-- Εξοπλισμός PRO πριν την αντιγραφή (αντίγραφο ασφαλείας) σε κοιλιακούς/πόδια — όχι προσωπικά δεδομένα
select t.gender, left(coalesce(t.sub_category,''),10) sub, t.name, dn as dday, io as pos, i->>'exercise' ex,
  jsonb_array_length(coalesce(i->'equipment','[]')) n_eq,
  (select string_agg(e->>'name', ' | ') from jsonb_array_elements(coalesce(i->'equipment','[]')) e) eq
from public.template_programs_backup b join public.template_programs t on t.id=b.template_id
cross join lateral jsonb_array_elements(b.data->'days') with ordinality y(d,dn)
cross join lateral jsonb_array_elements(d->'items') with ordinality x(i,io)
where t.gender='ΑΝΔΡΕΣ' and t.name in ('PRO 2','PRO 3') and (i->>'exercise' ilike '%κοιλιακ%' or i->>'exercise' ilike '%leg press%' or i->>'exercise' ilike '%squat%')
order by 3,4,5
