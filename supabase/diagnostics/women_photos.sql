-- Φωτογραφίες γυναικείων προγραμμάτων ανά κατηγορία (όχι προσωπικά δεδομένα)
select left(coalesce(sub_category,''),14) sub, name, sort_order,
  case when coalesce(photo_url,'')='' then '-' else right(photo_url,40) end photo,
  case when coalesce(data->>'topCategoryPhoto','')='' then '-' else 'yes' end topcat_photo
from public.template_programs where gender='ΓΥΝΑΙΚΕΣ' order by sort_order, sub
