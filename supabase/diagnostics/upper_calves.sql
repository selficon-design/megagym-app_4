-- 1) Ασκήσεις/εξοπλισμός του καταλόγου που ταιριάζουν
select 'CAT' k, g.key as grp, e->>'exercise' as exercise, null::text eq
from public.exercise_catalog_versions v, jsonb_each(v.data->'EXERCISES') g, jsonb_array_elements(g.value) e
where v.is_active and (e->>'exercise' ilike '%ανασηκ%' or e->>'exercise' ilike '%κωπηλατ%' or e->>'exercise' ilike '%βυθίσ%' or e->>'exercise' ilike '%ανάποδη%')
union all
select 'EQ', k.key, k.key, e->>'name'
from public.exercise_catalog_versions v, jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k, jsonb_array_elements(k.value) e
where v.is_active and (k.key ilike '%ανασηκ%' or k.key ilike '%κωπηλατ%' or k.key ilike '%βυθίσ%' or k.key ilike '%ανάποδη%')
order by 1,2,3,4;
-- 2) Μέρες με γάμπες στα ανδρικά «έμφαση πάνω»
select 'DAYS' k, t.sort_order, t.name, string_agg((d.ord)::text || ':' || coalesce(d.d->>'label',''), ', ' order by d.ord) days_with_calves, count(*) n
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d, ord)
where t.gender='ΑΝΔΡΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ%'
  and exists (select 1 from jsonb_array_elements(d.d->'items') i where i->>'groupLabel' ilike '%ΓΑΜΠ%')
group by 1,2,3 order by 2;
-- 3) Πώς είναι οι γάμπες (πρώτο πρόγραμμα) — ρυθμίσεις
select 'CALF' k, t.name, d.ord, i->>'exercise', i->>'groupLabel', i->>'set', i->>'rep', i->>'rest', i->>'tempo', i->>'failure', (select count(*) from jsonb_array_elements(d.d->'items') x where x->>'groupLabel' ilike '%ΓΑΜΠ%') per_day
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d, ord), jsonb_array_elements(d.d->'items') i
where t.gender='ΑΝΔΡΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ%' and i->>'groupLabel' ilike '%ΓΑΜΠ%' and t.sort_order in (1,15,21)
order by t.sort_order, d.ord;
-- 4) Τα group labels που χρησιμοποιούνται
select 'GL' k, i->>'groupLabel' g, count(*) from public.template_programs t, jsonb_array_elements(t.data->'days') d, jsonb_array_elements(d->'items') i
where t.gender='ΑΝΔΡΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ%' group by 1,2 order by 3 desc;
