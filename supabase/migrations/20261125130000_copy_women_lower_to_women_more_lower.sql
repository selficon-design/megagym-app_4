-- Αντιγραφή ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ → ΓΥΝΑΙΚΕΣ · ΜΕ ΑΚΟΜΗ ΠΕΡΙΣΣΟΤΕΡΗ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ.
-- Κρατά τις φωτογραφίες, την ορατότητα και τα id των υπαρχόντων. Όσα λείπουν (π.χ. PRO MAX 1–3) μπαίνουν κρυφά.
-- Η «ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ» δεν αλλάζει. Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  top constant text := 'ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ';
  g   constant text := 'ΓΥΝΑΙΚΕΣ';
  src constant text := 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ';
  dst constant text := 'ΜΕ ΑΚΟΜΗ ΠΕΡΙΣΣΟΤΕΡΗ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ';
begin
  if not exists (select 1 from public.template_programs where gender=g and top_category=top and sub_category=src) then
    raise exception 'Δεν βρέθηκε η πηγή';
  end if;

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'copy_women_lower_to_more_lower_20261125', to_jsonb(t) from public.template_programs t
  where gender=g and top_category=top and sub_category=dst;

  delete from public.template_programs u
  where u.gender=g and u.top_category=top and u.sub_category=dst
    and not exists (select 1 from public.template_programs f where f.gender=g and f.top_category=top and f.sub_category=src and f.name=u.name);

  insert into public.template_programs
    (id, gender, top_category, top_category_photo_url, sub_category, name, photo_url, num_days, description, results, nutrition, notes, data, is_published, sort_order, created_at, updated_at)
  select gen_random_uuid(), g, top,
         coalesce((select x.top_category_photo_url from public.template_programs x where x.gender=g and x.top_category=top and x.sub_category=dst and x.top_category_photo_url is not null limit 1), f.top_category_photo_url),
         dst, f.name, f.photo_url, f.num_days, f.description, f.results, f.nutrition, f.notes, f.data, false, f.sort_order, now(), now()
  from public.template_programs f
  where f.gender=g and f.top_category=top and f.sub_category=src
    and not exists (select 1 from public.template_programs u where u.gender=g and u.top_category=top and u.sub_category=dst and u.name=f.name);

  update public.template_programs u
     set num_days=f.num_days, description=f.description, results=f.results, nutrition=f.nutrition, notes=f.notes,
         data = case when (u.data ? 'topCategoryPhoto') then f.data || jsonb_build_object('topCategoryPhoto', u.data->'topCategoryPhoto') else f.data end,
         sort_order=f.sort_order, updated_at=now()
    from public.template_programs f
   where u.gender=g and u.top_category=top and u.sub_category=dst
     and f.gender=g and f.top_category=top and f.sub_category=src and f.name=u.name;

  -- «επόμενο» → στο αντίστοιχο πρόγραμμα της ίδιας κατηγορίας
  update public.template_programs u
     set data = jsonb_set(u.data, '{next}', to_jsonb(u2.id::text))
    from public.template_programs fnext, public.template_programs u2
   where u.gender=g and u.top_category=top and u.sub_category=dst
     and fnext.id::text = u.data->>'next' and fnext.gender=g and fnext.sub_category=src
     and u2.gender=g and u2.top_category=top and u2.sub_category=dst and u2.name=fnext.name;
end $$;
