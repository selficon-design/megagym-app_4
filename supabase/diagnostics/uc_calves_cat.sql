select 'EQ' k, k.key as exercise, e->>'name' as equipment
from public.exercise_catalog_versions v, jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k, jsonb_array_elements(k.value) e
where v.is_active and (k.key ilike '%γάμπ%' or k.key ilike '%calf%' or e->>'name' ilike '%stretch%')
order by 2,3;
