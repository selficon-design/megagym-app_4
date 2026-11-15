-- Δομή γυναικείων «Γυμνάζει όλο το σώμα» (όχι προσωπικά δεδομένα): ημέρες και ομάδες ανά ημέρα
select t.sort_order as so, t.name, jsonb_array_length(t.data->'days') as n_days, d.ord as day_no,
       string_agg(coalesce(case when i.it->>'type'='cardio' then 'CARDIO' end, split_part(i.it->>'groupLabel',' - ',1)), ' | ' order by i.ord) as groups
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') with ordinality d(day, ord)
cross join lateral jsonb_array_elements(d.day->'items') with ordinality i(it, ord)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ' and t.is_published and d.ord <= 4
group by 1,2,3,4 order by 1,2,4
