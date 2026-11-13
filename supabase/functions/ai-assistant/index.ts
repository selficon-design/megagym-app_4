// =====================================================================
// ΦΟΡΜΑ — Supabase Edge Function: ai-assistant
// Ο «ψηφιακός προπονητής»: διαβάζει τις κάρτες του Κέντρου Κανόνων AI
// και εκτελεί την ενέργεια του κουμπιού που πάτησε ο πελάτης.
//
// Ενέργειες (body.action):
//   "request"  — πελάτης: { button_key: "program_renewal", note, catalog }
//   "simulate" — owner:   { button_key, note, catalog, version: "draft"|"published", customer_code? }
//                (δοκιμή: ΔΕΝ γράφει τίποτα στη βάση)
//   "review"   — πελάτης: { button_key: "program_check", program_id, note, catalog }
//                «Έλεγχος προγράμματος»: ελέγχει ένα πρόγραμμα που έφτιαξε ο ίδιος ο αθλούμενος
//                («Φτιάχνω δικό μου πρόγραμμα») και επιστρέφει σχόλια + βελτιωμένη εκδοχή.
//                ΔΕΝ γράφει πρόγραμμα: την αλλαγή την αποθηκεύει ο αθλούμενος αν τη θέλει.
//
// Ασφάλεια:
//   - Το πρόγραμμα που προτείνει το AI ελέγχεται εδώ: μόνο ασκήσεις της λίστας,
//     σετ 3–6, σωστές επαναλήψεις/διαλείμματα, έως 6 ημέρες.
//   - Ευαίσθητες περιπτώσεις (πόνος, τραυματισμός κ.λπ.) ΠΑΝΤΑ σε έγκριση.
//   - Κάθε πρόταση γράφει ποια έκδοση κανόνων χρησιμοποιήθηκε.
//
// Secrets: ANTHROPIC_API_KEY (υπάρχει ήδη), ANTHROPIC_MODEL (προαιρετικό)
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

const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5-5";
const APP = "forma";
const OWNER_DAILY_LIMIT = 200;

// Τα κουμπιά της εφαρμογής που μπορούν να συνδεθούν με κάρτες
const BUTTONS: Record<string, { label: string; scope: string }> = {
  program_renewal: { label: "Θέλω ανανέωση προγράμματος", scope: "program" },
  program_check: { label: "Έλεγχος προγράμματος", scope: "program" },
};

// Βασικοί κανόνες «Ελέγχου προγράμματος» — ισχύουν όσο ο owner δεν έχει γράψει δική του κάρτα
// για το κουμπί «Έλεγχος προγράμματος» στο Κέντρο Κανόνων AI.
const DEFAULT_CHECK_RULES = `
1. ΔΙΑΛΕΙΜΜΑ (Αύξηση μυϊκού ιστού): το διάλειμμα πρέπει να είναι από 90 δευτερόλεπτα και πάνω.
   - 90sec → εντάξει, δεν προτείνεις τίποτα.
   - 120sec και πάνω → πρότεινε ότι θα μπορούσε να ξεκινήσει από 90sec. Ερώτηση: «Θέλεις να το αλλάξω σε 90 δευτερόλεπτα ή να συνεχίσεις με τον χρόνο διαλείμματος που έχεις βάλει;»
   - κάτω από 90sec (π.χ. 60sec) → πρότεινε 90sec.
2. ΕΠΑΝΑΛΗΨΕΙΣ: αν είναι «13 έως 15», πες ότι καλύτερο θα ήταν «10 έως 12» ή «8 έως 10». Ερώτηση: «Θέλεις να το αλλάξω σε 10 έως 12 ή να συνεχίσεις με 13 έως 15;»
3. UNTIL FAILURE:
   - -3 ή -2 → εντάξει.
   - -1 ή 0 → πες ότι αυτό δεν είναι πρόγραμμα TRANSFORMATION: δεν μπορείς σε όλα τα set να πηγαίνεις until failure. Πιο ασφαλές θα ήταν until failure -3, ή μόνο στο 1-2 τελευταίο set until failure -1 ή 0. Το until failure δίνει τα μέγιστα αποτελέσματα όταν ακολουθείται το πρωτόκολλο TRANSFORMATION. Πρότεινε αλλαγή σε -3.
- Όταν το ίδιο θέμα υπάρχει σε πολλές ασκήσεις, κάνε ΜΙΑ πρόταση που τις περιλαμβάνει όλες (πολλά apply).
- Αν δεν βρεις κάτι από τα παραπάνω, πες ότι το πρόγραμμα είναι εντάξει.
- Πόνος, τραυματισμός, εγκυμοσύνη ή ιατρικό θέμα στο σημείωμα → sensitive = true και σύσταση να μιλήσει με τον προπονητή.`;

