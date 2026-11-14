-- =====================================================================
-- ΦΟΡΜΑ — Προσωπικά στοιχεία αθλούμενου & ζυγολόγιο
--   client_profiles : όνομα, επώνυμο, nickname, ύψος, βάρος, ηλικία, ποσοστό λίπους,
--                     και ποιο πρόγραμμα έχει ορίσει ως «Το πρόγραμμά μου»
--   weight_logs     : ένα βάρος ανά ημέρα (ζυγολόγιο)
-- Ο αθλούμενος βλέπει/αλλάζει μόνο τα δικά του. Οι προπονητές (trainer/supervisor/owner) τα διαβάζουν.
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.client_profiles (
  customer_code  text primary key,
  first_name     text,
  last_name      text,
  nickname       text,
  height_cm      numeric(5,1) check (height_cm is null or height_cm between 50 and 260),
  weight_kg      numeric(5,1) check (weight_kg is null or weight_kg between 20 and 400),
  age            integer      check (age is null or age between 5 and 120),
  body_fat_pct   numeric(4,1) check (body_fat_pct is null or body_fat_pct between 1 and 75),
  my_program_id  text,                                   -- id του προγράμματος «Το πρόγραμμά μου»
  updated_at     timestamptz not null default now()
);
alter table public.client_profiles enable row level security;

create table if not exists public.weight_logs (
  id             bigserial primary key,
  customer_code  text not null,
  log_date       date not null,
  weight_kg      numeric(5,1) not null check (weight_kg between 20 and 400),
  created_at     timestamptz not null default now(),
  unique (customer_code, log_date)
);
create index if not exists weight_logs_customer_idx on public.weight_logs (customer_code, log_date desc);
alter table public.weight_logs enable row level security;

-- ο αθλούμενος: μόνο ο δικός του κωδικός πελάτη
drop policy if exists "client profiles own" on public.client_profiles;
create policy "client profiles own" on public.client_profiles for all
  using (customer_code in (select code from public.customers where claimed_by = auth.uid()))
  with check (customer_code in (select code from public.customers where claimed_by = auth.uid()));
drop policy if exists "weight logs own" on public.weight_logs;
create policy "weight logs own" on public.weight_logs for all
  using (customer_code in (select code from public.customers where claimed_by = auth.uid()))
  with check (customer_code in (select code from public.customers where claimed_by = auth.uid()));

-- οι προπονητές διαβάζουν
drop policy if exists "client profiles staff read" on public.client_profiles;
create policy "client profiles staff read" on public.client_profiles for select
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('trainer','supervisor','owner')));
drop policy if exists "weight logs staff read" on public.weight_logs;
create policy "weight logs staff read" on public.weight_logs for select
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('trainer','supervisor','owner')));
