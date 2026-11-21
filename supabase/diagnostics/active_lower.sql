-- ACTIVE γυναικών «με έμφαση στο κάτω»: ημέρες και SET/REP ανά ημέρα 1–6 (όχι προσωπικά δεδομένα)
select t.name, t.updated_at, jsonb_array_length(t.data->'days') days, dn as dday,
  (select string_agg(coalesce(i->>'exercise','?')||' ['||coalesce(i->>'set','')||'x'||coalesce(i->>'rep','')||' f'||coalesce(i->>'failure','')||coalesce(' '||(i->>'failureSets'),'')||']', ' | ' order by io)
     from jsonb_array_elements(d->'items') with ordinality x(i,io)) items
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') with ordinality y(d,dn)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and t.name ~ '^ACTIVE [1-5]$' and dn <= 6
order by t.name, dn
