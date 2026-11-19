-- Εκδόσεις καταλόγου ασκήσεων: εξοπλισμός για κοιλιακούς / leg press (όχι προσωπικά δεδομένα)
select v.id, v.created_at, v.is_active, left(coalesce(v.file_name,''),40) file, k.key as ex,
  jsonb_array_length(k.value) n_eq,
  (select string_agg(e->>'name', ' | ') from jsonb_array_elements(k.value) e) eq
from public.exercise_catalog_versions v
cross join lateral jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k
where (k.key ilike '%κοιλιακ%' or k.key ilike '%leg press%' or k.key ilike '%squat%')
  and v.id in (select id from public.exercise_catalog_versions order by id desc limit 3)
order by v.id desc, k.key
