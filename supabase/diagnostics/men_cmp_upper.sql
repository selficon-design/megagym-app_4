-- Άνδρες: σύγκριση «όλο το σώμα» με «έμφαση πάνω» ανά πρόγραμμα (όχι προσωπικά δεδομένα)
select coalesce(f.name,u.name) name, f.sort_order fo, u.sort_order uo, u.is_published upub,
  (f.data->'days') = (u.data->'days') same_days, f.photo_url = u.photo_url same_photo,
  (select n.name from public.template_programs n where n.id::text = u.data->>'next') u_next, (select n.sub_category from public.template_programs n where n.id::text = u.data->>'next') u_next_sub
from (select * from public.template_programs where gender='ΑΝΔΡΕΣ' and sub_category='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ') f
full join (select * from public.template_programs where gender='ΑΝΔΡΕΣ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ') u on u.name=f.name
order by coalesce(f.sort_order,u.sort_order)
