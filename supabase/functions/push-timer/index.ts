// ΦΟΡΜΑ — ειδοποιήσεις «Τέλος διαλείμματος» (Web Push).
// Η εφαρμογή στο iPhone/Android «παγώνει» στο παρασκήνιο, οπότε δεν μπορεί να χτυπήσει μόνη της.
// Στο START του διαλείμματος ζητάει από εδώ: «στείλε ειδοποίηση σε Χ δευτερόλεπτα».
// Η υπηρεσία περιμένει (σε κομμάτια ≤100″ — μετά καλεί τον εαυτό της) και στέλνει την ειδοποίηση,
// εκτός αν στο μεταξύ ακυρώθηκε (STOP / επαναφορά / νέο διάλειμμα).
//
// Ενέργειες (POST JSON):
//   { action:'key' }                                   → το δημόσιο κλειδί VAPID (για την εγγραφή της συσκευής)
//   { action:'subscribe', subscription }               → αποθήκευση συσκευής (απαιτεί σύνδεση)
//   { action:'unsubscribe', endpoint }
//   { action:'schedule', delaySec, title, body, url, tag } → προγραμματισμός (ακυρώνει τα προηγούμενα ίδιου tag)
//   { action:'cancel', tag }
//   { action:'test' }                                  → δοκιμαστική ειδοποίηση τώρα
//   { action:'wait', id, token }                       → εσωτερική (συνέχεια αναμονής)
import { createClient } from "npm:@supabase/supabase-js@2";
import { sendPush, type Subscription } from "./webpush.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (status: number, data: unknown) =>
  new Response(JSON.stringify(data), { status, headers: { ...CORS, "Content-Type": "application/json" } });

function serverKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    return keys.default ?? Object.values(keys)[0] ?? "";
  } catch { return ""; }
}
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const admin = () => createClient(SUPABASE_URL, serverKey(), { auth: { persistSession: false, autoRefreshToken: false } });
const vapid = () => ({
  publicKey: Deno.env.get("VAPID_PUBLIC_KEY") ?? "",
  privateKey: Deno.env.get("VAPID_PRIVATE_KEY") ?? "",
  subject: Deno.env.get("VAPID_SUBJECT") ?? "https://selficon-design.github.io/megagym-app_4/",
});
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const HOP_MS = 100_000;           // κάθε κλήση περιμένει το πολύ 100″ (όριο χρόνου των Edge Functions)

// deno-lint-ignore no-explicit-any
function bg(p: Promise<unknown>) { try { (globalThis as any).EdgeRuntime.waitUntil(p); } catch { /* τοπικά */ } }

async function sendToUser(db: ReturnType<typeof admin>, userId: string, data: unknown, topic?: string) {
  const { data: subs } = await db.from("push_subscriptions").select("id, endpoint, p256dh, auth").eq("user_id", userId);
  let ok = 0;
  for (const s of subs ?? []) {
    try {
      const st = await sendPush(s as Subscription, data, vapid(), { ttl: 120, urgency: "high", topic });
      if (st === 404 || st === 410) await db.from("push_subscriptions").delete().eq("id", s.id);   // η συσκευή δεν ισχύει πια
      else if (st >= 200 && st < 300) { ok++; await db.from("push_subscriptions").update({ last_ok_at: new Date().toISOString() }).eq("id", s.id); }
      else console.error("push status", st);
    } catch (e) { console.error("push error", e); }
  }
  return { devices: subs?.length ?? 0, ok };
}