const REVIEW_TOOL = {
  name: "review_program",
  description: "Αποτέλεσμα ελέγχου του προγράμματος του αθλούμενου, με προτάσεις που ο αθλούμενος δέχεται ή απορρίπτει μία-μία.",
  input_schema: {
    type: "object",
    properties: {
      verdict: { type: "string", enum: ["ok", "improve", "unsafe"], description: "ok = καλό όπως είναι, improve = υπάρχουν προτάσεις, unsafe = χρειάζεται προπονητή" },
      sensitive: { type: "boolean" },
      sensitive_reason: { type: "string" },
      summary: { type: "string", description: "Μήνυμα προς τον αθλούμενο, 1-3 προτάσεις, στον ενικό, φιλικό" },
      good: { type: "array", items: { type: "string" }, description: "Τι είναι σωστό (σύντομα)" },
      suggestions: {
        type: "array",
        description: "Μία πρόταση ανά θέμα. Ο αθλούμενος απαντά «άλλαξέ το» ή «συνεχίζω με το δικό μου».",
        items: {
          type: "object",
          properties: {
            explanation: { type: "string", description: "Γιατί (σύμφωνα με τους κανόνες), 1-3 προτάσεις" },
            question: { type: "string", description: "Η ερώτηση προς τον αθλούμενο, π.χ. «Θέλεις να το αλλάξω σε 90 δευτερόλεπτα ή να συνεχίσεις με αυτό που έχεις βάλει;»" },
            apply: {
              type: "array",
              description: "Οι αλλαγές αν πει ναι. day/item = αριθμοί όπως στη λίστα του προγράμματος (από 1).",
              items: {
                type: "object",
                properties: {
                  day: { type: "integer" }, item: { type: "integer" },
                  field: { type: "string", enum: ["set", "rep", "rest", "tempo", "failure", "minutes"] },
                  value: { type: "string", description: "Η νέα τιμή ΑΚΡΙΒΩΣ από τις επιτρεπτές (π.χ. 90sec, 10 έως 12, -3, 1-2-1)" },
                },
                required: ["day", "item", "field", "value"],
              },
            },
          },
          required: ["explanation", "question", "apply"],
        },
      },
    },
    required: ["verdict", "sensitive", "summary", "suggestions"],
  },
};

type Opts = { set: number[]; rep: string[]; rest: string[]; tempo: string[]; minutes: number[]; cardio_equipment: string[] };
// deno-lint-ignore no-explicit-any
function readOpts(c: any): Opts {
  const o = c?.options ?? {};
  const arr = (v: unknown, n = 60) => (Array.isArray(v) ? v.slice(0, n) : []);
  return {
    set: arr(o.set).map(Number).filter((x: number) => x > 0 && x <= 12),
    rep: arr(o.rep).map(String), rest: arr(o.rest).map(String), tempo: arr(o.tempo).map(String),
    minutes: arr(o.minutes, 40).map(Number).filter((x: number) => x > 0 && x <= 180),
    cardio_equipment: arr(o.cardio_equipment).map(String),
  };
}
// Ετικέτα ομάδας του προγράμματος (π.χ. «CHEST - ΣΤΗΘΟΣ») → κλειδί της λίστας (π.χ. «ΣΤΗΘΟΣ»)
function groupKeyOf(label: string, cat: Catalog): string | null {
  const s = String(label ?? "");
  const part = squash(s.includes(" - ") ? s.split(" - ").pop()! : s).normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  for (const [k, g] of Object.entries(cat.groups)) {
    const kk = squash(k).normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/_/g, " ");
    if (kk === part || squash(g.label) === squash(s)) return k;
  }
  return null;
}
// deno-lint-ignore no-explicit-any
function describeProgram(r: any, cat: Catalog): string {
  const goal = r?.category === "fatburn" ? `Καύση λίπους (${r?.subtype ?? ""})` : "Αύξηση μυϊκού ιστού";
  const lines = [`Στόχος: ${goal}`, `Όνομα: ${r?.customName || r?.templateName || "-"}`];
  if (r?.instructions) lines.push(`Σημειώσεις αθλούμενου: ${String(r.instructions).slice(0, 500)}`);
  // deno-lint-ignore no-explicit-any
  (Array.isArray(r?.days) ? r.days : []).forEach((d: any, di: number) => {
    lines.push(`\nΗμέρα ${di + 1} (${d.label ?? ""}):`);
    const g = Array.isArray(d.groups) ? d.groups : [], c = Array.isArray(d.cardioSlots) ? d.cardioSlots : [];
    const order: string[] = Array.isArray(d.order) ? d.order : [...g.map(() => "w"), ...c.map(() => "c")];
    let wi = 0, ci = 0, n = 0;
    for (const k of order) {
      if (k === "c" && ci < c.length) { const x = c[ci++]; lines.push(`  ${++n}. [cardio] ${x.equipment} ${x.minutes ?? "?"}′`); }
      else if (k === "w" && wi < g.length) {
        const x = g[wi++];
        lines.push(`  ${++n}. [muscle] group_key=${groupKeyOf(x.groupLabel, cat) ?? "?"} | ${x.exercise} | ${x.set}×${x.rep} | διάλειμμα ${x.rest} | tempo ${x.tempo || "-"} | failure ${x.failure ?? 0}`);
      }
    }
  });
  return lines.join("\n");
}
// Ελέγχει τις αλλαγές του AI: σωστή ημέρα/άσκηση και τιμές ΜΟΝΟ από τις επιτρεπτές
// deno-lint-ignore no-explicit-any
function validateSuggestions(list: any, record: any, cat: Catalog, o: Opts) {
  const failOpts = (cat.failure_options?.length ? cat.failure_options : [0, -1, -2, -3]).map(String);
  // deno-lint-ignore no-explicit-any
  const days: any[] = Array.isArray(record?.days) ? record.days : [];
  // στοιχεία ημέρας με τη σειρά που τα βλέπει ο αθλούμενος
  const itemAt = (di: number, ii: number) => {
    const d = days[di]; if (!d) return null;
    const g = Array.isArray(d.groups) ? d.groups : [], c = Array.isArray(d.cardioSlots) ? d.cardioSlots : [];
    const order: string[] = Array.isArray(d.order) ? d.order : [...g.map(() => "w"), ...c.map(() => "c")];
    let wi = 0, ci = 0, n = 0;
    for (const k of order) {
      if (k === "c" && ci < c.length) { if (n++ === ii) return { type: "cardio", x: c[ci] }; ci++; }
      else if (k === "w" && wi < g.length) { if (n++ === ii) return { type: "muscle", x: g[wi] }; wi++; }
    }
    return null;
  };
  const allowed: Record<string, string[]> = {
    set: o.set.map(String), rep: o.rep, rest: o.rest, tempo: o.tempo, failure: failOpts, minutes: o.minutes.map(String),
  };
  // deno-lint-ignore no-explicit-any
  const out: any[] = [];
  // deno-lint-ignore no-explicit-any
  (Array.isArray(list) ? list.slice(0, 12) : []).forEach((sg: any) => {
    // deno-lint-ignore no-explicit-any
    const apply: any[] = [];
    // deno-lint-ignore no-explicit-any
    (Array.isArray(sg?.apply) ? sg.apply.slice(0, 80) : []).forEach((a: any) => {
      const di = Number(a?.day) - 1, ii = Number(a?.item) - 1, field = String(a?.field ?? "");
      const it = itemAt(di, ii); if (!it || !allowed[field]) return;
      if (field === "minutes" ? it.type !== "cardio" : it.type !== "muscle") return;
      const opts = allowed[field];
      const val = opts.length ? opts.find((v) => squash(v) === squash(String(a?.value ?? ""))) : String(a?.value ?? "");
      if (val === undefined || val === "") return;
      const from = String(it.x[field] ?? "");
      if (squash(from) === squash(val)) return;
      apply.push({ day: di, item: ii, field, value: val, from, name: it.type === "cardio" ? it.x.equipment : it.x.exercise });
    });
    if (apply.length) out.push({ explanation: String(sg?.explanation ?? "").slice(0, 800), question: String(sg?.question ?? "").slice(0, 400), apply });
  });
  return out;
}

function serverKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    return keys.default ?? Object.values(keys)[0] ?? "";
  } catch { return ""; }
}

// ---------------------------------------------------------------------
// Κατάλογος ασκήσεων (τον στέλνει η εφαρμογή — ίδια λίστα με τη φόρμα προγράμματος)
// ---------------------------------------------------------------------
type Catalog = {
  groups: Record<string, { label: string; exercises: string[] }>;
  setrep: Record<string, { rep: string; rest: string }>;
  fatburn_fixed: { set: number; rep: string; rest: string };
  day_labels: string[];
  nutrition_muscle: Record<string, { kcal: string; text: string }>;
  fatburn_kcal_options: number[];
  fatburn_text: string;
  failure_options: number[];
};
const squash = (s: string) => s.toLowerCase().normalize("NFC").replace(/\s+/g, " ").trim();

function checkCatalog(c: unknown): Catalog | null {
  // deno-lint-ignore no-explicit-any
  const x = c as any;
  if (!x || typeof x !== "object" || !x.groups || typeof x.groups !== "object") return null;
  const keys = Object.keys(x.groups);
  if (!keys.length || keys.length > 30) return null;
  for (const k of keys) {
    const g = x.groups[k];
    if (!g || typeof g.label !== "string" || !Array.isArray(g.exercises) || g.exercises.length > 200) return null;
  }
  if (!x.setrep || !Array.isArray(x.day_labels) || !x.nutrition_muscle || !x.fatburn_fixed) return null;
  return x as Catalog;
}

// ---------------------------------------------------------------------
// Το εργαλείο που ΠΡΕΠΕΙ να καλέσει το AI (δομημένη απάντηση)
// ---------------------------------------------------------------------
const PROPOSE_TOOL = {
  name: "propose_program",
  description: "Επιστρέφει το νέο πρόγραμμα του πελάτη και τα μηνύματα.",
  input_schema: {
    type: "object",
    properties: {
      sensitive: { type: "boolean", description: "true αν η περίπτωση χρειάζεται έλεγχο από άνθρωπο σύμφωνα με τις κάρτες" },
      sensitive_reason: { type: "string", description: "Γιατί είναι ευαίσθητη (κενό αν δεν είναι)" },
      message_to_client: { type: "string", description: "Μήνυμα προς τον πελάτη, 2-4 προτάσεις, στον ενικό" },
      reasoning_for_trainer: { type: "string", description: "Σύντομη εξήγηση για τον προπονητή: τι άλλαξες, γιατί, ποιες κάρτες εφάρμοσες" },
      program: {
        type: "object",
        properties: {
          category: { type: "string", enum: ["muscle", "fatburn"], description: "muscle = Αύξηση Μυϊκού Ιστού, fatburn = Καύση Λίπους με βάρη" },
          nutrition_set: { type: "integer", enum: [3, 4, 5, 6], description: "Μόνο για muscle: επιλογή διατροφής (συνήθως ίση με τα σετ του προγράμματος)" },
          fatburn_kcal: { type: "integer", description: "Μόνο για fatburn: μία από τις επιτρεπτές τιμές θερμίδων" },
          instructions: { type: "string", description: "Οδηγίες προγράμματος (σύντομες)" },
          notes: { type: "string", description: "Παρατηρήσεις (προαιρετικό)" },
          days: {
            type: "array",
            items: {
              type: "object",
              properties: {
                groups: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      group_key: { type: "string", description: "Κλειδί μυϊκής ομάδας ΑΚΡΙΒΩΣ από τη λίστα" },
                      exercise: { type: "string", description: "Άσκηση ΑΚΡΙΒΩΣ όπως στη λίστα της ομάδας" },
                      set: { type: "integer", enum: [3, 4, 5, 6] },
                      failure: { type: "integer", enum: [0, -1, -2, -3] },
                    },
                    required: ["group_key", "exercise", "set", "failure"],
                  },
                },
              },
              required: ["groups"],
            },
          },
        },
        required: ["category", "days"],
      },
    },
    required: ["sensitive", "message_to_client", "reasoning_for_trainer", "program"],
  },
};

const KIND_TITLE: Record<string, string> = {
  general: "ΓΕΝΙΚΟΙ ΚΑΝΟΝΕΣ",
  forbidden: "ΑΠΑΓΟΡΕΥΣΕΙΣ (δεν παραβιάζονται ποτέ)",
  sensitive: "ΠΟΤΕ ΧΡΕΙΑΖΕΤΑΙ ΑΝΘΡΩΠΟΣ (sensitive = true)",
  knowledge: "ΓΝΩΣΗ TRANSFORMATION",
  button: "ΟΔΗΓΙΕΣ ΓΙΑ ΤΟ ΚΟΥΜΠΙ ΠΟΥ ΠΑΤΗΘΗΚΕ",
};

