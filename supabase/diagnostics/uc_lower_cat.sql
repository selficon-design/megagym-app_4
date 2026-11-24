select 'EQ' k, k.key as exercise, e->>'name' as equipment, e->>'hands' h
from public.exercise_catalog_versions v, jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k, jsonb_array_elements(k.value) e
where v.is_active and (k.key ilike '%πρέσα%' or k.key ilike '%leg press%' or k.key ilike '%hip thrust%' or k.key ilike '%γλουτ%' or e->>'name' ilike '%linear%' or e->>'name' ilike '%hip thrust%')
order by 2,3;
