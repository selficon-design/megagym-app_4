-- PRO MAX: δομή (όχι προσωπικά δεδομένα)
select id, gender, left(coalesce(sub_category,''),14) sub, name, sort_order, updated_at, num_days,
  jsonb_array_length(coalesce(data->'days','[]')) days,
  (select string_agg(coalesce(d->>'label','?')||':'||jsonb_array_length(coalesce(d->'items','[]')), ' ' order by n) from jsonb_array_elements(data->'days') with ordinality x(d,n)) per_day,
  data->'dayDefaults' defaults
from public.template_programs where name ilike '%max%'
