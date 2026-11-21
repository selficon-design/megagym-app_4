-- Leg curl: ασκήσεις/εξοπλισμός στον ενεργό κατάλογο και στα έτοιμα προγράμματα (όχι προσωπικά δεδομένα)
select 'catalog' src, k.key ex, (select string_agg(e->>'name', ' || ') from jsonb_array_elements(k.value) e) eq, null::text prog
from public.exercise_catalog_versions v cross join lateral jsonb_each(v.data->'EQUIPMENT_BY_EXERCISE') k
where v.is_active and (k.key ilike '%curl%' or k.key ilike '%κάμψ%')
union all
select 'tpl', i->>'exercise', (select string_agg(coalesce(e->>'name', e#>>'{}'), ' || ') from jsonb_array_elements(coalesce(i->'equipment','[]')) e),
  t.gender||' / '||left(coalesce(t.sub_category,''),12)||' / '||t.name||' / d'||dn
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') with ordinality y(d,dn)
cross join lateral jsonb_array_elements(d->'items') i
where i->>'exercise' ilike '%curl%' or (i->'equipment')::text ilike '%curl%'
order by 1, 2, 4