type Card = { kind: string; title: string; body: string; button_key: string | null; scope: string };

function buildSystemPrompt(cards: Card[], buttonKey: string, cat: Catalog): string {
  const order = ["general", "forbidden", "sensitive", "knowledge", "button"];
  const parts: string[] = [
    "Είσαι το σύστημα AI της εφαρμογής ΦΟΡΜΑ (προγράμματα TRANSFORMATION του MEGA GYM).",
    "Ακολουθείς ΑΥΣΤΗΡΑ τις κάρτες κανόνων του ιδιοκτήτη που ακολουθούν. Αν κάτι δεν καλύπτεται, ενεργείς με σύνεση και το αναφέρεις στο reasoning_for_trainer.",
  ];
  for (const k of order) {
    const list = cards.filter((c) => c.kind === k && (k !== "button" || c.button_key === buttonKey));
    if (!list.length) continue;
    parts.push(`\n## ${KIND_TITLE[k]}`);
    for (const c of list) parts.push(`### ${c.title}\n${c.body.trim()}`);
  }
  const groups = Object.entries(cat.groups)
    .map(([k, g]) => `- ${k} (${g.label}): ${g.exercises.join(" | ")}`).join("\n");
  const setrep = Object.entries(cat.setrep).map(([s, v]) => `${s} σετ → ${v.rep} επαναλήψεις, διάλειμμα ${v.rest}`).join("; ");
  parts.push(`
## ΤΕΧΝΙΚΟΙ ΚΑΝΟΝΕΣ ΤΗΣ ΕΦΑΡΜΟΓΗΣ
- Επιτρεπτές μυϊκές ομάδες (group_key) και ασκήσεις — χρησιμοποίησε ΜΟΝΟ αυτές, γραμμένες ΑΚΡΙΒΩΣ έτσι:
${groups}
- Αύξηση Μυϊκού Ιστού (muscle): σετ 3, 4, 5 ή 6 ανά άσκηση. ${setrep}. Το nutrition_set είναι συνήθως ίσο με τα σετ που επικρατούν στο πρόγραμμα.
- Καύση Λίπους (fatburn): πάντα ${cat.fatburn_fixed.set} σετ × ${cat.fatburn_fixed.rep} επαναλήψεις, διάλειμμα ${cat.fatburn_fixed.rest}. fatburn_kcal μία από: ${(cat.fatburn_kcal_options || []).join(", ")}.
- failure (UNTIL FAILURE): 0, -1, -2 ή -3.
- Έως 6 ημέρες, 3–8 ασκήσεις ανά ημέρα.
- Κάλεσε ΠΑΝΤΑ το εργαλείο propose_program, μία φορά.`);
  return parts.join("\n");
}

// ---------------------------------------------------------------------
// Έλεγχος & μετατροπή του προγράμματος του AI στη μορφή της εφαρμογής
// ---------------------------------------------------------------------
// deno-lint-ignore no-explicit-any
function toProgramRecord(p: any, cat: Catalog, versionNo: number) {
  const warnings: string[] = [];
  const lookup = new Map<string, { key: string; ex: Map<string, string> }>();
  for (const [k, g] of Object.entries(cat.groups)) {
    lookup.set(squash(k), { key: k, ex: new Map(g.exercises.map((e) => [squash(e), e])) });
  }
  const category = p?.category === "fatburn" ? "fatburn" : "muscle";
  const failOpts = cat.failure_options?.length ? cat.failure_options : [0, -1, -2, -3];
  const rawDays = Array.isArray(p?.days) ? p.days.slice(0, 6) : [];
  // deno-lint-ignore no-explicit-any
  const days: any[] = [];
  rawDays.forEach((d: { groups?: unknown[] }, di: number) => {
    // deno-lint-ignore no-explicit-any
    const groups: any[] = [];
    // deno-lint-ignore no-explicit-any
    (Array.isArray(d?.groups) ? d.groups.slice(0, 10) : []).forEach((g: any) => {
      const grp = lookup.get(squash(String(g?.group_key ?? "")));
      if (!grp) { warnings.push(`Άγνωστη μυϊκή ομάδα «${g?.group_key}» — αφαιρέθηκε`); return; }
      const ex = grp.ex.get(squash(String(g?.exercise ?? "")));
      if (!ex) { warnings.push(`Άσκηση εκτός λίστας «${g?.exercise}» — αφαιρέθηκε`); return; }
      let set: number, rep: string, rest: string;
      if (category === "fatburn") {
        ({ set, rep, rest } = cat.fatburn_fixed);
      } else {
        set = [3, 4, 5, 6].includes(Number(g?.set)) ? Number(g.set) : 3;
        const sr = cat.setrep[String(set)];
        if (!sr) { warnings.push(`Μη έγκυρα σετ για «${ex}»`); return; }
        rep = sr.rep; rest = sr.rest;
      }
      const failure = failOpts.includes(Number(g?.failure)) ? Number(g.failure) : -2;
      groups.push({ groupLabel: cat.groups[grp.key].label, exercise: ex, set, rep, rest, failure, equipment: [] });
    });
    if (groups.length) days.push({ label: cat.day_labels[days.length] || `ΗΜΕΡΑ ${di + 1}`, groups });
  });
  if (!days.length) return { record: null, warnings: warnings.concat("Το AI δεν έδωσε καμία έγκυρη ημέρα.") };

  // deno-lint-ignore no-explicit-any
  let nutrition: any = null;
  if (category === "muscle") {
    const ns = [3, 4, 5, 6].includes(Number(p?.nutrition_set)) ? Number(p.nutrition_set) : 3;
    const n = cat.nutrition_muscle[String(ns)];
    if (n) nutrition = { setChoice: ns, kcal: n.kcal, text: n.text };
  } else {
    const opts = cat.fatburn_kcal_options?.length ? cat.fatburn_kcal_options : [-500, -250, 0, 150];
    const k = opts.includes(Number(p?.fatburn_kcal)) ? Number(p.fatburn_kcal) : 0;
    nutrition = { kcal: (k > 0 ? "+" : "") + k + "kcal", text: cat.fatburn_text || "" };
  }
  const record = {
    category,
    subtype: category === "fatburn" ? "weights" : null,
    notes: String(p?.notes ?? "").slice(0, 1000),
    instructions: String(p?.instructions ?? "").slice(0, 1000),
    nutrition,
    days,
    cardioSlots: null,
    fromAI: true,
    aiVersion: versionNo,
  };
  return { record, warnings };
}

