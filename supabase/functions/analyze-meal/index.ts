// =====================================================================
// ΦΟΡΜΑ — Supabase Edge Function: analyze-meal
// Δέχεται φωτογραφία γεύματος από συνδεδεμένο χρήστη, τη στέλνει στο
// Claude και επιστρέφει τρόφιμα + εκτίμηση γραμμαρίων/θερμίδων/μακρο.
// Για τρόφιμα της βάσης (πίνακας foods) οι θερμίδες βγαίνουν από τον πίνακα.
//
// Secrets (Supabase → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY   (υποχρεωτικό)
//   ANTHROPIC_MODEL     (προαιρετικό, default: claude-sonnet-5-5)
//   MEAL_DAILY_LIMIT    (προαιρετικό, default: 20 φωτογραφίες / 24ώρο / χρήστη)
// Τα SUPABASE_URL και τα κλειδιά του Supabase υπάρχουν ήδη αυτόματα.
// =====================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5-5";
const DAILY_LIMIT = Number(Deno.env.get("MEAL_DAILY_LIMIT") ?? "20");
const MAX_B64_LEN = 6_000_000; // ~4.5MB εικόνα — η εφαρμογή στέλνει ~150KB μετά τη συμπίεση
const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp"];

const SYSTEM_PROMPT = `Είσαι διατροφολόγος που εκτιμά θερμίδες από φωτογραφίες φαγητού για μια εφαρμογή γυμναστικής στην Ελλάδα.
Κανόνες:
- Αναγνώρισε κάθε διακριτό τρόφιμο στο πιάτο. Δώσε ελληνικά ονόματα (π.χ. "Κοτόπουλο ψητό", "Ρύζι λευκό", "Χωριάτικη σαλάτα").
- Εκτίμηση γραμμαρίων, βήμα-βήμα για κάθε τρόφιμο:
  1. Βρες αντικείμενο αναφοράς: πιάτο φαγητού ≈ 26-28 εκ. διάμετρο, πιρούνι ≈ 19 εκ., μαχαίρι ≈ 22 εκ., παλάμη ενήλικα ≈ 8-9 εκ. πλάτος.
  2. Εκτίμησε τις διαστάσεις του τροφίμου σε εκατοστά (μήκος × πλάτος × πάχος). Τα κρέατα μαγειρεμένα είναι συνήθως 1-2 εκ. πάχος.
  3. Υπολόγισε όγκο × πυκνότητα (κρέας/ψάρι ≈ 1,05 γρ./κ.εκ.). Αν υπάρχει κόκαλο, αφαίρεσέ το — μέτρα μόνο το φαγώσιμο μέρος.
  4. Σύγκρινε με ρεαλιστικές σπιτικές μερίδες: μπριζόλα χοιρινή ή φιλέτο κοτόπουλο 100-180γρ., μπιφτέκι 80-150γρ., ρύζι/ζυμαρικά μαγειρεμένα 120-250γρ.
  Τα μοντέλα τείνουν να ΥΠΕΡΕΚΤΙΜΟΥΝ τις μερίδες κρέατος από φωτογραφίες· όταν διστάζεις, προτίμησε τη μεσαία-χαμηλή τιμή. Τα γραμμάρια αφορούν το βάρος όπως σερβίρεται (μαγειρεμένο).
  Γράψε σύντομα το σκεπτικό διαστάσεων στο πεδίο size_basis κάθε τροφίμου ΠΡΙΝ δώσεις τα γραμμάρια.
- Υπολόγισε θερμίδες και μακροθρεπτικά για την ποσότητα που εκτίμησες (όχι ανά 100γρ.), με βάση τυπικές τιμές διατροφικών πινάκων.
- Στην ελληνική κουζίνα το λάδι είναι κρυφή πηγή θερμίδων: σε λαδερά, σαλάτες, τηγανητά και μαγειρευτά πρόσθεσε ΞΕΧΩΡΙΣΤΟ στοιχείο "Ελαιόλαδο" με λογική ποσότητα, εκτός αν ο χρήστης πει άλλο ή αν διάλεξες από τη λίστα εκδοχή φαγητού που περιέχει ήδη το λάδι (π.χ. "με λάδι", λαδερά, μαγειρευτά).
- Για σύνθετα πιάτα (μουσακάς, παστίτσιο, γεμιστά, πίτες) δώσε το πιάτο ως ένα στοιχείο με τυπική συνταγή.
- Αν ο χρήστης δώσει σημείωση (π.χ. ποσότητες, λάδι, μάρκα), αυτή υπερισχύει της εικόνας.
- Αν η εικόνα δεν δείχνει φαγητό ή ποτό, βάλε is_food=false και κενή λίστα.
Κάλεσε ΠΑΝΤΑ το εργαλείο report_meal με το αποτέλεσμα (μία φορά, χωρίς άλλο κείμενο).
Αν για κάποιο λόγο δεν μπορείς να καλέσεις το εργαλείο, απάντησε ΜΟΝΟ με ένα αντικείμενο JSON με τα ίδια πεδία (is_food, items, confidence, comment).`;

