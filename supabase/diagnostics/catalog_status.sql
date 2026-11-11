-- Κατάλογος ασκήσεων: εκδόσεις από το «Ανέβασμα Excel» (χωρίς προσωπικά δεδομένα)
select id, is_active, file_name, created_at, activated_at, summary,
       jsonb_array_length(coalesce(data->'GYMS','[]'::jsonb)) as gyms,
       (select count(*) from jsonb_object_keys(data->'EXERCISES')) as groups
from public.exercise_catalog_versions order by id desc limit 20
