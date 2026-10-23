-- =====================================================================
-- ΦΟΡΜΑ — Εκπαίδευση AI Διατροφής (διορθώσεις βάρους από τον owner)
-- Τρέξε το μία φορά στο Supabase → SQL Editor → New query → Run.
-- Δεν αγγίζει κανέναν υπάρχοντα πίνακα.
-- =====================================================================
create table if not exists public.ai_food_calibration (
  id          uuid primary key default gen_random_uuid(),
  food_name   text not null,             -- όνομα τροφίμου (όπως το διόρθωσε ο owner)
  ai_name     text,                      -- όνομα που έδωσε αρχικά το AI
  ai_grams    numeric(7,1) not null check (ai_grams > 0),
  true_grams  numeric(7,1) not null check (true_grams > 0),  -- βάρος από ζυγαριά
  note        text,
  created_by  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now()
);
create index if not exists ai_food_calibration_time_idx on public.ai_food_calibration (created_at desc);

alter table public.ai_food_calibration enable row level security;

-- Μόνο ο owner βλέπει / προσθέτει / σβήνει διορθώσεις.
-- (Η Edge Function τις διαβάζει με το κλειδί διακομιστή για όλους τους πελάτες.)
drop policy if exists "calibration owner select" on public.ai_food_calibration;
create policy "calibration owner select" on public.ai_food_calibration
  for select using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'owner'));

drop policy if exists "calibration owner insert" on public.ai_food_calibration;
create policy "calibration owner insert" on public.ai_food_calibration
  for insert with check (
    created_by = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'owner')
  );

drop policy if exists "calibration owner delete" on public.ai_food_calibration;
create policy "calibration owner delete" on public.ai_food_calibration
  for delete using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'owner'));
