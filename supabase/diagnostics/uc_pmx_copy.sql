select t.name, d.ord,
  (select string_agg(coalesce(i->>'exercise','') || '|' || coalesce((select string_agg(q->>'name',',') from jsonb_array_elements(coalesce(i->'equipment','[]'::jsonb)) q),''), ' # ' order by o) from jsonb_array_elements(d.d->'items') with ordinality z(i,o))
    = (select string_agg(coalesce(i->>'exercise','') || '|' || coalesce((select string_agg(q->>'name',',') from jsonb_array_elements(coalesce(i->'equipment','[]'::jsonb)) q),''), ' # ' order by o) from jsonb_array_elements(s.data->'days'->(d.ord::int-1)->'items') with ordinality z(i,o)) same_as_pmx1,
  (select string_agg(coalesce(i->>'set','') || 'x' || coalesce(i->>'rep',''), ' ' order by o) from jsonb_array_elements(d.d->'items') with ordinality z(i,o)) sets_reps
from public.template_programs t
join public.template_programs s on s.gender=t.gender and s.sub_category=t.sub_category and s.name='PRO MAX 1'
, jsonb_array_elements(t.data->'days') with ordinality d(d,ord)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and t.name in ('PRO MAX 1','PRO MAX 2','PRO MAX 3')
order by t.name, d.ord
