select 'W' k, t.gender, left(t.sub_category,26) sub, count(*) n,
  sum(case when t.is_published then 1 else 0 end) visible,
  sum(case when t.photo_url is null then 1 else 0 end) no_photo,
  sum(case when md5((t.data - 'next' - 'topCategoryPhoto')::text) = (select md5((f.data - 'next' - 'topCategoryPhoto')::text) from public.template_programs f where f.gender='ΑΝΔΡΕΣ' and f.sub_category='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ' and f.top_category=t.top_category and f.name=t.name) then 1 else 0 end) same_as_men_full_now,
  to_char(max(t.updated_at) at time zone 'Europe/Athens','DD/MM HH24:MI') last_change,
  string_agg(case when not t.is_published then t.name end, ', ') hidden_names
from public.template_programs t where t.top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ'
group by 1,2,3 order by 2,3;
