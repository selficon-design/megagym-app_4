-- Εξοπλισμός PRO 1 σε κοιλιακούς / πόδια (όχι προσωπικά δεδομένα)
select t.gender, left(coalesce(t.sub_category,''),12) sub, t.updated_at, dn as dday, io as pos, i->>'exercise' ex,
  jsonb_array_length(coalesce(i->'equipment','[]')) n_eq,
  (select string_agg(e->>'name', ' | ') from jsonb_array_elements(coalesce(i->'equipment','[]')) e) eq
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') with ordinality y(d,dn)
cross join lateral jsonb_array_elements(d->'items') with ordinality x(i,io)
where t.name='PRO 1' and t.gender='ΑΝΔΡΕΣ' and (i->>'groupLabel' ilike '%ΚΟΙΛ%' or i->>'groupLabel' ilike '%LEG%' or i->>'groupLabel' ilike '%ΠΟΔ%')
order by 1,2,4,5
