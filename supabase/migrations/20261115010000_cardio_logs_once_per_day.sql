-- =====================================================================
-- ΦΟΡΜΑ — Ένα αερόβιο καταγράφεται μία φορά την ημέρα
--   slot     = θέση του αερόβιου μέσα στην ημέρα του προγράμματος (για να ξεχωρίζουν δύο ίδια μηχανήματα)
--   log_date = ημερομηνία Ελλάδας
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
alter table public.cardio_logs add column if not exists slot integer;
alter table public.cardio_logs add column if not exists log_date date not null default ((now() at time zone 'Europe/Athens')::date);
-- όσα γράφτηκαν διπλά πριν το κλείδωμα: κρατάμε την πρώτη καταγραφή
update public.cardio_logs set log_date = (created_at at time zone 'Europe/Athens')::date;
delete from public.cardio_logs a using public.cardio_logs b
where a.customer_code = b.customer_code and coalesce(a.program_name,'') = coalesce(b.program_name,'')
  and coalesce(a.day_label,'') = coalesce(b.day_label,'') and coalesce(a.slot,-1) = coalesce(b.slot,-1)
  and a.equipment = b.equipment and a.log_date = b.log_date
  and (a.created_at > b.created_at or (a.created_at = b.created_at and a.id > b.id));
create unique index if not exists cardio_logs_once_per_day
  on public.cardio_logs (customer_code, coalesce(program_name,''), coalesce(day_label,''), coalesce(slot,-1), equipment, log_date);
