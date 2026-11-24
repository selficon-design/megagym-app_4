select 'P' k, t.name, d.ord, coalesce(i->>'exercise','(αερόβιο)') || ' :: ' || coalesce((select string_agg(e->>'name',' | ') from jsonb_array_elements(i->'equipment') e),'')
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d,ord), jsonb_array_elements(d.d->'items') i
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.name in ('ADVANCED 1','ADVANCED 2','ADVANCED 3') and d.ord <= 6
  and (i->>'groupLabel' ilike '%ΓΑΜΠ%' or i->>'exercise' ilike '%leg press%' or i->>'exercise' ilike '%hip thrust%' or i->>'exercise' ilike '%αγωγ%' or i->>'exercise' ilike '%θανάτου%')
order by t.sort_order, d.ord;
