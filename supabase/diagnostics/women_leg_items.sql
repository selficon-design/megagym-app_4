-- Έτοιμα προγράμματα γυναικών «Γυμνάζει όλο το σώμα» (όχι προσωπικά δεδομένα):
-- οι ασκήσεις ποδιών/γαμπών ανά ημέρα, για να φτιαχτεί η κατηγορία «έμφαση στο κάτω μέρος».
select t.sort_order as so, t.name, d.ord as day_no, i.ord as item_no,
       i.it->>'groupLabel' as grp, i.it->>'exercise' as exercise,
       i.it->>'set' as sets, i.it->>'rep' as rep, i.it->>'rest' as rest, i.it->>'tempo' as tempo, i.it->>'failure' as fail,
       jsonb_array_length(coalesce(i.it->'equipment','[]'::jsonb)) as n_eq
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') with ordinality as d(day, ord)
cross join lateral jsonb_array_elements(d.day->'items') with ordinality as i(it, ord)
where t.gender = 'ΓΥΝΑΙΚΕΣ' and t.sub_category = 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ' and t.is_published
  and (i.it->>'groupLabel' ilike any (array['%ΠΟΔ%','%ΓΑΜΠ%','%ΓΛΟΥΤ%','%LEG%','%CALF%','%CALVES%','%ΜΗΡ%']))
order by t.sort_order, t.name, d.ord, i.ord
