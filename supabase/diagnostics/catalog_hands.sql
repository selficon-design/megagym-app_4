select coalesce(e->>'hands','(κενό)') hands, count(*) n
from public.exercise_catalog_versions v
cross join lateral jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k
cross join lateral jsonb_array_elements(k.value) e
where v.is_active
group by 1 order by 1
