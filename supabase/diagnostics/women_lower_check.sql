-- Έλεγχος κατηγορίας γυναικών «Με έμφαση στο κάτω μέρος» (όχι προσωπικά δεδομένα)
select t.name, count(*) filter (where i.it->>'groupLabel' ilike '%ΓΑΜΠ%') as calves_left,
       count(*) filter (where i.it->>'groupLabel' ilike '%ΠΟΔΙΑ%') as leg_items,
       min(jsonb_array_length(coalesce(i.it->'equipment','[]'::jsonb))) filter (where i.it->>'groupLabel' ilike '%ΠΟΔΙΑ%') as min_leg_eq,
       string_agg(distinct i.it->>'exercise', ' / ') filter (where i.it->>'groupLabel' ilike '%ΠΟΔΙΑ%') as leg_exercises
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') d(day)
cross join lateral jsonb_array_elements(d.day->'items') i(it)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ'
group by t.name, t.sort_order order by t.sort_order, t.name
