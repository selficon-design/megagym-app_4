-- Ειδοποιήσεις «Τέλος διαλείμματος» (Web Push) όταν η εφαρμογή είναι στο παρασκήνιο / κλειδωμένη οθόνη.

-- Οι συσκευές (κινητά/browser) κάθε χρήστη που έδωσαν άδεια για ειδοποιήσεις
create table if not exists public.push_subscriptions (
  id          bigserial primary key,
  user_id     uuid not null default auth.uid(),
  endpoint    text not null unique,
  p256dh      text not null,
  auth        text not null,
  user_agent  text,
  created_at  timestamptz not null default now(),
  last_ok_at  timestamptz
);
create index if not exists push_subscriptions_user_idx on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
drop policy if exists "push subs own" on public.push_subscriptions;
create policy "push subs own" on public.push_subscriptions for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Προγραμματισμένες ειδοποιήσεις (π.χ. τέλος διαλείμματος σε 90″)
create table if not exists public.push_jobs (
  id          bigserial primary key,
  user_id     uuid not null,
  tag         text not null default 'rest',
  send_at     timestamptz not null,
  payload     jsonb not null,
  token       text not null,                 -- μυστικό για τις εσωτερικές κλήσεις της υπηρεσίας
  status      text not null default 'pending' check (status in ('pending','sent','canceled','failed')),
  created_at  timestamptz not null default now(),
  done_at     timestamptz
);
create index if not exists push_jobs_user_pending_idx on public.push_jobs (user_id, tag) where status = 'pending';
alter table public.push_jobs enable row level security;
-- Μόνο ανάγνωση των δικών σου· τα γράφει η υπηρεσία (service role)
drop policy if exists "push jobs own read" on public.push_jobs;
create policy "push jobs own read" on public.push_jobs for select using (user_id = auth.uid());