const REPORT_TOOL = {
  name: "report_meal",
  description: "Επιστρέφει τα τρόφιμα που εντοπίστηκαν στη φωτογραφία με εκτιμώμενες ποσότητες και διατροφικές τιμές.",
  input_schema: {
    type: "object",
    properties: {
      is_food: { type: "boolean", description: "Αν η εικόνα δείχνει φαγητό ή ποτό" },
      items: {
        type: "array",
        items: {
          type: "object",
          properties: {
            name: { type: "string", description: "Όνομα τροφίμου στα ελληνικά" },
            db_name: { type: "string", description: "Αν το τρόφιμο υπάρχει στη ΛΙΣΤΑ ΤΡΟΦΙΜΩΝ, το όνομα ΑΚΡΙΒΩΣ όπως είναι στη λίστα· αλλιώς κενό" },
            size_basis: { type: "string", description: "Σύντομο σκεπτικό: αναφορά, διαστάσεις σε εκ., πάχος" },
            grams: { type: "number", description: "Εκτιμώμενο βάρος σε γραμμάρια (ή ml για υγρά)" },
            kcal: { type: "number" },
            protein_g: { type: "number" },
            carbs_g: { type: "number" },
            fat_g: { type: "number" },
          },
          required: ["name", "grams", "kcal", "protein_g", "carbs_g", "fat_g"],
        },
      },
      confidence: { type: "string", enum: ["low", "medium", "high"], description: "Πόσο σίγουρη είναι η εκτίμηση" },
      comment: { type: "string", description: "Μία σύντομη πρόταση στα ελληνικά, π.χ. τι δεν φαινόταν καθαρά" },
    },
    required: ["is_food", "items", "confidence"],
  },
};

// Κλειδί διακομιστή: παλιό (SUPABASE_SERVICE_ROLE_KEY) ή νέο σύστημα κλειδιών (SUPABASE_SECRET_KEYS)
function serverKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    return keys.default ?? Object.values(keys)[0] ?? "";
  } catch { return ""; }
}

// Ελληνικό κείμενο χωρίς τόνους/κεφαλαία, για ταίριασμα ονομάτων τροφίμων
const normName = (t: string) =>
  t.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/\(.*?\)/g, "").replace(/\s+/g, " ").trim();

