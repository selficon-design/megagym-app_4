-- =====================================================================
-- ΦΟΡΜΑ — Ένα αερόβιο καταγράφεται μία φορά την ημέρα
--   slot     = θέση του αερόβιου μέσα στην ημέρα του προγράμματος (για να ξεχωρίζουν δύο ίδια μηχανήματα)
--   log_date = ημερομηνία Ελλάδας
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
alter table public.cardio_logs add column if not exists slot integer;
alter table public.cardio_logs add column if not exists log_date date not null default ((now() at time zone 'Europe/Athens')::date);
create unique index if not exists cardio_logs_once_per_day
  on public.cardio_logs (customer_code, coalesce(program_name,''), coalesce(day_label,''), coalesce(slot,-1), equipment, log_date);
