-- Κατηγορίες έτοιμων προγραμμάτων (όχι προσωπικά δεδομένα)
select gender, top_category, coalesce(sub_category,'') sub, is_published, count(*) n, string_agg(name, ', ' order by sort_order) names
from public.template_programs group by 1,2,3,4 order by 1,2,3,4
