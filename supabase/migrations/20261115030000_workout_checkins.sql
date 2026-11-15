-- =====================================================================
-- ΦΟΡΜΑ — Ερωτήσεις του expert πριν την προπόνηση & αξιολόγηση μετά
--   kind = 'pre'  : πώς νιώθει, κούραση, ενέργεια, πόνοι κ.λπ. (πριν την προπόνηση)
--   kind = 'post' : πώς τα πήγε (μετά την προπόνηση ή όταν σταματήσει νωρίτερα)
--   answers = { "<κλειδί ερώτησης>": τιμή, ... , "note": "ελεύθερο κείμενο" }
--   Τα διαβάζει το AI για να δίνει συμβουλές.
-- Ο αθλούμενος γράφει/βλέπει τα δικά του· οι προπονητές βλέπουν όλα.
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.workout_checkins (
  id             uuid primary key default gen_random_uuid(),
  customer_code  text not null references public.customers(code) on delete cascade,
  program_id     text not null default '',
  program_name   text,
  day_label      text,
  log_date       date not null default ((now() at time zone 'Europe/Athens')::date),
  kind           text not null check (kind in ('pre','post')),
  answers        jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now(),
  unique (customer_code, program_id, log_date, kind)
);
create index if not exists workout_checkins_customer_idx on public.workout_checkins (customer_code, created_at desc);
alter table public.workout_checkins enable row level security;

drop policy if exists "workout checkins own" on public.workout_checkins;
create policy "workout checkins own" on public.workout_checkins for all
  using (customer_code in (select code from public.customers where claimed_by = auth.uid()))
  with check (customer_code in (select code from public.customers where claimed_by = auth.uid()));
drop policy if exists "workout checkins staff read" on public.workout_checkins;
create policy "workout checkins staff read" on public.workout_checkins for select
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('trainer','supervisor','owner')));
