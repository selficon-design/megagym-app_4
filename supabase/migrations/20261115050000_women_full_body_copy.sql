-- =====================================================================
-- ΦΟΡΜΑ — Τα προγράμματα «ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ · ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ» των ανδρών
--         αντιγράφονται ίδια στις ΓΥΝΑΙΚΕΣ (ίδια ονόματα, σειρά, ημέρες, ασκήσεις, κείμενα).
--   • Μπαίνουν ΚΡΥΦΑ (is_published = false) — ο owner τα ελέγχει, αλλάζει φωτογραφίες και τα δημοσιεύει.
--   • Το «Επόμενο πρόγραμμα» (data.next) δείχνει στα αντίστοιχα προγράμματα των γυναικών.
--   • Αν δεν υπάρχει οργανόγραμμα γυναικών, αντιγράφεται των ανδρών με τα νέα προγράμματα.
--   • Δεν ξαναντιγράφει ό,τι υπάρχει ήδη (ίδιο όνομα στην ίδια κατηγορία γυναικών).
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
do $$
declare
  r record;
  g text;
begin
  drop table if exists _map;
  create temp table _map (old_id uuid primary key, new_id uuid not null) on commit drop;

  insert into _map (old_id, new_id)
  select m.id, gen_random_uuid()
  from public.template_programs m
  where m.gender = 'ΑΝΔΡΕΣ' and m.top_category = 'ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and m.sub_category = 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ'
    and not exists (select 1 from public.template_programs w
                    where w.gender = 'ΓΥΝΑΙΚΕΣ' and w.top_category = m.top_category
                      and w.sub_category = m.sub_category and w.name = m.name);

  insert into public.template_programs
    (id, gender, top_category, top_category_photo_url, sub_category, sub_category_description, sub_category_results,
     sub_category_photo_url, name, photo_url, num_days, description, results, nutrition, notes, data,
     is_published, sort_order, created_at, updated_at)
  select mp.new_id, 'ΓΥΝΑΙΚΕΣ', m.top_category, m.top_category_photo_url, m.sub_category, m.sub_category_description, m.sub_category_results,
     m.sub_category_photo_url, m.name, m.photo_url, m.num_days, m.description, m.results, m.nutrition, m.notes, m.data,
     false, m.sort_order, now(), now()
  from public.template_programs m join _map mp on mp.old_id = m.id;

  -- «Επόμενο πρόγραμμα» → το αντίστοιχο των γυναικών
  update public.template_programs t
     set data = jsonb_set(t.data, '{next}', to_jsonb(mp2.new_id::text))
    from _map mp, _map mp2
   where t.id = mp.new_id and (t.data->>'next') = mp2.old_id::text;

  -- Οργανόγραμμα γυναικών (μόνο αν δεν υπάρχει ήδη)
  if exists (select 1 from _map) and exists (select 1 from public.program_flows where gender = 'ΑΝΔΡΕΣ')
     and not exists (select 1 from public.program_flows where gender = 'ΓΥΝΑΙΚΕΣ') then
    select graph::text into g from public.program_flows where gender = 'ΑΝΔΡΕΣ';
    for r in select * from _map loop
      g := replace(g, r.old_id::text, r.new_id::text);
    end loop;
    insert into public.program_flows (gender, graph) values ('ΓΥΝΑΙΚΕΣ', g::jsonb);
  end if;
end $$;
