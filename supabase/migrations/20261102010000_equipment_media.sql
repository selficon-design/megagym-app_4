-- =====================================================================
-- ΦΟΡΜΑ — Φωτογραφίες & βίντεο εξοπλισμού (ανεβαίνουν από την εφαρμογή)
--   Ένα «κλειδί» ανά μηχάνημα/εξοπλισμό (το όνομά του όπως στη λίστα της εφαρμογής).
--   Υπερισχύει της φωτογραφίας/βίντεο της λίστας, και ισχύει και για ΗΔΗ αποθηκευμένα προγράμματα.
--   video_id = κωδικός βίντεο στο Bunny Stream.
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.equipment_media (
  name           text primary key,
  photo_url      text,
  video_id       text,
  video_title    text,
  video_status   integer,        -- 4 = έτοιμο (κατάσταση Bunny)
  updated_by     uuid default auth.uid() references auth.users(id) on delete set null,
  updated_at     timestamptz not null default now()
);
alter table public.equipment_media enable row level security;

drop policy if exists "equipment media read" on public.equipment_media;
create policy "equipment media read" on public.equipment_media for select to authenticated using (true);
drop policy if exists "equipment media owner insert" on public.equipment_media;
create policy "equipment media owner insert" on public.equipment_media for insert with check (public.ai_is_owner());
drop policy if exists "equipment media owner update" on public.equipment_media;
create policy "equipment media owner update" on public.equipment_media for update using (public.ai_is_owner()) with check (public.ai_is_owner());
drop policy if exists "equipment media owner delete" on public.equipment_media;
create policy "equipment media owner delete" on public.equipment_media for delete using (public.ai_is_owner());
