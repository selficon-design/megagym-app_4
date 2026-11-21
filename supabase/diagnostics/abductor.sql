-- Απαγωγοί/προσαγωγοί: κατάλογος και έτοιμα προγράμματα (όχι προσωπικά δεδομένα)
select 'catalog' src, k.key ex, (select string_agg(e->>'name', ' || ') from jsonb_array_elements(k.value) e) eq, null::text n
from public.exercise_catalog_versions v cross join lateral jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k
where v.is_active and (k.key ilike '%γωγ%' or k.key ilike '%ductor%' or k.value::text ilike '%ductor%')
union all
select 'tpl', i->>'exercise', (select string_agg(coalesce(e->>'name', e#>>'{}'), ' || ') from jsonb_array_elements(coalesce(i->'equipment','[]')) e), count(*)::text
from public.template_programs t, jsonb_array_elements(t.data->'days') d, jsonb_array_elements(d->'items') i
where i->>'exercise' ilike '%γωγ%' or (i->'equipment')::text ilike '%ductor%' or (i->'equipment')::text ilike '%γωγ%'
group by 1,2,3
order by 1,2
