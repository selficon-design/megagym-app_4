-- Ημερομηνία γέννησης (η ηλικία υπολογίζεται) + λιπομετρήσεις
alter table public.client_profiles add column if not exists birth_date date;

create table if not exists public.body_fat_logs (
  id             bigserial primary key,
  customer_code  text not null,
  log_date       date not null,
  method         text not null check (method in ('analysis','kanellakis','expert')),
  -- analysis   : ο αθλούμενος έκανε σωματική ανάλυση και γράφει το ποσοστό του
  -- kanellakis : υπολογισμός με μεζούρα (κοιλιά, γοφοί, βραχίονας + ηλικία, φύλο, ύψος)
  -- expert     : σωματική ανάλυση από expert του TRANSFORMATION στο κατάστημα (ΔΕΝ το γράφει ο αθλούμενος)
  fat_pct        numeric(4,1) not null check (fat_pct between 1 and 75),
  measurements   jsonb,
  created_by     uuid default auth.uid(),
  created_at     timestamptz not null default now(),
  unique (customer_code, log_date, method)
);
create index if not exists body_fat_logs_customer_idx on public.body_fat_logs (customer_code, log_date desc);
alter table public.body_fat_logs enable row level security;

drop policy if exists "body fat own read" on public.body_fat_logs;
create policy "body fat own read" on public.body_fat_logs for select
  using (customer_code in (select code from public.customers where claimed_by = auth.uid()));
drop policy if exists "body fat own write" on public.body_fat_logs;
create policy "body fat own write" on public.body_fat_logs for insert
  with check (method <> 'expert' and customer_code in (select code from public.customers where claimed_by = auth.uid()));
drop policy if exists "body fat own update" on public.body_fat_logs;
create policy "body fat own update" on public.body_fat_logs for update
  using (method <> 'expert' and customer_code in (select code from public.customers where claimed_by = auth.uid()))
  with check (method <> 'expert' and customer_code in (select code from public.customers where claimed_by = auth.uid()));
drop policy if exists "body fat own delete" on public.body_fat_logs;
create policy "body fat own delete" on public.body_fat_logs for delete
  using (method <> 'expert' and customer_code in (select code from public.customers where claimed_by = auth.uid()));
drop policy if exists "body fat staff read" on public.body_fat_logs;
create policy "body fat staff read" on public.body_fat_logs for select
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('trainer','supervisor','owner')));
