select 'G' k, jsonb_typeof(v.data->'EXERCISES') t, left((v.data->'EXERCISES')::text, 300) s, left((v.data->'groupLabels')::text, 400) gl
from public.exercise_catalog_versions v where v.is_active;
