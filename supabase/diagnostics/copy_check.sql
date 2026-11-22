select gender, left(sub_category,24) sub, count(*) n, sum(case when is_published then 1 else 0 end) visible,
  sum(case when photo_url is null then 1 else 0 end) no_photo,
  sum(case when data->>'next' ~ '^[0-9a-f-]{36}$' and not exists (select 1 from public.template_programs n where n.id::text=t.data->>'next' and n.gender=t.gender and n.sub_category=t.sub_category) then 1 else 0 end) bad_next,
  sum(case when md5((t.data - 'next' - 'topCategoryPhoto')::text) = (select md5((f.data - 'next' - 'topCategoryPhoto')::text) from public.template_programs f where f.gender='ΑΝΔΡΕΣ' and f.sub_category='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ' and f.top_category=t.top_category and f.name=t.name) then 1 else 0 end) same_as_men_full,
  string_agg(case when photo_url is null then name end, ', ') missing_photo_names
from public.template_programs t where top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' group by 1,2 order by 1,2;
