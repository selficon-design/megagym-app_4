-- 2) Μέρες με γάμπες στα ανδρικά «έμφαση πάνω»
select 'DAYS' k, t.sort_order, t.name, string_agg((d.ord)::text || ':' || coalesce(d.d->>'label',''), ', ' order by d.ord) days_with_calves, count(*) n
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d, ord)
where t.gender='ΑΝΔΡΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ%'
  and exists (select 1 from jsonb_array_elements(d.d->'items') i where i->>'groupLabel' ilike '%ΓΑΜΠ%')
group by 1,2,3 order by 2;
