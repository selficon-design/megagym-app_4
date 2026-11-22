select t.gender, left(t.sub_category,20) sub, t.name, coalesce(i->>'failure','(κενό)') failure, coalesce(i->>'failureSets','') fs, count(*) n
from public.template_programs t, jsonb_array_elements(t.data->'days') d, jsonb_array_elements(d->'items') i
where coalesce(i->>'type','')<>'cardio' and t.top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and t.gender='ΑΝΔΡΕΣ' and t.sub_category='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ'
group by 1,2,3,4,5 order by 1,2,min(t.sort_order),4;
