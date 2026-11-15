-- =====================================================================
-- ΦΟΡΜΑ — Καταγραφή αερόβιων στο ιστορικό προπονήσεων
--   Όταν ο αθλούμενος απαντά «ΝΑΙ, εκτελέστηκε» για ένα αερόβιο του προγράμματός του.
--   Χωριστός πίνακας ώστε να μην αλλοιώνονται οι όγκοι (kg × reps) των βαρών.
-- Ο αθλούμενος γράφει/βλέπει τα δικά του· οι προπονητές βλέπουν όλα.
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.cardio_logs (
  id             uuid primary key default gen_random_uuid(),
  customer_code  text not null references public.customers(code) on delete cascade,
  program_name   text,
  day_label      text,
  equipment      text not null,
  minutes        numeric(5,1) check (minutes is null or minutes between 0 and 600),
  created_by     uuid default auth.uid(),
  created_at     timestamptz not null default now()
);
create index if not exists cardio_logs_customer_idx on public.cardio_logs (customer_code, created_at desc);
alter table public.cardio_logs enable row level security;

drop policy if exists "cardio logs own" on public.cardio_logs;
create policy "cardio logs own" on public.cardio_logs for all
  using (customer_code in (select code from public.customers where claimed_by = auth.uid()))
  with check (customer_code in (select code from public.customers where claimed_by = auth.uid()));
drop policy if exists "cardio logs staff read" on public.cardio_logs;
create policy "cardio logs staff read" on public.cardio_logs for select
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('trainer','supervisor','owner')));
