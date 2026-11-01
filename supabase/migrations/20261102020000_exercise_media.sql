-- =====================================================================
-- ΦΟΡΜΑ — Βίντεο & φωτογραφία ΑΣΚΗΣΗΣ ανά συνδυασμό «άσκηση + μηχάνημα»
--   Π.χ. «Έλξεις πλάτης από πάνω προς τα κάτω» στο «LAT Technogym» έχει δικό του βίντεο.
--   Η φωτογραφία του ΜΗΧΑΝΗΜΑΤΟΣ μένει στο equipment_media (μία για όλες τις ασκήσεις).
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.exercise_media (
  exercise            text not null,     -- όνομα άσκησης, όπως στη λίστα της εφαρμογής
  equipment           text not null,     -- όνομα μηχανήματος/εξοπλισμού
  video_id            text,              -- κωδικός βίντεο στο Bunny Stream
  video_status        integer,           -- 4 = έτοιμο
  exercise_photo_url  text,
  updated_by          uuid default auth.uid() references auth.users(id) on delete set null,
  updated_at          timestamptz not null default now(),
  primary key (exercise, equipment)
);
alter table public.exercise_media enable row level security;

drop policy if exists "exercise media read" on public.exercise_media;
create policy "exercise media read" on public.exercise_media for select to authenticated using (true);
drop policy if exists "exercise media owner insert" on public.exercise_media;
create policy "exercise media owner insert" on public.exercise_media for insert with check (public.ai_is_owner());
drop policy if exists "exercise media owner update" on public.exercise_media;
create policy "exercise media owner update" on public.exercise_media for update using (public.ai_is_owner()) with check (public.ai_is_owner());
drop policy if exists "exercise media owner delete" on public.exercise_media;
create policy "exercise media owner delete" on public.exercise_media for delete using (public.ai_is_owner());
