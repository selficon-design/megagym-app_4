-- Άνδρες ανά κατηγορία (όχι προσωπικά δεδομένα)
select coalesce(sub_category,'') sub, is_published, count(*) n, string_agg(name||'('||sort_order||')', ', ' order by sort_order) names
from public.template_programs where gender='ΑΝΔΡΕΣ' group by 1,2 order by 1,2
