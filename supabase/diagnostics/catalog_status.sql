-- Κατάλογος ασκήσεων: εκδόσεις από το «Ανέβασμα Excel» (χωρίς προσωπικά δεδομένα)
select id, is_active, file_name, created_at, summary,
       data->'groupLabels' as group_labels,
       (select count(*) from jsonb_object_keys(data->'EXERCISES')) as groups
from public.exercise_catalog_versions order by id desc limit 20