async function runJob(id: number, token: string) {
  const db = admin();
  const { data: job } = await db.from("push_jobs").select("*").eq("id", id).eq("token", token).maybeSingle();
  if (!job || job.status !== "pending") return;
  const left = new Date(job.send_at).getTime() - Date.now();
  if (left > HOP_MS + 5_000) {
    await sleep(HOP_MS);
    // συνέχεια σε νέα κλήση (νέο χρονικό όριο)
    await fetch(`${SUPABASE_URL}/functions/v1/push-timer`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "wait", id, token }),
    }).catch((e) => console.error("hop", e));
    return;
  }
  if (left > 0) await sleep(left);
  const { data: again } = await db.from("push_jobs").select("status").eq("id", id).maybeSingle();
  if (!again || again.status !== "pending") return;            // ακυρώθηκε στο μεταξύ
  const r = await sendToUser(db, job.user_id, job.payload, job.tag);
  await db.from("push_jobs").update({ status: r.ok ? "sent" : "failed", done_at: new Date().toISOString() }).eq("id", id).eq("status", "pending");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  // deno-lint-ignore no-explicit-any
  let body: any;
  try { body = await req.json(); } catch { return json(400, { error: "bad_request" }); }
  const action = String(body?.action ?? "");

  if (action === "key") return json(200, { publicKey: vapid().publicKey || null });

  if (action === "wait") {
    const id = Number(body.id), token = String(body.token ?? "");
    if (!id || !token) return json(400, { error: "bad_request" });
    bg(runJob(id, token));
    return json(202, { ok: true });
  }

  // όλα τα υπόλοιπα: συνδεδεμένος χρήστης
  const db = admin();
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json(401, { error: "unauthorized" });
  const { data: { user } } = await db.auth.getUser(jwt);
  if (!user) return json(401, { error: "unauthorized" });
  if (!vapid().privateKey) return json(503, { error: "not_configured" });

  if (action === "subscribe") {
    const s = body.subscription ?? {};
    const endpoint = String(s.endpoint ?? ""), p256dh = String(s.keys?.p256dh ?? ""), auth = String(s.keys?.auth ?? "");
    if (!/^https:\/\//.test(endpoint) || !p256dh || !auth) return json(400, { error: "bad_subscription" });
    const { error } = await db.from("push_subscriptions").upsert(
      { user_id: user.id, endpoint, p256dh, auth, user_agent: String(body.userAgent ?? "").slice(0, 300) }, { onConflict: "endpoint" });
    if (error) { console.error(error); return json(500, { error: "db" }); }
    return json(200, { ok: true });
  }
  if (action === "unsubscribe") {
    await db.from("push_subscriptions").delete().eq("user_id", user.id).eq("endpoint", String(body.endpoint ?? ""));
    return json(200, { ok: true });
  }
  if (action === "cancel") {
    await db.from("push_jobs").update({ status: "canceled", done_at: new Date().toISOString() })
      .eq("user_id", user.id).eq("tag", String(body.tag ?? "rest")).eq("status", "pending");
    return json(200, { ok: true });
  }
  if (action === "test") {
    const r = await sendToUser(db, user.id, { title: "TRANSFORMATION", body: "✅ Οι ειδοποιήσεις λειτουργούν!", url: String(body.url ?? ""), tag: "test" });
    return json(200, r);
  }
  if (action === "schedule") {
    const delay = Math.max(1, Math.min(Number(body.delaySec) || 0, 30 * 60));
    const tag = String(body.tag ?? "rest").slice(0, 40);
    const payload = {
      title: String(body.title ?? "⏱ Τέλος διαλείμματος").slice(0, 120),
      body: String(body.body ?? "").slice(0, 240),
      url: String(body.url ?? "").slice(0, 500),
      tag,
    };
    // ένα ενεργό ανά tag: τα παλιά ακυρώνονται
    await db.from("push_jobs").update({ status: "canceled", done_at: new Date().toISOString() })
      .eq("user_id", user.id).eq("tag", tag).eq("status", "pending");
    const token = crypto.randomUUID();
    const { data: job, error } = await db.from("push_jobs").insert({
      user_id: user.id, tag, send_at: new Date(Date.now() + delay * 1000).toISOString(), payload, token,
    }).select("id").single();
    if (error || !job) { console.error(error); return json(500, { error: "db" }); }
    bg(runJob(job.id, token));
    // καθάρισμα παλιών εγγραφών (πάνω από 2 ημέρες)
    bg(db.from("push_jobs").delete().lt("created_at", new Date(Date.now() - 2 * 864e5).toISOString()).then(() => {}));
    return json(200, { ok: true, id: job.id });
  }
  return json(400, { error: "unknown_action" });
});
