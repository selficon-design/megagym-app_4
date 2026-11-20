-- PRO MAX 1: οι ασκήσεις των ημερών 1–6 αντιγράφονται ακριβώς στις ημέρες 7–12 (μόνο αν αυτές είναι άδειες).
-- Τα ονόματα των ημερών 7–12 μένουν ίδια. Κρατιέται αντίγραφο ασφαλείας.
insert into public.template_programs_backup (template_id, reason, data)
select id, 'promax1_copy_days_1_6_to_7_12', data from public.template_programs
where id = 'bd4ed0e6-bf27-41a5-b5fd-2e13e73ab806';

update public.template_programs t
set data = jsonb_set(t.data, '{days}', (
  select jsonb_agg(
    case when n between 7 and 12
         then jsonb_set(d, '{items}', coalesce(t.data->'days'->(n::int-7)->'items', '[]'::jsonb))
         else d end order by n)
  from jsonb_array_elements(t.data->'days') with ordinality x(d, n)))
where t.id = 'bd4ed0e6-bf27-41a5-b5fd-2e13e73ab806'
  and jsonb_array_length(t.data->'days') = 12
  and not exists (select 1 from jsonb_array_elements(t.data->'days') with ordinality y(d, n)
                  where n between 7 and 12 and jsonb_array_length(coalesce(d->'items','[]'::jsonb)) > 0);
