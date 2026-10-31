-- Κατηγορίες των έτοιμων προγραμμάτων (ΧΩΡΙΣ στοιχεία πελατών).
select gender,
       '[' || top_category || ']' as top_category,
       length(top_category) as len,
       encode(convert_to(top_category, 'UTF8'), 'hex') as hex,
       coalesce(sub_category, '') as sub_category,
       count(*) as programs
from public.template_programs
group by 1, 2, 3, 4, 5
order by 1, 2, 5;
