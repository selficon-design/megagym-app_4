select 'Q' k, t.name, d.ord, string_agg(coalesce(i->>'exercise','(αερόβιο '||coalesce(i->>'equipment','')||')') || ' [' || concat_ws('/', i->>'set', i->>'rep', i->>'rest', i->>'failure') || ']', ' · ' order by io) items
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d,ord), jsonb_array_elements(d.d->'items') with ordinality x(i, io)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.name in ('PRO 1','PRO 2','PRO 3') and d.ord between 7 and 12
group by 1,2,3, t.sort_order order by d.ord, t.sort_order;
