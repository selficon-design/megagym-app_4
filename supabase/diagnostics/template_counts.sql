-- Έτοιμα προγράμματα ανά φύλο/κατηγορία (όχι προσωπικά δεδομένα)
select gender, top_category, coalesce(sub_category,'') as sub_category, count(*) as programs,
       count(*) filter (where is_published) as published, string_agg(name, ' | ' order by sort_order) as names
from public.template_programs group by 1,2,3 order by 1,2,3
