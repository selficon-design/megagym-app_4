select 'EQ' k, k.key as exercise, e->>'name' as equipment, null::text a, null::text b
from public.exercise_catalog_versions v, jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k, jsonb_array_elements(k.value) e
where v.is_active and (k.key ilike '%αγωγ%' or k.key ilike '%abduct%' or k.key ilike '%adduct%')
union all
select 'D6', t.name, i->>'exercise', i->>'groupLabel', concat_ws(' / ', i->>'set', i->>'rep', i->>'rest', i->>'tempo', i->>'failure')
from public.template_programs t, jsonb_array_elements(t.data->'days'->5->'items') i
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.name in ('ACTIVE 1','ACTIVE 2','ACTIVE 3')
order by 1,2;
