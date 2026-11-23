select 'S' k, i::text from public.template_programs t, jsonb_array_elements(t.data->'days') d, jsonb_array_elements(d->'items') i
where t.gender='ΑΝΔΡΕΣ' and t.sub_category='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ' and t.name in ('PRO 1') and (i->>'groupLabel' ilike '%ΓΑΜΠ%' or i->>'groupLabel' ilike '%ΩΜΟΙ%')
limit 3;
