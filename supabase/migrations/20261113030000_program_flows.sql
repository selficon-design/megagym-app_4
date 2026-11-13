-- =====================================================================
-- ΦΟΡΜΑ — Οργανόγραμμα έτοιμων προγραμμάτων (ένα ανά φύλο)
--   graph = {
--     pos:   { "<template id>": { "x": .., "y": .. } },              -- θέσεις κουτιών
--     edges: [ { "id", "from", "to", "rule", "x", "y" } ]           -- συνδέσεις με προαιρετικό κανόνα
--   }
--   rule = κείμενο που θα διαβάζει το AI (π.χ. «αν ο πελάτης ζητήσει έμφαση στο πάνω σώμα»).
--   Σύνδεση χωρίς κανόνα = η κανονική συνέχεια του προγράμματος.
-- Ανάγνωση: συνδεδεμένοι (και το AI μέσω Edge Function). Αλλαγές: μόνο owner.
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.program_flows (
  gender      text primary key,                 -- 'ΑΝΔΡΕΣ' | 'ΓΥΝΑΙΚΕΣ'
  graph       jsonb not null default '{"pos":{},"edges":[]}'::jsonb,
  updated_by  uuid default auth.uid() references auth.users(id) on delete set null,
  updated_at  timestamptz not null default now()
);
alter table public.program_flows enable row level security;

drop policy if exists "program flows read" on public.program_flows;
create policy "program flows read" on public.program_flows for select to authenticated using (true);
drop policy if exists "program flows owner insert" on public.program_flows;
create policy "program flows owner insert" on public.program_flows for insert with check (public.ai_is_owner());
drop policy if exists "program flows owner update" on public.program_flows;
create policy "program flows owner update" on public.program_flows for update using (public.ai_is_owner()) with check (public.ai_is_owner());
drop policy if exists "program flows owner delete" on public.program_flows;
create policy "program flows owner delete" on public.program_flows for delete using (public.ai_is_owner());
