select 'PM' k, left(t.sub_category,22) sub, t.name,
  string_agg(d.ord::text || case when exists (select 1 from jsonb_array_elements(d.d->'items') x where x->>'groupLabel' ilike '%ΓΑΜΠ%') then '(Γ' || (select count(*) from jsonb_array_elements(d.d->'items') x where x->>'groupLabel' ilike '%ΓΑΜΠ%') || ')' else '' end || '/' || jsonb_array_length(d.d->'items'), ' ' order by d.ord) days,
  max(t.updated_at) upd
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d, ord)
where t.gender='ΑΝΔΡΕΣ' and t.sort_order >= 21
group by 1,2,3, t.sort_order order by 2, t.sort_order;
