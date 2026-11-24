select 'EQ' k, k.key as a, e->>'name' as b
from public.exercise_catalog_versions v, jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k, jsonb_array_elements(k.value) e
where v.is_active and (k.key ilike '%θανάτου%' or k.key ilike '%deadlift%')
union all
select 'D8', t.name || ' / ημ.' || d.ord, coalesce(i->>'exercise','(αερόβιο)') || ' :: ' || coalesce((select string_agg(e->>'name',' | ') from jsonb_array_elements(i->'equipment') e),'')
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d,ord), jsonb_array_elements(d.d->'items') i
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.name in ('PRO 1','PRO 2','PRO 3') and d.ord <= 6 and (i->>'groupLabel' ilike '%ΓΑΜΠ%' or i->>'groupLabel' ilike 'LEGS%')
order by 1,2;
