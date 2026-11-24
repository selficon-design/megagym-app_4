select 'P' k, t.name || ' / ημ.' || d.ord, coalesce(i->>'exercise','(αερόβιο)') || ' :: ' || coalesce((select string_agg(e->>'name',' | ') from jsonb_array_elements(i->'equipment') e),'')
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d,ord), jsonb_array_elements(d.d->'items') i
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.name in ('POWER 1','POWER 2','POWER 3','PRO 1','PRO 2','PRO 3') and d.ord <= 6
  and (i->>'groupLabel' ilike '%ΓΑΜΠ%' or i->>'exercise' ilike '%leg press%' or i->>'exercise' ilike '%hip thrust%' or i->>'exercise' ilike '%αγωγ%')
order by t.sort_order, d.ord;
