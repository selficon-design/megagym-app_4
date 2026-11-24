select 'L' k, d.ord, string_agg(t.name || '=' || coalesce(i->>'exercise','') || ' [' || concat_ws('/', i->>'set', i->>'rep', i->>'rest') || '] ' || coalesce((select string_agg(e->>'name','|') from jsonb_array_elements(i->'equipment') e),''), ' ## ' order by t.sort_order) x
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d,ord), jsonb_array_elements(d.d->'items') i
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.name ~ '^PRO [1-6]$' and d.ord = 11 and (i->>'groupLabel' ilike 'LEGS%' or i->>'groupLabel' ilike 'CALVES%')
group by 1,2 order by 2;
