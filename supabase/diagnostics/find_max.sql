-- Αναζήτηση προγράμματος «MAX» σε έτοιμα και κάδο + πρόσφατα (όχι προσωπικά δεδομένα)
select 'templates' src, id::text, name, gender, coalesce(sub_category,'') sub, is_published::text pub, created_at::text c, updated_at::text u,
  jsonb_array_length(coalesce(data->'days','[]')) days from public.template_programs where name ilike '%max%'
union all
select 'trash', template_id::text, name, coalesce(row->>'gender',''), coalesce(row->>'sub_category',''), '', deleted_at::text, '', jsonb_array_length(coalesce(row->'data'->'days','[]'))
from public.template_programs_trash where deleted_at > now() - interval '2 days' or name ilike '%max%'
union all
select 'recent', id::text, name, gender, coalesce(sub_category,''), is_published::text, created_at::text, updated_at::text, jsonb_array_length(coalesce(data->'days','[]'))
from public.template_programs where created_at > now() - interval '8 hours' or updated_at > now() - interval '2 hours'
