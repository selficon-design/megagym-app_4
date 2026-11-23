select 'PM' k, t.gender, left(t.sub_category,22), t.sort_order, t.name, d.ord as day, coalesce(d.d->>'label','') label, jsonb_array_length(d.d->'items') n_items,
  (select count(*) from jsonb_array_elements(d.d->'items') x where x->>'groupLabel' ilike '%ΓΑΜΠ%') calves, t.updated_at
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d, ord)
where t.sort_order >= 21 and d.ord=5
order by t.sort_order, d.ord;
