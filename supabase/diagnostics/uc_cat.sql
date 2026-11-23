-- 1) Ασκήσεις/εξοπλισμός του καταλόγου που ταιριάζουν
select 'CAT' k, g.key as grp, e->>'exercise' as exercise, null::text eq
from public.exercise_catalog_versions v, jsonb_each(v.data->'EXERCISES') g, jsonb_array_elements(g.value) e
where v.is_active and (e->>'exercise' ilike '%ανασηκ%' or e->>'exercise' ilike '%κωπηλατ%' or e->>'exercise' ilike '%βυθίσ%' or e->>'exercise' ilike '%ανάποδη%')
union all
select 'EQ', k.key, k.key, e->>'name'
from public.exercise_catalog_versions v, jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k, jsonb_array_elements(k.value) e
where v.is_active and (k.key ilike '%ανασηκ%' or k.key ilike '%κωπηλατ%' or k.key ilike '%βυθίσ%' or k.key ilike '%ανάποδη%')
order by 1,2,3,4;