// ---------------------------------------------------------------------
// Βάση τροφίμων (πίνακας foods, τιμές ανά 100γρ.). Το AI διαλέγει όνομα
// από τη λίστα και οι θερμίδες/μακρο υπολογίζονται από τον πίνακα.
// Κρατιέται 5 λεπτά στη μνήμη της συνάρτησης.
// ---------------------------------------------------------------------
type FoodRow = { name: string; category: string; kcal: number; protein_g: number; carbs_g: number; fat_g: number };
let foodsCache: { at: number; rows: FoodRow[] } | null = null;
const dbKey = (t: string) =>
  t.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/["«»]/g, "").replace(/\s+/g, " ").trim();

// deno-lint-ignore no-explicit-any
async function loadFoods(admin: any): Promise<FoodRow[]> {
  if (foodsCache && Date.now() - foodsCache.at < 5 * 60 * 1000) return foodsCache.rows;
  const { data, error } = await admin.from("foods")
    .select("name, category, kcal, protein_g, carbs_g, fat_g").order("name").limit(3000);
  if (error) { console.error("foods load error", error); return foodsCache?.rows ?? []; }
  const rows = ((data ?? []) as FoodRow[]).map((r) => ({
    name: r.name, category: r.category ?? "Άλλο",
    kcal: Number(r.kcal) || 0, protein_g: Number(r.protein_g) || 0, carbs_g: Number(r.carbs_g) || 0, fat_g: Number(r.fat_g) || 0,
  }));
  foodsCache = { at: Date.now(), rows };
  return rows;
}

function buildFoodListText(rows: FoodRow[]): string {
  if (!rows.length) return "";
  const byCat = new Map<string, string[]>();
  for (const r of rows) {
    const list = byCat.get(r.category) ?? [];
    list.push(r.name);
    byCat.set(r.category, list);
  }
  const lines = [...byCat.entries()].map(([cat, names]) => `${cat}: ${names.join(" | ")}`);
  return `

ΛΙΣΤΑ ΤΡΟΦΙΜΩΝ (βάση της εφαρμογής, τιμές ανά 100γρ. — οι θερμίδες υπολογίζονται από εκεί):
${lines.join("\n")}
Για κάθε τρόφιμο: αν υπάρχει αντίστοιχο στη λίστα, γράψε στο db_name το όνομα ΑΚΡΙΒΩΣ όπως είναι στη λίστα και βάλε το ίδιο και στο name. Διάλεξε την πιο κοντινή εκδοχή (ψητό / βραστό / τηγανητό, με ή χωρίς πέτσα, πλήρες ή light). Τα γραμμάρια είναι όπως σερβίρεται, οπότε προτίμησε τις μαγειρεμένες εκδοχές· τις "ωμό/ωμή" μόνο για τρόφιμα που τρώγονται ωμά. Αν δεν υπάρχει κάτι αντίστοιχο, άφησε κενό το db_name και δώσε δικές σου τιμές.`;
}

// Διορθώσεις του owner → οδηγίες για το AI
// deno-lint-ignore no-explicit-any
async function buildCalibrationText(admin: any): Promise<string> {
  const { data, error } = await admin.from("ai_food_calibration")
    .select("food_name, ai_grams, true_grams")
    .order("created_at", { ascending: false }).limit(500);
  if (error || !data || !data.length) return "";
  const groups = new Map<string, { name: string; n: number; ai: number; real: number; ratios: number[] }>();
  for (const r of data as Array<{ food_name: string; ai_grams: number; true_grams: number }>) {
    const ai = Number(r.ai_grams), real = Number(r.true_grams);
    if (!(ai > 0 && real > 0)) continue;
    const key = normName(r.food_name);
    const g = groups.get(key) ?? { name: r.food_name, n: 0, ai: 0, real: 0, ratios: [] };
    g.n++; g.ai += ai; g.real += real; g.ratios.push(real / ai);
    groups.set(key, g);
  }
  if (!groups.size) return "";
  const all = [...groups.values()].flatMap((g) => g.ratios);
  const median = (a: number[]) => { const b = [...a].sort((x, y) => x - y); const m = Math.floor(b.length / 2); return b.length % 2 ? b[m] : (b[m - 1] + b[m]) / 2; };
  const pct = (r: number) => (r >= 1 ? "+" : "") + Math.round((r - 1) * 100) + "%";
  const lines = [...groups.values()].sort((a, b) => b.n - a.n).slice(0, 40).map((g) => {
    const r = median(g.ratios);
    return `- ${g.name}: εκτιμούσες κατά μέσο όρο ${Math.round(g.ai / g.n)}γρ., το πραγματικό ήταν ${Math.round(g.real / g.n)}γρ. → διόρθωση ${pct(r)} (×${r.toFixed(2)}, ${g.n} ζυγίσματα)`;
  });
  return `

ΔΙΟΡΘΩΣΕΙΣ ΑΠΟ ΖΥΓΙΣΜΕΝΑ ΓΕΥΜΑΤΑ (από τον προπονητή — είναι ακριβείς, εμπιστέψου τες):
${lines.join("\n")}
Συνολικά, το πραγματικό βάρος ήταν κατά μέσο όρο ×${median(all).toFixed(2)} της εκτίμησής σου (${all.length} ζυγίσματα).
Πώς να τις χρησιμοποιήσεις: κάνε πρώτα την εκτίμησή σου όπως πάντα, και μετά πολλαπλασίασε τα γραμμάρια με τον συντελεστή του ίδιου ή του πιο παρόμοιου τροφίμου (π.χ. κρέας με κρέας). Για τρόφιμα χωρίς παρόμοια διόρθωση χρησιμοποίησε τον συνολικό συντελεστή μόνο αν υπάρχουν τουλάχιστον 5 ζυγίσματα. Αν ο χρήστης δώσει βάρος στη σημείωση, αυτό υπερισχύει.`;
}

const num = (v: unknown) => {
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? Math.round(n * 10) / 10 : 0;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // --- 1. Ποιος είναι ο χρήστης;
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, serverKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "unauthorized", message: "Πρέπει να είσαι συνδεδεμένος." }, 401);
  const { data: { user }, error: userErr } = await admin.auth.getUser(token);
  if (userErr || !user) return json({ error: "unauthorized", message: "Πρέπει να είσαι συνδεδεμένος." }, 401);

  // --- 2. Είσοδος
  let body: { image?: string; media_type?: string; note?: string; raw?: boolean };
  try { body = await req.json(); } catch { return json({ error: "bad_request", message: "Μη έγκυρο αίτημα." }, 400); }
  const image = (body.image ?? "").replace(/^data:[^;]+;base64,/, "");
  const mediaType = body.media_type ?? "image/jpeg";
  const note = (body.note ?? "").toString().slice(0, 500);
  if (!image) return json({ error: "bad_request", message: "Δεν στάλθηκε φωτογραφία." }, 400);
  if (image.length > MAX_B64_LEN) return json({ error: "too_large", message: "Η φωτογραφία είναι πολύ μεγάλη." }, 413);
  if (!ALLOWED_TYPES.includes(mediaType)) return json({ error: "bad_type", message: "Μη υποστηριζόμενος τύπος εικόνας." }, 400);

  // Ρόλος χρήστη (ο owner εκπαιδεύει το AI: παίρνει "ωμή" εκτίμηση χωρίς διορθώσεις, μεγαλύτερο όριο)
  const { data: profile } = await admin.from("profiles").select("role").eq("id", user.id).maybeSingle();
  const isOwner = profile?.role === "owner";
  const rawMode = isOwner && body.raw === true;

  // --- 3. Όριο χρήσης
  const limit = isOwner ? Math.max(DAILY_LIMIT, 200) : DAILY_LIMIT;
  const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  const { count } = await admin.from("meal_ai_usage")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id).gte("created_at", since);
  if ((count ?? 0) >= limit) {
    return json({ error: "rate_limited", message: `Έφτασες το όριο των ${limit} φωτογραφιών για σήμερα. Μπορείς να προσθέσεις γεύμα χειροκίνητα.` }, 429);
  }
  // (Η χρήση καταγράφεται ΜΟΝΟ μετά από επιτυχημένη ανάλυση — βλ. βήμα 5.)

  // --- 4. Κλήση στο Claude
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "server_config", message: "Λείπει το ANTHROPIC_API_KEY στον διακομιστή." }, 500);

  const [calibration, foods] = await Promise.all([
    rawMode ? Promise.resolve("") : buildCalibrationText(admin),
    loadFoods(admin),
  ]);
  const foodByKey = new Map(foods.map((f) => [dbKey(f.name), f]));

  const userText = note
    ? `Ανάλυσε αυτό το γεύμα. Σημείωση χρήστη: "${note}"`
    : "Ανάλυσε αυτό το γεύμα.";

  let aiRes: Response;
  try {
    aiRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1500,
        system: SYSTEM_PROMPT + buildFoodListText(foods) + calibration,
        tools: [REPORT_TOOL],
        messages: [{
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: mediaType, data: image } },
            { type: "text", text: userText },
          ],
        }],
      }),
    });
  } catch (e) {
    console.error("Anthropic fetch failed", e);
    return json({ error: "ai_unreachable", message: "Η υπηρεσία ανάλυσης δεν απαντά. Δοκίμασε ξανά." }, 502);
  }

  if (!aiRes.ok) {
    console.error("Anthropic error", aiRes.status, await aiRes.text());
    return json({ error: "ai_error", message: "Η ανάλυση απέτυχε. Δοκίμασε ξανά σε λίγο." }, 502);
  }

  const ai = await aiRes.json();
  const blocks = (ai.content ?? []) as Array<{ type: string; input?: unknown; text?: string }>;
  const toolUse = blocks.find((c) => c.type === "tool_use");
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let out: any = toolUse?.input;
  if (!out) {
    // Εναλλακτικά: το μοντέλο απάντησε με JSON σε κείμενο αντί για εργαλείο
    const text = blocks.filter((c) => c.type === "text").map((c) => c.text ?? "").join("\n");
    const m = text.match(/\{[\s\S]*\}/);
    if (m) { try { out = JSON.parse(m[0]); } catch { /* αγνόησε */ } }
  }
  if (!out) {
    console.error("No tool_use / JSON in response", JSON.stringify(ai).slice(0, 2000));
    return json({ error: "ai_error", message: "Η ανάλυση δεν επέστρεψε αποτέλεσμα. Δοκίμασε ξανά." }, 502);
  }
  const items = Array.isArray(out.items) ? out.items.slice(0, 20).map((it: Record<string, unknown>) => {
    const grams = num(it.grams);
    // Αν το AI διάλεξε τρόφιμο της βάσης, θερμίδες & μακρο από τον πίνακα (ανά 100γρ.)
    const f = foodByKey.get(dbKey(String(it.db_name ?? ""))) ?? foodByKey.get(dbKey(String(it.name ?? "")));
    if (f && grams > 0) {
      const k = grams / 100;
      return {
        name: f.name,
        grams,
        kcal: Math.round(f.kcal * k),
        protein_g: num(f.protein_g * k),
        carbs_g: num(f.carbs_g * k),
        fat_g: num(f.fat_g * k),
        per100: { kcal: f.kcal, protein_g: f.protein_g, carbs_g: f.carbs_g, fat_g: f.fat_g },
      };
    }
    return {
      name: String(it.name ?? "Τρόφιμο").slice(0, 80),
      grams,
      kcal: Math.round(num(it.kcal)),
      protein_g: num(it.protein_g),
      carbs_g: num(it.carbs_g),
      fat_g: num(it.fat_g),
    };
  }) : [];

  // --- 5. Καταγραφή χρήσης: μετράει μόνο η ανάλυση που πέτυχε
  const { error: usageErr } = await admin.from("meal_ai_usage").insert({ user_id: user.id });
  if (usageErr) console.error("meal_ai_usage insert failed", usageErr);

  return json({
    is_food: out.is_food !== false,
    items,
    confidence: ["low", "medium", "high"].includes(out.confidence) ? out.confidence : "medium",
    comment: typeof out.comment === "string" ? out.comment.slice(0, 300) : "",
  });
});
