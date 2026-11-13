-- Έτοιμα προγράμματα: σειρά εμφάνισης (όχι προσωπικά δεδομένα)
select gender, top_category, coalesce(sub_category,'') as sub_category, sort_order, name, is_published,
       created_at, updated_at, data->>'next' as next, data->>'sessions' as sessions
from public.template_programs order by gender, top_category, sub_category, sort_order, created_at
