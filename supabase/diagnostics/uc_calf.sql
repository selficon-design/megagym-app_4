-- 3) Πώς είναι οι γάμπες (πρώτο πρόγραμμα) — ρυθμίσεις
select 'CALF' k, t.name, d.ord, i->>'exercise', i->>'groupLabel', i->>'set', i->>'rep', i->>'rest', i->>'tempo', i->>'failure', (select count(*) from jsonb_array_elements(d.d->'items') x where x->>'groupLabel' ilike '%ΓΑΜΠ%') per_day
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d, ord), jsonb_array_elements(d.d->'items') i
where t.gender='ΑΝΔΡΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ%' and i->>'groupLabel' ilike '%ΓΑΜΠ%' and t.sort_order in (1,15,21)
order by t.sort_order, d.ord;
