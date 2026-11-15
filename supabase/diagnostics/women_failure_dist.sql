-- UNTIL FAILURE στα έτοιμα προγράμματα ανά φύλο (όχι προσωπικά δεδομένα)
select t.gender, coalesce(t.sub_category,'') as sub, i.it->>'failure' as failure, count(*) as items
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') d(day)
cross join lateral jsonb_array_elements(d.day->'items') i(it)
where coalesce(i.it->>'type','muscle') <> 'cardio'
group by 1,2,3 order by 1,2,3
