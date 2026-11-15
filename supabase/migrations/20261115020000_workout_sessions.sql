-- =====================================================================
-- ΦΟΡΜΑ — Πρόοδος προπόνησης ανά ημέρα προγράμματος
--   Μία γραμμή ανά (πελάτης, πρόγραμμα, ημερομηνία, ημέρα προγράμματος).
--   progress = { "<θέση άσκησης>": <set που έγιναν> }  — ενημερώνεται σε κάθε set (χρονόμετρο ή υπολογιστής)
--   completed = έγιναν όλα τα set και τα αερόβια της ημέρας
--   Χρησιμοποιείται από το «ΕΝΑΡΞΗ ΠΡΟΓΡΑΜΜΑΤΟΣ ΓΥΜΝΑΣΤΙΚΗΣ» (ποια ημέρα σειρά, συνέχεια από το επόμενο set).
-- Ο αθλούμενος γράφει/βλέπει τα δικά του· οι προπονητές βλέπουν όλα.
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.workout_sessions (
  id             uuid primary key default gen_random_uuid(),
  customer_code  text not null references public.customers(code) on delete cascade,
  program_id     text not null,
  day_index      integer not null check (day_index between 0 and 50),
  day_label      text,
  log_date       date not null default ((now() at time zone 'Europe/Athens')::date),
  progress       jsonb not null default '{}'::jsonb,
  total_sets     integer,
  done_sets      integer,
  completed      boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (customer_code, program_id, log_date, day_index)
);
create index if not exists workout_sessions_lookup on public.workout_sessions (customer_code, program_id, log_date desc, updated_at desc);
alter table public.workout_sessions enable row level security;

drop policy if exists "workout sessions own" on public.workout_sessions;
create policy "workout sessions own" on public.workout_sessions for all
  using (customer_code in (select code from public.customers where claimed_by = auth.uid()))
  with check (customer_code in (select code from public.customers where claimed_by = auth.uid()));
drop policy if exists "workout sessions staff read" on public.workout_sessions;
create policy "workout sessions staff read" on public.workout_sessions for select
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('trainer','supervisor','owner')));
