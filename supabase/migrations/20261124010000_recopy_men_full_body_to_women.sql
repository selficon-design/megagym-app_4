-- Ξανά-αντιγραφή ΑΝΔΡΕΣ · ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ → ΓΥΝΑΙΚΕΣ · ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ και ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ,
-- ώστε να περάσουν οι διορθώσεις των ανδρών (BEGINNER 1 ημέρα 3, PRO MAX 1–3 ημέρες 5/8/11).
-- Κρατά τις γυναικείες φωτογραφίες, την ορατότητα και τα id. Οι ΑΝΔΡΕΣ δεν αλλάζουν. Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  top constant text := 'ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ';
  fb  constant text := 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ';
  tg record;
begin
  for tg in select * from (values
      ('ΓΥΝΑΙΚΕΣ', 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ',                 true),
      ('ΓΥΝΑΙΚΕΣ', 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ',  true)
    ) v(gender, sub, keep_photo)
  loop
    insert into public.template_programs_backup (template_id, reason, data)
    select id, 'copy_men_full_body_to_women_20261124', to_jsonb(t) from public.template_programs t
    where gender=tg.gender and top_category=top and sub_category=tg.sub;

    delete from public.template_programs u
    where u.gender=tg.gender and u.top_category=top and u.sub_category=tg.sub
      and not exists (select 1 from public.template_programs f where f.gender='ΑΝΔΡΕΣ' and f.top_category=top and f.sub_category=fb and f.name=u.name);

    insert into public.template_programs
      (id, gender, top_category, top_category_photo_url, sub_category, name, photo_url, num_days, description, results, nutrition, notes, data, is_published, sort_order, created_at, updated_at)
    select gen_random_uuid(), tg.gender, top,
           case when tg.keep_photo then (select x.top_category_photo_url from public.template_programs x where x.gender=tg.gender and x.top_category=top and x.top_category_photo_url is not null limit 1) else f.top_category_photo_url end,
           tg.sub, f.name, case when tg.keep_photo then null else f.photo_url end,
           f.num_days, f.description, f.results, f.nutrition, f.notes, f.data, false, f.sort_order, now(), now()
    from public.template_programs f
    where f.gender='ΑΝΔΡΕΣ' and f.top_category=top and f.sub_category=fb
      and not exists (select 1 from public.template_programs u where u.gender=tg.gender and u.top_category=top and u.sub_category=tg.sub and u.name=f.name);

    update public.template_programs u
       set photo_url = case when tg.keep_photo then u.photo_url else f.photo_url end,
           num_days=f.num_days, description=f.description, results=f.results, nutrition=f.nutrition, notes=f.notes,
           data = case when tg.keep_photo and (u.data ? 'topCategoryPhoto') then f.data || jsonb_build_object('topCategoryPhoto', u.data->'topCategoryPhoto') else f.data end,
           sort_order=f.sort_order, updated_at=now()
      from public.template_programs f
     where u.gender=tg.gender and u.top_category=top and u.sub_category=tg.sub
       and f.gender='ΑΝΔΡΕΣ' and f.top_category=top and f.sub_category=fb and f.name=u.name;

    -- «επόμενο» → στο αντίστοιχο πρόγραμμα της ίδιας κατηγορίας
    update public.template_programs u
       set data = jsonb_set(u.data, '{next}', to_jsonb(u2.id::text))
      from public.template_programs fnext, public.template_programs u2
     where u.gender=tg.gender and u.top_category=top and u.sub_category=tg.sub
       and fnext.id::text = u.data->>'next' and fnext.gender='ΑΝΔΡΕΣ' and fnext.sub_category=fb
       and u2.gender=tg.gender and u2.top_category=top and u2.sub_category=tg.sub and u2.name=fnext.name;
  end loop;
end $$;
