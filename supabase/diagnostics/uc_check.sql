select 'R' k, left(t.sub_category,10) sub, t.sort_order, t.name,
  string_agg(g.ord || ':' || coalesce((select string_agg(case when i->>'groupLabel' ilike '%ΓΑΜΠ%' then 'Γ' when i->>'exercise' like 'Ανασηκώσεις Ώμων%' then 'ΩΜ' when i->>'exercise' like 'Σκυφτή κωπηλατική στον επικλινή με κανονική%' then 'ΠΛ' when i->>'exercise' like 'Βυθίσεις στήθους%' then 'ΣΤ' when i->>'exercise' like 'Κάμψεις δικεφάλων ανάποδη%' then 'ΔΚ' end, '+') from jsonb_array_elements(g.d->'items') i), '·') || '/' || jsonb_array_length(g.d->'items'), ' ' order by g.ord) days
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality g(d,ord)
where t.gender='ΑΝΔΡΕΣ' and t.top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and (t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ%' or t.sort_order in (1,15,21))
group by 1,2,3,4 order by 2,3;
