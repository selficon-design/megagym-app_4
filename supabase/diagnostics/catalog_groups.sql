-- Ενεργός κατάλογος ασκήσεων: ομάδες και ασκήσεις (όχι προσωπικά δεδομένα)
select g.key as grp_key, (v.data->'groupLabels'->>g.key) as grp_label, e.ord, e.ex #>> '{}' as exercise
from public.exercise_catalog_versions v
cross join lateral jsonb_each(v.data->'EXERCISES') as g(key, list)
cross join lateral jsonb_array_elements(g.list) with ordinality as e(ex, ord)
where v.is_active
order by g.key, e.ord
