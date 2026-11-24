select 'AC' k, t.name, d.ord, i->>'exercise' ex, (select string_agg(e->>'name',' | ') from jsonb_array_elements(i->'equipment') e) eq
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d, ord), jsonb_array_elements(d.d->'items') i
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.sort_order between 1 and 6
  and (i->>'groupLabel' ilike '%ΓΑΜΠ%' or i->>'exercise' ilike '%leg press%')
order by t.sort_order, d.ord;
