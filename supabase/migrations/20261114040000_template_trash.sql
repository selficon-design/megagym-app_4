-- =====================================================================
-- ΦΟΡΜΑ — Κάδος διαγραμμένων έτοιμων προγραμμάτων
--   Κάθε διαγραφή από template_programs αντιγράφει πρώτα το πρόγραμμα στον κάδο (trigger).
--   Κρατάμε τα 10 τελευταία. Επαναφορά με restore_template_program(<id κάδου>).
--   Διαβάζουν/επαναφέρουν: trainer, supervisor, owner.
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.template_programs_trash (
  id           bigserial primary key,
  template_id  uuid not null,
  name         text,
  row          jsonb not null,
  deleted_at   timestamptz not null default now(),
  deleted_by   uuid
);
alter table public.template_programs_trash enable row level security;

create or replace function public.tpl_trash_is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('trainer','supervisor','owner'))
$$;

drop policy if exists "template trash staff read" on public.template_programs_trash;
create policy "template trash staff read" on public.template_programs_trash for select using (public.tpl_trash_is_staff());

-- 1) Trigger: πριν διαγραφεί, πάει στον κάδο· μένουν μόνο τα 10 τελευταία
create or replace function public.tpl_trash_on_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.template_programs_trash (template_id, name, row, deleted_by)
  values (old.id, old.name, to_jsonb(old), auth.uid());
  delete from public.template_programs_trash
  where id not in (select id from public.template_programs_trash order by deleted_at desc, id desc limit 10);
  return old;
end $$;
drop trigger if exists tpl_trash_on_delete on public.template_programs;
create trigger tpl_trash_on_delete before delete on public.template_programs
  for each row execute function public.tpl_trash_on_delete();

-- 2) Επαναφορά: ξαναμπαίνει στη βιβλιοθήκη κρυφό από τους πελάτες (is_published=false)
create or replace function public.restore_template_program(trash_id bigint) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  r   public.template_programs_trash%rowtype;
  j   jsonb;
  new_id uuid;
begin
  if not public.tpl_trash_is_staff() then raise exception 'Δεν επιτρέπεται.'; end if;
  select * into r from public.template_programs_trash where id = trash_id;
  if not found then raise exception 'Δεν βρέθηκε στον κάδο.'; end if;
  j := r.row || jsonb_build_object('is_published', false, 'updated_at', now(), 'updated_by', auth.uid());
  if exists (select 1 from public.template_programs t where t.id = r.template_id) then
    j := j || jsonb_build_object('id', gen_random_uuid());   -- το παλιό id χρησιμοποιείται ήδη
  end if;
  insert into public.template_programs select * from jsonb_populate_record(null::public.template_programs, j) returning id into new_id;
  delete from public.template_programs_trash where id = trash_id;
  return new_id;
end $$;
revoke all on function public.restore_template_program(bigint) from public;
grant execute on function public.restore_template_program(bigint) to authenticated;