// ---------------------------------------------------------------------
// Ιστορικό πελάτη για το AI (χωρίς επώνυμο / στοιχεία επικοινωνίας)
// ---------------------------------------------------------------------
// deno-lint-ignore no-explicit-any
async function customerContext(admin: any, code: string) {
  const [{ data: cust }, { data: progs }, { data: logs }, { data: props }] = await Promise.all([
    admin.from("customers").select("name, dob, created_at").eq("code", code).maybeSingle(),
    admin.from("programs").select("created_at, days").eq("customer_code", code).order("created_at", { ascending: false }).limit(3),
    admin.from("workout_logs").select("created_at, exercise, kg, reps, set_number, failure_quality")
      .eq("customer_code", code).gte("created_at", new Date(Date.now() - 56 * 864e5).toISOString())
      .order("created_at", { ascending: false }).limit(1500),
    admin.from("ai_proposals").select("created_at, status, decision_note").eq("customer_code", code)
      .order("created_at", { ascending: false }).limit(3),
  ]);
  let age: number | null = null;
  if (cust?.dob) { const b = new Date(cust.dob); if (!isNaN(+b)) age = Math.floor((Date.now() - +b) / (365.25 * 864e5)); }

  // deno-lint-ignore no-explicit-any
  const programs = (progs ?? []).map((p: any) => {
    const r = p.days ?? {};
    return {
      date: String(p.created_at).slice(0, 10),
      category: r.category, subtype: r.subtype ?? null,
      nutrition: r.nutrition?.kcal ?? null,
      // deno-lint-ignore no-explicit-any
      days: (Array.isArray(r.days) ? r.days : []).map((d: any) => ({
        label: d.label,
        // deno-lint-ignore no-explicit-any
        exercises: (d.groups ?? []).map((g: any) => `${g.groupLabel}: ${g.exercise} — ${g.set}×${g.rep}, failure ${g.failure ?? 0}`),
        cardio: (d.cardioSlots ?? []).length || undefined,
      })),
      cardio_only_slots: Array.isArray(r.cardioSlots) ? r.cardioSlots.length : undefined,
    };
  });

  const dates = new Set<string>();
  const perWeek = new Map<number, Set<string>>();
  const ex = new Map<string, { sets: number; maxKg: number; last: string }>();
  // deno-lint-ignore no-explicit-any
  for (const l of (logs ?? []) as any[]) {
    const day = String(l.created_at).slice(0, 10);
    dates.add(day);
    const w = Math.floor((Date.now() - +new Date(l.created_at)) / (7 * 864e5));
    if (!perWeek.has(w)) perWeek.set(w, new Set());
    perWeek.get(w)!.add(day);
    const e = ex.get(l.exercise) ?? { sets: 0, maxKg: 0, last: "" };
    e.sets++; e.maxKg = Math.max(e.maxKg, Number(l.kg) || 0);
    if (!e.last) e.last = `${l.kg ?? "-"}kg × ${l.reps ?? "-"} (${day})`;
    ex.set(l.exercise, e);
  }
  const weeks = [...Array(8).keys()].map((w) => perWeek.get(w)?.size ?? 0);
  return {
    first_name: cust?.name ?? null,
    age,
    member_since: cust?.created_at ? String(cust.created_at).slice(0, 10) : null,
    last_programs: programs,
    training_last_8_weeks: {
      sessions_total: dates.size,
      sessions_per_week_newest_first: weeks,
      exercises: [...ex.entries()].sort((a, b) => b[1].sets - a[1].sets).slice(0, 30)
        .map(([name, v]) => ({ name, sets: v.sets, max_kg: v.maxKg, last: v.last })),
    },
    // deno-lint-ignore no-explicit-any
    previous_ai_proposals: (props ?? []).map((p: any) => ({ date: String(p.created_at).slice(0, 10), status: p.status, trainer_note: p.decision_note ?? undefined })),
  };
}

