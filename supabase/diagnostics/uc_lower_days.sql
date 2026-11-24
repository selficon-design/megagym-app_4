select 'LD' k, t.sort_order, t.name,
  string_agg(d.ord::text || case when exists (select 1 from jsonb_array_elements(d.d->'items') x where x->>'groupLabel' ilike '%ΓΑΜΠ%') then 'Γ' else '' end
    || case when exists (select 1 from jsonb_array_elements(d.d->'items') x where x->>'exercise' ilike '%πρέσα%' or x->>'exercise' ilike '%leg press%') then 'Π' else '' end, ' ' order by d.ord) days
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d, ord)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.sort_order <= 8
group by 1,2,3 order by 2;
