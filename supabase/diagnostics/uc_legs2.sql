select 'L' k, t.name, string_agg(d.ord || ':' || (select count(*) from jsonb_array_elements(d.d->'items') i where i->>'groupLabel' ilike 'LEGS%' or i->>'groupLabel' ilike 'CALVES%') || '/' || jsonb_array_length(d.d->'items'), ' ' order by d.ord) legs_per_day
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d,ord)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.name in ('PRO 6','PRO MAX 1','PRO MAX 2','PRO MAX 3')
group by 1,2, t.sort_order order by t.sort_order;