// ---------------------------------------------------------------------
// «Έλεγχος προγράμματος» (action = review)
// ---------------------------------------------------------------------
// deno-lint-ignore no-explicit-any
async function handleReview(admin: any, user: any, isOwner: boolean, body: any, cat: Catalog, note: string) {
  const { data: cust } = await admin.from("customers").select("code").eq("claimed_by", user.id).maybeSingle();
  if (!cust?.code) return fail(403, "no_customer", "Ο λογαριασμός σου δεν είναι συνδεδεμένος με πελάτη.");
  const programId = String(body?.program_id ?? "");
  const { data: prog } = await admin.from("programs").select("id, days, customer_code").eq("id", programId).maybeSingle();
  if (!prog || prog.customer_code !== cust.code) return fail(404, "no_program", "Το πρόγραμμα δεν βρέθηκε.");
  const record = prog.days ?? {};
  if (!record.fromClientBuilder) return fail(400, "not_own", "Ο έλεγχος γίνεται στα προγράμματα που έφτιαξες μόνος σου.");

  const { data: settings } = await admin.from("ai_settings").select("daily_limit").eq("app", APP).maybeSingle();
  const limit = isOwner ? OWNER_DAILY_LIMIT : Number(settings?.daily_limit ?? 10);
  const { count } = await admin.from("ai_usage").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).gte("created_at", new Date(Date.now() - 864e5).toISOString());
  if ((count ?? 0) >= limit) return fail(429, "rate_limited", `Έφτασες το όριο των ${limit} αιτημάτων AI για σήμερα. Δοκίμασε ξανά αύριο.`);

  // Κάρτες: η δημοσιευμένη έκδοση (αλλιώς το πρόχειρο). Αν δεν υπάρχει κάρτα για το κουμπί → βασικοί κανόνες.
  const { data: versions } = await admin.from("ai_rule_versions").select("id, version_no, status").eq("app", APP).in("status", ["draft", "published"]);
  // deno-lint-ignore no-explicit-any
  const version = (versions ?? []).find((v: any) => v.status === "published") ?? (versions ?? []).find((v: any) => v.status === "draft");
  let cards: Card[] = [];
  if (version) {
    const { data: cr } = await admin.from("ai_rule_cards").select("kind, title, body, button_key, scope")
      .eq("version_id", version.id).eq("active", true).order("sort");
    cards = ((cr ?? []) as Card[]).filter((c) => c.scope === "all" || c.scope === "program");
  }
  const order = ["general", "forbidden", "sensitive", "knowledge", "button"];
  const parts: string[] = [
    "Είσαι ο ψηφιακός προπονητής της εφαρμογής ΦΟΡΜΑ (TRANSFORMATION, MEGA GYM).",
    "Ο αθλούμενος έφτιαξε ΜΟΝΟΣ του ένα πρόγραμμα και ζητά «Έλεγχο προγράμματος». Ελέγχεις με τους κανόνες, εξηγείς απλά και για κάθε θέμα κάνεις πρόταση με ερώτηση «να το αλλάξω ή συνεχίζεις;».",
  ];
  for (const k of order) {
    const list = cards.filter((c) => c.kind === k && (k !== "button" || c.button_key === "program_check"));
    if (!list.length) continue;
    parts.push(`\n## ${KIND_TITLE[k]}`);
    for (const c of list) parts.push(`### ${c.title}\n${c.body.trim()}`);
  }
  if (!cards.some((c) => c.kind === "button" && c.button_key === "program_check")) parts.push(`\n## ΚΑΝΟΝΕΣ ΕΛΕΓΧΟΥ ΠΡΟΓΡΑΜΜΑΤΟΣ\n${DEFAULT_CHECK_RULES}`);
  const o = readOpts(body?.catalog);
  const groups = Object.entries(cat.groups).map(([k, g]) => `- ${k} (${g.label}): ${g.exercises.join(" | ")}`).join("\n");
  parts.push(`
## ΤΕΧΝΙΚΟΙ ΚΑΝΟΝΕΣ
- Ασκήσεις ΜΟΝΟ από τη λίστα, γραμμένες ΑΚΡΙΒΩΣ έτσι (group_key: ασκήσεις):
${groups}
- Επιτρεπτά: σετ ${o.set.join(", ") || "3-6"} · επαναλήψεις ${o.rep.join(" / ")} · διάλειμμα ${o.rest.join(" / ")} · tempo ${o.tempo.join(" / ")} · failure ${(cat.failure_options || [0, -1, -2, -3]).join(", ")}
- Αερόβιο: μηχάνημα από ${o.cardio_equipment.join(" / ")}, λεπτά ${o.minutes.join(", ")}.
- Οι προτάσεις αλλάζουν ΜΟΝΟ πεδία υπαρχουσών ασκήσεων (set, rep, rest, tempo, failure, minutes) με τιμές από τις επιτρεπτές· day/item όπως στην αρίθμηση του προγράμματος.
- Αν όλα είναι εντάξει: verdict = ok και καμία πρόταση.
- Κάλεσε ΠΑΝΤΑ το εργαλείο review_program, μία φορά.`);

  const ctx = await customerContext(admin, cust.code);
  const userText = [
    "Πατήθηκε το κουμπί: «Έλεγχος προγράμματος».",
    note ? `Ο αθλούμενος έγραψε: «${note}»` : "Ο αθλούμενος δεν έγραψε κάτι.",
    `ΤΟ ΠΡΟΓΡΑΜΜΑ ΠΡΟΣ ΕΛΕΓΧΟ:\n${describeProgram(record, cat)}`,
    `Ιστορικό αθλούμενου (JSON):\n${JSON.stringify(ctx).slice(0, 30_000)}`,
  ].join("\n\n");

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return fail(500, "server_config", "Λείπει το ANTHROPIC_API_KEY στον διακομιστή.");
  let aiRes: Response;
  try {
    aiRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 6000, system: parts.join("\n"),
        tools: [REVIEW_TOOL], tool_choice: { type: "auto" },
        messages: [{ role: "user", content: userText }],
      }),
    });
  } catch (e) {
    console.error("Anthropic fetch failed", e);
    return fail(502, "ai_unreachable", "Η υπηρεσία AI δεν απαντά. Δοκίμασε ξανά.");
  }
  if (!aiRes.ok) { console.error("Anthropic error", aiRes.status, await aiRes.text()); return fail(502, "ai_error", "Το AI δεν μπόρεσε να απαντήσει. Δοκίμασε ξανά σε λίγο."); }
  let ai = await aiRes.json();
  // deno-lint-ignore no-explicit-any
  let out = (ai.content ?? []).find((c: any) => c.type === "tool_use")?.input;
  if (!out) {   // το μοντέλο δεν κάλεσε το εργαλείο → μία ακόμη προσπάθεια με ρητή οδηγία
    const retry = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 6000, system: parts.join("\n"),
        tools: [REVIEW_TOOL], tool_choice: { type: "auto" },
        messages: [{ role: "user", content: userText + "\n\nΑπάντησε ΜΟΝΟ καλώντας το εργαλείο review_program." }],
      }),
    });
    if (retry.ok) { ai = await retry.json(); /* deno-lint-ignore no-explicit-any */ out = (ai.content ?? []).find((c: any) => c.type === "tool_use")?.input; }
  }
  if (!out) return fail(502, "ai_error", "Το AI δεν επέστρεψε αποτέλεσμα. Δοκίμασε ξανά.");
  await admin.from("ai_usage").insert({ user_id: user.id, kind: "program_check" });

  const sensitive = out.sensitive === true || out.verdict === "unsafe";
  const suggestions = sensitive ? [] : validateSuggestions(out.suggestions, record, cat, o);
  const good = (Array.isArray(out.good) ? out.good : []).slice(0, 8).map((g: unknown) => String(g ?? "").slice(0, 300)).filter(Boolean);
  return json({
    verdict: sensitive ? "unsafe" : (suggestions.length ? "improve" : "ok"),
    sensitive, sensitive_reason: String(out.sensitive_reason ?? "").slice(0, 500),
    summary: String(out.summary ?? "").slice(0, 1500), good, suggestions,
    rules: cards.some((c) => c.kind === "button" && c.button_key === "program_check") ? "cards" : "default",
    rules_version: version?.version_no ?? null,
  });
}

