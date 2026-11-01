-- Στήλες του πίνακα template_programs και φωτογραφίες κατηγοριών (ΧΩΡΙΣ στοιχεία πελατών).
select 'col' as k, column_name as a, data_type as b, '' as c
from information_schema.columns where table_schema = 'public' and table_name = 'template_programs'
union all
select 'photo', gender || ' / ' || top_category, coalesce(sub_category, ''), left(coalesce(top_category_photo_url, ''), 120)
from public.template_programs where top_category_photo_url is not null and top_category_photo_url <> ''
union all
select 'bucket', id, public::text, '' from storage.buckets
