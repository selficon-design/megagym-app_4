-- Ημερολόγιο δουλειάς στον builder των έτοιμων προγραμμάτων: τι αποθηκεύτηκε, πότε και πού (για το «🕘 Πού έμεινα»)
create table if not exists public.template_activity (
  id bigserial primary key,
  user_id uuid default auth.uid(),
  template_id uuid,
  program_name text,
  category text,
  summary text,
  place jsonb,               -- { day: 2, item: 1, group: 'ΠΟΔΙΑ' }
  created_at timestamptz not null default now()
);
create index if not exists template_activity_created_idx on public.template_activity (created_at desc);
alter table public.template_activity enable row level security;
drop policy if exists "template activity staff read" on public.template_activity;
drop policy if exists "template activity staff insert" on public.template_activity;
create policy "template activity staff read" on public.template_activity for select using (public.tpl_trash_is_staff());
create policy "template activity staff insert" on public.template_activity for insert with check (public.tpl_trash_is_staff());