// ---------------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return fail(405, "method_not_allowed", "Μη επιτρεπτή μέθοδος.");

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, serverKey(), { auth: { persistSession: false, autoRefreshToken: false } });
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return fail(401, "unauthorized", "Πρέπει να είσαι συνδεδεμένος.");
  const { data: { user }, error: userErr } = await admin.auth.getUser(token);
  if (userErr || !user) return fail(401, "unauthorized", "Πρέπει να είσαι συνδεδεμένος.");

  // deno-lint-ignore no-explicit-any
  let body: any;
  try { body = await req.json(); } catch { return fail(400, "bad_request", "Μη έγκυρο αίτημα."); }
  const action = body?.action;
  const buttonKey = String(body?.button_key ?? "");
  const note = String(body?.note ?? "").slice(0, 600);
  if (!BUTTONS[buttonKey]) return fail(400, "bad_button", "Άγνωστο κουμπί.");
  if (JSON.stringify(body?.catalog ?? {}).length > 300_000) return fail(413, "too_large", "Πολύ μεγάλο αίτημα.");
  const cat = checkCatalog(body?.catalog);
  if (!cat) return fail(400, "bad_catalog", "Λείπει η λίστα ασκήσεων.");

  const { data: profile } = await admin.from("profiles").select("role").eq("id", user.id).maybeSingle();
  const isOwner = profile?.role === "owner";
  if (action === "review") return await handleReview(admin, user, isOwner, body, cat, note);
  const isSim = action === "simulate";
  if (isSim && !isOwner) return fail(403, "forbidden", "Μόνο ο owner κάνει δοκιμές.");
  if (!isSim && action !== "request") return fail(400, "bad_action", "Άγνωστη ενέργεια.");

  const { data: settings } = await admin.from("ai_settings").select("*").eq("app", APP).maybeSingle();
  const s = settings ?? { approval_program: true, test_customer_codes: [], daily_limit: 10 };

  // --- Ποιος πελάτης
  let customerCode: string | null = null;
  if (isSim) {
    customerCode = body?.customer_code ? String(body.customer_code).slice(0, 40) : null;
  } else {
    const { data: cust } = await admin.from("customers").select("code").eq("claimed_by", user.id).maybeSingle();
    if (!cust?.code) return fail(403, "no_customer", "Ο λογαριασμός σου δεν είναι συνδεδεμένος με πελάτη.");
    customerCode = cust.code;
    // Υπάρχει ήδη πρόταση που περιμένει έγκριση; Δεν φτιάχνουμε δεύτερη.
    const { data: pend } = await admin.from("ai_proposals").select("id, message_to_client")
      .eq("customer_code", customerCode).eq("button_key", buttonKey).eq("status", "pending").limit(1).maybeSingle();
    if (pend) return json({ status: "pending", proposal_id: pend.id, already: true, message: "Το νέο σου πρόγραμμα έχει ήδη ετοιμαστεί και το ελέγχει ο προπονητής σου." });
  }

  // --- Όριο χρήσης
  const limit = isOwner ? OWNER_DAILY_LIMIT : Number(s.daily_limit ?? 10);
  const { count } = await admin.from("ai_usage").select("id", { count: "exact", head: true })
    .eq("user_id", user.id).gte("created_at", new Date(Date.now() - 864e5).toISOString());
  if ((count ?? 0) >= limit) return fail(429, "rate_limited", `Έφτασες το όριο των ${limit} αιτημάτων για σήμερα. Δοκίμασε ξανά αύριο.`);

  // --- Ποια έκδοση κανόνων
  const { data: versions } = await admin.from("ai_rule_versions").select("id, version_no, status").eq("app", APP).in("status", ["draft", "published"]);
  // deno-lint-ignore no-explicit-any
  const draft = (versions ?? []).find((v: any) => v.status === "draft");
  // deno-lint-ignore no-explicit-any
  const published = (versions ?? []).find((v: any) => v.status === "published");
  let version = published;
  let usedDraft = false;
  if (isSim) {
    version = body?.version === "draft" ? draft : published;
    usedDraft = body?.version === "draft";
    if (!version) return fail(400, "no_version", body?.version === "draft" ? "Δεν υπάρχει πρόχειρο." : "Δεν υπάρχει δημοσιευμένη έκδοση.");
  } else if (draft && (s.test_customer_codes ?? []).includes(customerCode)) {
    version = draft; usedDraft = true;
  }
  if (!version) return fail(503, "not_ready", "Η λειτουργία δεν είναι ακόμα διαθέσιμη. Ο προπονητής σου ετοιμάζει τους κανόνες.");

  const { data: cardsRaw } = await admin.from("ai_rule_cards").select("kind, title, body, button_key, scope")
    .eq("version_id", version.id).eq("active", true).order("sort");
  const scope = BUTTONS[buttonKey].scope;
  const cards = ((cardsRaw ?? []) as Card[]).filter((c) => c.scope === "all" || c.scope === scope);
  if (!cards.some((c) => c.kind === "button" && c.button_key === buttonKey)) {
    return fail(503, "no_button_card", isSim
      ? `Η έκδοση ${version.version_no} δεν έχει ενεργή κάρτα συνδεδεμένη με το κουμπί «${BUTTONS[buttonKey].label}».`
      : "Η λειτουργία δεν είναι ακόμα διαθέσιμη.");
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return fail(500, "server_config", "Λείπει το ANTHROPIC_API_KEY στον διακομιστή.");

  const ctx = customerCode ? await customerContext(admin, customerCode) : { note: "Δοκιμαστικός πελάτης χωρίς ιστορικό." };
  // deno-lint-ignore no-explicit-any
  const lastProg = (ctx as any).last_programs?.[0];
  const unsupported = lastProg && (lastProg.subtype === "cardio" || lastProg.subtype === "combo");

  const userText = [
    `Πατήθηκε το κουμπί: «${BUTTONS[buttonKey].label}».`,
    note ? `Ο πελάτης έγραψε: «${note}»` : "Ο πελάτης δεν έγραψε κάτι.",
    `Στοιχεία πελάτη (JSON):\n${JSON.stringify(ctx).slice(0, 40_000)}`,
  ].join("\n\n");

  let aiRes: Response;
  try {
    aiRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 6000,
        system: buildSystemPrompt(cards, buttonKey, cat),
        tools: [PROPOSE_TOOL],
        tool_choice: { type: "auto" },
        messages: [{ role: "user", content: userText }],
      }),
    });
  } catch (e) {
    console.error("Anthropic fetch failed", e);
    return fail(502, "ai_unreachable", "Η υπηρεσία AI δεν απαντά. Δοκίμασε ξανά.");
  }
  if (!aiRes.ok) {
    console.error("Anthropic error", aiRes.status, await aiRes.text());
    return fail(502, "ai_error", "Το AI δεν μπόρεσε να απαντήσει. Δοκίμασε ξανά σε λίγο.");
  }
  const ai = await aiRes.json();
  // deno-lint-ignore no-explicit-any
  const out = (ai.content ?? []).find((c: any) => c.type === "tool_use")?.input;
  if (!out?.program) return fail(502, "ai_error", "Το AI δεν επέστρεψε πρόγραμμα. Δοκίμασε ξανά.");

  const { record, warnings } = toProgramRecord(out.program, cat, version.version_no);
  if (!record) return fail(502, "ai_invalid", "Το AI έδωσε πρόγραμμα που δεν πέρασε τον έλεγχο. Δοκίμασε ξανά.");

  let sensitive = out.sensitive === true;
  let sensitiveReason = String(out.sensitive_reason ?? "").slice(0, 500);
  if (unsupported) {
    sensitive = true;
    sensitiveReason = (sensitiveReason ? sensitiveReason + " · " : "") + "Το τρέχον πρόγραμμα είναι με αερόβιο — δεν ανανεώνεται ακόμα αυτόματα.";
  }
  const message = String(out.message_to_client ?? "").slice(0, 1500);
  const reasoning = String(out.reasoning_for_trainer ?? "").slice(0, 3000);
  const needsApproval = sensitive || s.approval_program !== false;

  await admin.from("ai_usage").insert({ user_id: user.id, kind: isSim ? "simulate" : buttonKey });

  if (isSim) {
    return json({
      version_no: version.version_no, used_draft: usedDraft, sensitive, sensitive_reason: sensitiveReason,
      message_to_client: message, reasoning, program: record, warnings,
      would_status: needsApproval ? "pending" : "auto_applied",
    });
  }

  // --- Πραγματικό αίτημα: αποθήκευση πρότασης (και εφαρμογή αν επιτρέπεται)
  let status = needsApproval ? "pending" : "auto_applied";
  let programId: string | null = null;
  if (!needsApproval) {
    const { data: prog, error: pErr } = await admin.from("programs")
      .insert({ customer_code: customerCode, created_by: user.id, days: record }).select("id").single();
    if (pErr) { console.error("program insert failed", pErr); status = "pending"; }
    else programId = String(prog.id);
  }
  const { data: prop, error: propErr } = await admin.from("ai_proposals").insert({
    app: APP, customer_code: customerCode, user_id: user.id, button_key: buttonKey, status,
    version_id: version.id, version_no: version.version_no, used_draft: usedDraft,
    sensitive, sensitive_reason: sensitiveReason || null, request_note: note || null,
    message_to_client: message, reasoning: reasoning + (warnings.length ? `\n\nΈλεγχος εφαρμογής: ${warnings.join("; ")}` : ""),
    proposal: record, applied_program_id: programId,
    decided_at: status === "auto_applied" ? new Date().toISOString() : null,
  }).select("id").single();
  if (propErr) console.error("proposal insert failed", propErr);

  return json({
    status, proposal_id: prop?.id ?? null, sensitive,
    message: status === "auto_applied"
      ? message
      : "Το νέο σου πρόγραμμα ετοιμάστηκε! Ο προπονητής σου θα το ελέγξει και θα εμφανιστεί στα προγράμματά σου.",
  });
});
