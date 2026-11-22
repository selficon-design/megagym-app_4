select gender, sub_category, sort_order, name, is_published, (photo_url is not null) as has_photo, left(coalesce(photo_url,''),90) as photo
from public.template_programs
where (gender='ΑΝΔΡΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ') or (gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ')
order by gender, sub_category, sort_order, name;
