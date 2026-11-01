// =====================================================================
// ΦΟΡΜΑ — Supabase Edge Function: bunny-video (ΜΟΝΟ owner)
// Σύνδεση με το Bunny Stream για τα βίντεο εξοπλισμού.
//   "create" { title }       → νέο βίντεο + υπογραφή για ανέβασμα από τον browser (TUS)
//   "import" { title, url }  → η συνάρτηση κατεβάζει το βίντεο από link (π.χ. Wix) και το ανεβάζει
//   "status" { video_id }    → κατάσταση επεξεργασίας (encoding)
// Secrets: BUNNY_STREAM_API_KEY (υποχρεωτικό), BUNNY_STREAM_LIBRARY_ID (προαιρετικό, default 796694)
// Το κλειδί του Bunny ΔΕΝ φεύγει ποτέ προς τον browser.
// =====================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
const fail = (status: number, error: string, message: string) => json({ error, message }, status);

const LIB = Deno.env.get("BUNNY_STREAM_LIBRARY_ID") ?? "796694";
const API = "https://video.bunnycdn.com";
const MAX_IMPORT_BYTES = 400 * 1024 * 1024;
const ALLOWED_IMPORT_HOSTS = ["video.wixstatic.com", "static.wixstatic.com"];

function serverKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    return keys.default ?? Object.values(keys)[0] ?? "";
  } catch { return ""; }
}
async function sha256Hex(text: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function bunny(path: string, init: RequestInit, key: string) {
  const res = await fetch(`${API}${path}`, { ...init, headers: { AccessKey: key, accept: "application/json", ...(init.headers ?? {}) } });
  const text = await res.text();
  // deno-lint-ignore no-explicit-any
  let data: any = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = { raw: text.slice(0, 300) }; }
  return { ok: res.ok, status: res.status, data };
}
async function createVideo(title: string, key: string) {
  const r = await bunny(`/library/${LIB}/videos`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ title: title.slice(0, 200) || "Βίντεο" }),
  }, key);
  if (!r.ok || !r.data?.guid) { console.error("bunny create", r.status, r.data); return null; }
  return String(r.data.guid);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "Μη επιτρεπτή μέθοδος.");

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, serverKey(), { auth: { persistSession: false, autoRefreshToken: false } });
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return fail(401, "unauthorized", "Πρέπει να είσαι συνδεδεμένος.");
  const { data: { user } } = await admin.auth.getUser(token);
  if (!user) return fail(401, "unauthorized", "Πρέπει να είσαι συνδεδεμένος.");
  const { data: profile } = await admin.from("profiles").select("role").eq("id", user.id).maybeSingle();
  if (profile?.role !== "owner") return fail(403, "forbidden", "Μόνο ο owner ανεβάζει βίντεο.");

  const key = (Deno.env.get("BUNNY_STREAM_API_KEY") ?? "").trim();
  if (!key) return fail(500, "server_config", "Λείπει το BUNNY_STREAM_API_KEY στα Secrets του Supabase.");

  // deno-lint-ignore no-explicit-any
  let body: any;
  try { body = await req.json(); } catch { return fail(400, "bad_request", "Μη έγκυρο αίτημα."); }
  const action = body?.action;
  const title = String(body?.title ?? "").slice(0, 200);

  if (action === "create") {
    const videoId = await createVideo(title, key);
    if (!videoId) return fail(502, "bunny_error", "Το Bunny δεν δημιούργησε το βίντεο. Έλεγξε το κλειδί API.");
    const expire = Math.floor(Date.now() / 1000) + 6 * 3600;
    const signature = await sha256Hex(LIB + key + expire + videoId);
    return json({ library_id: LIB, video_id: videoId, expire, signature, endpoint: `${API}/tusupload` });
  }

  if (action === "import") {
    let url: URL;
    try { url = new URL(String(body?.url ?? "")); } catch { return fail(400, "bad_url", "Μη έγκυρο link."); }
    if (url.protocol !== "https:" || !ALLOWED_IMPORT_HOSTS.includes(url.hostname)) {
      return fail(400, "bad_url", "Επιτρέπεται μεταφορά μόνο από links του Wix.");
    }
    const src = await fetch(url.toString());
    if (!src.ok || !src.body) return fail(502, "download_failed", `Δεν κατέβηκε το βίντεο (${src.status}).`);
    const len = Number(src.headers.get("content-length") ?? "0");
    if (len > MAX_IMPORT_BYTES) return fail(413, "too_large", "Το βίντεο είναι πολύ μεγάλο για μεταφορά.");
    const videoId = await createVideo(title, key);
    if (!videoId) return fail(502, "bunny_error", "Το Bunny δεν δημιούργησε το βίντεο.");
    const up = await fetch(`${API}/library/${LIB}/videos/${videoId}`, {
      method: "PUT",
      headers: { AccessKey: key, "content-type": "application/octet-stream", ...(len ? { "content-length": String(len) } : {}) },
      body: await src.arrayBuffer(),
    });
    if (!up.ok) {
      console.error("bunny upload", up.status, await up.text());
      await bunny(`/library/${LIB}/videos/${videoId}`, { method: "DELETE" }, key);
      return fail(502, "bunny_upload", "Το ανέβασμα στο Bunny απέτυχε.");
    }
    return json({ library_id: LIB, video_id: videoId });
  }

  if (action === "status") {
    const id = String(body?.video_id ?? "");
    if (!/^[0-9a-f-]{36}$/i.test(id)) return fail(400, "bad_id", "Μη έγκυρο βίντεο.");
    const r = await bunny(`/library/${LIB}/videos/${id}`, { method: "GET" }, key);
    if (!r.ok) return fail(r.status === 404 ? 404 : 502, "bunny_error", r.status === 404 ? "Το βίντεο δεν βρέθηκε στο Bunny." : "Το Bunny δεν απάντησε.");
    // status: 0 δημιουργήθηκε, 1 ανέβηκε, 2 επεξεργασία, 3 μετατροπή, 4 έτοιμο, 5 σφάλμα, 6 αποτυχία ανεβάσματος
    return json({ status: r.data?.status ?? null, progress: r.data?.encodeProgress ?? null, length: r.data?.length ?? null });
  }

  return fail(400, "bad_action", "Άγνωστη ενέργεια.");
});
