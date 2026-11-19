-- Έλεγχος: πόσες θέσεις των PRO 2–6 έχουν ίδια άσκηση με το PRO 1 της κατηγορίας (όχι προσωπικά δεδομένα)
select t.gender, coalesce(t.sub_category,'') sub, t.name,
  count(*) total, count(*) filter (where i->>'exercise' = s.data->'days'->(dn::int-1)->'items'->(io::int-1)->>'exercise') same_ex,
  count(*) filter (where i->'equipment' = s.data->'days'->(dn::int-1)->'items'->(io::int-1)->'equipment') same_eq,
  min(i->>'rep') rep_min, max(i->>'rep') rep_max
from public.template_programs t
join public.template_programs s on s.name='PRO 1' and s.gender=t.gender and coalesce(s.sub_category,'')=coalesce(t.sub_category,'')
cross join lateral jsonb_array_elements(t.data->'days') with ordinality y(d,dn)
cross join lateral jsonb_array_elements(d->'items') with ordinality x(i,io)
where t.name ~ '^PRO [1-6]$' group by 1,2,3 order by 1,2,3
