-- Τιμές αερόβιων στα έτοιμα προγράμματα (όχι προσωπικά δεδομένα): ομαδοποίηση ανά τιμές
select t.gender, i.it->>'equipment' as eq, i.it->>'mode' as mode,
       coalesce(i.it->>'speedLow','') as lo, coalesce(i.it->>'speedLowMax','') as lomax,
       coalesce(i.it->>'incline','') as incl, coalesce(i.it->>'minutes','') as mins,
       coalesce(i.it->>'drillEveryMinutes','') as every, count(*) as n
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') d(day)
cross join lateral jsonb_array_elements(d.day->'items') i(it)
where i.it->>'type'='cardio'
group by 1,2,3,4,5,6,7,8 order by n desc
