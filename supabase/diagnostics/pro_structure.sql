-- Δομή προγραμμάτων PRO (όχι προσωπικά δεδομένα)
select id, gender, coalesce(sub_category,'') sub, name, sort_order, is_published,
       jsonb_array_length(coalesce(data->'days','[]'::jsonb)) days,
       (select string_agg(jsonb_array_length(coalesce(d->'items','[]'::jsonb))::text, ',' order by n) from jsonb_array_elements(data->'days') with ordinality x(d,n)) items_per_day
from public.template_programs where name ilike '%pro%' order by gender, sub, sort_order
