-- Κλειδιά στοιχείων ημερών στα έτοιμα PRO (όχι προσωπικά δεδομένα)
select i->>'type' as type, k, count(*) n, min(left(i->>k, 60)) example
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') d
cross join lateral jsonb_array_elements(d->'items') i
cross join lateral jsonb_object_keys(i) k
where t.name ~ '^PRO [1-6]$'
group by 1,2 order by 1,2
