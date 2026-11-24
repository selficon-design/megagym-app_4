select 'L' k, t.name, string_agg(d.ord || ':' || (select count(*) from jsonb_array_elements(d.d->'items') i where i->>'groupLabel' ilike 'LEGS%' or i->>'groupLabel' ilike 'CALVES%'), ' ' order by d.ord) legs_per_day
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d,ord)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.name in ('PRO 3','PRO 4','PRO 5','PRO 6')
group by 1,2, t.sort_order order by t.sort_order;
