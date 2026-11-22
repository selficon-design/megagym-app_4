select gender, left(sub_category,16) sub, name,
  substring(coalesce(description,'') from '(?i).{0,60}failure.{0,60}') d,
  substring(coalesce(results,'') from '(?i).{0,60}failure.{0,60}') r,
  substring(coalesce(notes,'') from '(?i).{0,60}failure.{0,60}') n,
  substring(coalesce(nutrition,'') from '(?i).{0,60}failure.{0,60}') nu
from public.template_programs where top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and (description ilike '%failure%' or results ilike '%failure%' or notes ilike '%failure%' or nutrition ilike '%failure%')
order by gender, sub_category, sort_order;
