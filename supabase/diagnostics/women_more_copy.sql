select 'M' k, b.name, b.is_published visible, b.photo_url is not null has_photo,
  (a.data - 'next' - 'topCategoryPhoto') = (b.data - 'next' - 'topCategoryPhoto') same_as_lower,
  (select u.name from public.template_programs u where u.id::text = b.data->>'next') next_name,
  (select u.sub_category = b.sub_category from public.template_programs u where u.id::text = b.data->>'next') next_same_cat
from public.template_programs b
left join public.template_programs a on a.gender=b.gender and a.top_category=b.top_category and a.sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and a.name=b.name
where b.gender='ΓΥΝΑΙΚΕΣ' and b.sub_category='ΜΕ ΑΚΟΜΗ ΠΕΡΙΣΣΟΤΕΡΗ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ'
order by b.sort_order
