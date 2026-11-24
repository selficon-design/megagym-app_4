select 'D' k, left(t.sub_category,22) sub, t.name, to_char(t.updated_at at time zone 'Europe/Athens','DD/MM HH24:MI') upd,
  (select string_agg(x.ord::text, ',') from jsonb_array_elements(t.data->'days') with ordinality x(d,ord)
     where x.d is distinct from (f.data->'days'->(x.ord::int-1))) diff_days,
  jsonb_array_length(t.data->'days') wd, jsonb_array_length(f.data->'days') md,
  to_char(f.updated_at at time zone 'Europe/Athens','DD/MM HH24:MI') men_upd
from public.template_programs t join public.template_programs f
  on f.gender='ΑΝΔΡΕΣ' and f.sub_category='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ' and f.top_category=t.top_category and f.name=t.name
where t.gender='ΓΥΝΑΙΚΕΣ' and t.top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and t.sub_category in ('ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ','ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ')
  and md5((t.data - 'next' - 'topCategoryPhoto')::text) <> md5((f.data - 'next' - 'topCategoryPhoto')::text)
order by 2, t.sort_order;
