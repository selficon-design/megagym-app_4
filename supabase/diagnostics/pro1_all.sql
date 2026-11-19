-- PRO 1 ανδρών: όλες οι θέσεις με πλήθος εξοπλισμού (όχι προσωπικά δεδομένα)
select dn as dday, io as pos, i->>'groupLabel' grp, i->>'exercise' ex, jsonb_array_length(coalesce(i->'equipment','[]')) n_eq
from public.template_programs t
cross join lateral jsonb_array_elements(t.data->'days') with ordinality y(d,dn)
cross join lateral jsonb_array_elements(d->'items') with ordinality x(i,io)
where t.name='PRO 1' and t.gender='ΑΝΔΡΕΣ' and coalesce(t.sub_category,'')='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ' order by 1,2
