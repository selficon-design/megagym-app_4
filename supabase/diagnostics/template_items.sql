-- Έτοιμα προγράμματα (όχι προσωπικά δεδομένα): ασκήσεις του πιο πρόσφατα αλλαγμένου προγράμματος για υπολογισμό διάρκειας
with p as (
  select id, name, gender, top_category, sub_category from public.template_programs
  order by coalesce(updated_at, created_at) desc limit 1
)
select p.name, p.top_category, p.sub_category, d.ord as day_no, d.day->>'label' as day_label, i.ord as item_no,
       i.it->>'type' as type, i.it->>'exercise' as exercise, i.it->>'equipment' as cardio_equipment,
       i.it->>'set' as sets, i.it->>'rep' as rep, i.it->>'rest' as rest, i.it->>'tempo' as tempo, i.it->>'minutes' as minutes
from p join public.template_programs t on t.id = p.id
cross join lateral jsonb_array_elements(t.data->'days') with ordinality as d(day, ord)
cross join lateral jsonb_array_elements(d.day->'items') with ordinality as i(it, ord)
order by d.ord, i.ord
