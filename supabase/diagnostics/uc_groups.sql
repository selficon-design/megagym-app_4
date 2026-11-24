select 'G' k, 'keys' a, string_agg(key, ',') b from public.exercise_catalog_versions v, jsonb_object_keys(v.data) key where v.is_active
union all
select 'G', 'legpress_label', string_agg(distinct i->>'groupLabel', ' | ') from public.template_programs t, jsonb_array_elements(t.data->'days') d, jsonb_array_elements(d->'items') i where i->>'exercise' ilike '%leg press%' or i->>'exercise' ilike '%hip thrust%'
union all
select 'G', 'calf_label', string_agg(distinct i->>'groupLabel', ' | ') from public.template_programs t, jsonb_array_elements(t.data->'days') d, jsonb_array_elements(d->'items') i where i->>'groupLabel' ilike '%ΓΑΜΠ%';
