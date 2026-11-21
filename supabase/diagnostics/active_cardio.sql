-- ACTIVE γυναικών «κάτω»: θέση και στοιχεία αερόβιων ανά ημέρα (όχι προσωπικά δεδομένα)
select t.name, t.updated_at, dn as dday, jsonb_array_length(d->'items') n_items,
  (select string_agg(io||':'||coalesce(i->>'equipment','')||' '||coalesce(i->>'mode','')||' '||coalesce(i->>'minutes','')||'λ '||coalesce(i->>'speedLow','')||'-'||coalesce(i->>'speedLowMax',''), ' | ' order by io)
     from jsonb_array_elements(d->'items') with ordinality x(i,io) where i->>'type'='cardio') cardio
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') with ordinality y(d,dn)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category=coalesce(nullif('ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ',''),'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ') and t.name ~ '^ACTIVE [1-5]$'
order by t.name, dn
