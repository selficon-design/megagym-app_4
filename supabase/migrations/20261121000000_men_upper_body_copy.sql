-- =====================================================================
-- Άνδρες: τα προγράμματα «ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ» αντιγράφονται ίδια (ίδια ονόματα, σειρά, ημέρες, ασκήσεις,
-- φωτογραφίες, κείμενα) στη νέα κατηγορία «ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ», για να συμπληρωθούν.
--   • Μπαίνουν ΚΡΥΦΑ (is_published = false) μέχρι να διορθωθούν και να δημοσιευτούν.
--   • Το «Επόμενο πρόγραμμα» (data.next) δείχνει στο αντίστοιχο αντίγραφο.
--   • Δεν ξαναντιγράφει ό,τι υπάρχει ήδη με το ίδιο όνομα στη νέα κατηγορία.
-- =====================================================================
do $$
begin
  drop table if exists _map;
  create temp table _map (old_id uuid primary key, new_id uuid not null) on commit drop;

  insert into _map (old_id, new_id)
  select m.id, gen_random_uuid()
  from public.template_programs m
  where m.gender = 'ΑΝΔΡΕΣ' and m.top_category = 'ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and m.sub_category = 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ'
    and not exists (select 1 from public.template_programs u
                    where u.gender = 'ΑΝΔΡΕΣ' and u.top_category = m.top_category
                      and u.sub_category = 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and u.name = m.name);

  insert into public.template_programs
    (id, gender, top_category, top_category_photo_url, sub_category, sub_category_description, sub_category_results,
     sub_category_photo_url, name, photo_url, num_days, description, results, nutrition, notes, data,
     is_published, sort_order, created_at, updated_at)
  select mp.new_id, m.gender, m.top_category, m.top_category_photo_url, 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ', null, null,
     null, m.name, m.photo_url, m.num_days, m.description, m.results, m.nutrition, m.notes, m.data,
     false, m.sort_order, now(), now()
  from public.template_programs m join _map mp on mp.old_id = m.id;

  update public.template_programs t
     set data = jsonb_set(t.data, '{next}', to_jsonb(mp2.new_id::text))
    from _map mp, _map mp2
   where t.id = mp.new_id and (t.data->>'next') = mp2.old_id::text;
end $$;
