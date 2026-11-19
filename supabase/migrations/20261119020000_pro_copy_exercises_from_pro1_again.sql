-- PRO 2–6: ασκήσεις, μυϊκή ομάδα και εξοπλισμός από το PRO 1 της ίδιας κατηγορίας (ίδια ημέρα, ίδια θέση).
-- SET / REP / ΔΙΑΛΕΙΜΜΑ / TEMPO / UNTIL FAILURE μένουν όπως είναι. Πριν την αλλαγή κρατιέται αντίγραφο.
create table if not exists public.template_programs_backup (
  id bigserial primary key,
  template_id uuid not null,
  reason text not null,
  data jsonb,
  backed_up_at timestamptz not null default now()
);
alter table public.template_programs_backup enable row level security;

insert into public.template_programs_backup (template_id, reason, data)
select t.id, 'pro_copy_exercises_from_pro1_v2', t.data
from public.template_programs t
where t.name ~ '^PRO [2-6]$'
  and not exists (select 1 from public.template_programs_backup b where b.template_id = t.id and b.reason = 'pro_copy_exercises_from_pro1_v2');

update public.template_programs t
set data = jsonb_set(t.data, '{days}', (
  select jsonb_agg(
    case when jsonb_typeof(d->'items')='array' then jsonb_set(d, '{items}', (
      select jsonb_agg(
        case when si is not null and coalesce(i->>'type','muscle')='muscle' and coalesce(si->>'type','muscle')='muscle'
             then i || jsonb_build_object('groupLabel', si->'groupLabel', 'exercise', si->'exercise', 'equipment', coalesce(si->'equipment','[]'::jsonb))
             else i end order by io)
      from jsonb_array_elements(d->'items') with ordinality x(i, io)
      left join lateral (select s.data->'days'->(dno::int-1)->'items'->(io::int-1) as si) z on true))
    else d end order by dno)
  from jsonb_array_elements(t.data->'days') with ordinality y(d, dno)))
from public.template_programs s
where t.name ~ '^PRO [2-6]$' and s.name = 'PRO 1'
  and s.gender = t.gender and coalesce(s.top_category,'') = coalesce(t.top_category,'') and coalesce(s.sub_category,'') = coalesce(t.sub_category,'')
  and jsonb_typeof(t.data->'days')='array' and jsonb_array_length(t.data->'days') > 0;
