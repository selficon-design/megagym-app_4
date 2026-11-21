-- Άνδρες «ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ ΜΕΡΟΣ»: όλα τα προγράμματα γίνονται ξανά ίδια με το «ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ».
--  • Αντίγραφο ασφαλείας όλων πρώτα.
--  • Όσα υπάρχουν με το ίδιο όνομα ενημερώνονται στη θέση τους (κρατούν id και δημοσίευση).
--  • Όσα λείπουν δημιουργούνται (κρυφά). Όσα δεν υπάρχουν στο «όλο το σώμα» σβήνονται (μένουν στο αντίγραφο ασφαλείας).
--  • Το «επόμενο» δείχνει στο αντίστοιχο πρόγραμμα της ίδιας κατηγορίας.
do $$
declare
  up constant text := 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ';
  fb constant text := 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ';
begin
  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'men_upper_recopy_from_full_body', to_jsonb(t) from public.template_programs t
  where gender='ΑΝΔΡΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category=up;

  -- σβήνει όσα δεν έχουν αντίστοιχο στο «όλο το σώμα»
  delete from public.template_programs u
  where u.gender='ΑΝΔΡΕΣ' and u.top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and u.sub_category=up
    and not exists (select 1 from public.template_programs f where f.gender='ΑΝΔΡΕΣ' and f.top_category=u.top_category and f.sub_category=fb and f.name=u.name);

  -- δημιουργεί όσα λείπουν (κρυφά)
  insert into public.template_programs
    (id, gender, top_category, top_category_photo_url, sub_category, name, photo_url, num_days, description, results, nutrition, notes, data, is_published, sort_order, created_at, updated_at)
  select gen_random_uuid(), f.gender, f.top_category, f.top_category_photo_url, up, f.name, f.photo_url, f.num_days, f.description, f.results, f.nutrition, f.notes, f.data, false, f.sort_order, now(), now()
  from public.template_programs f
  where f.gender='ΑΝΔΡΕΣ' and f.top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and f.sub_category=fb
    and not exists (select 1 from public.template_programs u where u.gender='ΑΝΔΡΕΣ' and u.top_category=f.top_category and u.sub_category=up and u.name=f.name);

  -- ενημερώνει όλα με τα στοιχεία του «όλο το σώμα»
  update public.template_programs u
     set photo_url=f.photo_url, num_days=f.num_days, description=f.description, results=f.results, nutrition=f.nutrition, notes=f.notes,
         data=f.data, sort_order=f.sort_order, updated_at=now()
    from public.template_programs f
   where u.gender='ΑΝΔΡΕΣ' and u.top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and u.sub_category=up
     and f.gender='ΑΝΔΡΕΣ' and f.top_category=u.top_category and f.sub_category=fb and f.name=u.name;

  -- «επόμενο»: από το πρόγραμμα του «όλο το σώμα» στο αντίστοιχο της «έμφασης»
  update public.template_programs u
     set data = jsonb_set(u.data, '{next}', to_jsonb(u2.id::text))
    from public.template_programs fnext, public.template_programs u2
   where u.gender='ΑΝΔΡΕΣ' and u.top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and u.sub_category=up
     and fnext.id::text = u.data->>'next' and fnext.sub_category=fb
     and u2.gender='ΑΝΔΡΕΣ' and u2.top_category=u.top_category and u2.sub_category=up and u2.name=fnext.name;
end $$;
