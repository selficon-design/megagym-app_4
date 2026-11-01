-- Κατηγορίες βιβλιοθήκης & bucket φωτογραφιών (ΧΩΡΙΣ στοιχεία πελατών).
select 'cat' as k, gender || ' / ' || top_category || coalesce(' › ' || nullif(sub_category, ''), '') as a,
       (photo_url is not null)::text as has_photo, (description is not null)::text as has_desc
from public.library_categories
union all
select 'bucket', id, public::text, coalesce(file_size_limit::text, '') from storage.buckets
