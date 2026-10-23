-- =====================================================================
-- ΦΟΡΜΑ — Διατροφή: καταγραφή γευμάτων (με ανάλυση φωτογραφίας από AI)
-- Τρέξε το μία φορά στο Supabase → SQL Editor → New query → Run.
-- =====================================================================

-- 1) Τα γεύματα κάθε πελάτη
create table if not exists public.meal_logs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  customer_code text,
  meal_date     date not null,                       -- τοπική ημερομηνία του γεύματος
  meal_type     text check (meal_type in ('breakfast','lunch','dinner','snack')),
  items         jsonb not null default '[]'::jsonb,  -- [{name, grams, kcal, protein_g, carbs_g, fat_g}]
  total_kcal    integer not null default 0,
  protein_g     numeric(6,1) not null default 0,
  carbs_g       numeric(6,1) not null default 0,
  fat_g         numeric(6,1) not null default 0,
  note          text,
  source        text not null default 'photo' check (source in ('photo','manual')),
  created_at    timestamptz not null default now()
);

create index if not exists meal_logs_user_date_idx on public.meal_logs (user_id, meal_date);
create index if not exists meal_logs_code_date_idx on public.meal_logs (customer_code, meal_date);

alter table public.meal_logs enable row level security;

-- Ο πελάτης βλέπει / γράφει / σβήνει μόνο τα δικά του γεύματα
drop policy if exists "meal_logs own select" on public.meal_logs;
create policy "meal_logs own select" on public.meal_logs
  for select using (user_id = auth.uid());

drop policy if exists "meal_logs own insert" on public.meal_logs;
create policy "meal_logs own insert" on public.meal_logs
  for insert with check (
    user_id = auth.uid()
    and (customer_code is null
         or customer_code in (select code from public.customers where claimed_by = auth.uid()))
  );

drop policy if exists "meal_logs own update" on public.meal_logs;
create policy "meal_logs own update" on public.meal_logs
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "meal_logs own delete" on public.meal_logs;
create policy "meal_logs own delete" on public.meal_logs
  for delete using (user_id = auth.uid());

-- Οι προπονητές (trainer / supervisor / owner) μπορούν να διαβάζουν τα γεύματα των πελατών
drop policy if exists "meal_logs trainers read" on public.meal_logs;
create policy "meal_logs trainers read" on public.meal_logs
  for select using (
    exists (select 1 from public.profiles p
            where p.id = auth.uid() and p.role in ('trainer','supervisor','owner'))
  );

-- 2) Μετρητής χρήσης του AI (για όριο φωτογραφιών ανά ημέρα).
--    Χωρίς policies: τον διαβάζει/γράφει ΜΟΝΟ η Edge Function με το service role key.
create table if not exists public.meal_ai_usage (
  id         bigserial primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists meal_ai_usage_user_time_idx on public.meal_ai_usage (user_id, created_at);
alter table public.meal_ai_usage enable row level security;
