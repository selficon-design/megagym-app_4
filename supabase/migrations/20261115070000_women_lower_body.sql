-- =====================================================================
-- ΦΟΡΜΑ — ΓΥΝΑΙΚΕΣ · ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ · «ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ»
--   Ίδια προγράμματα με το «ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ» των γυναικών, μόνο που κάθε άσκηση ΓΑΜΠΕΣ
--   γίνεται δεύτερη άσκηση ΠΟΔΙΩΝ (ίδια set / επαναλήψεις / διάλειμμα / tempo / ένταση):
--     ημέρα με Leg Extension → Leg Curl
--     ημέρα με Leg Curl      → Hip Thrust
--     ημέρα με Leg Press     → Απαγωγοί
--     αλλιώς                 → Hip Thrust
--   Ο εξοπλισμός της νέας άσκησης παίρνεται από τον ενεργό κατάλογο (Excel).
--   «Επόμενο πρόγραμμα» → το αντίστοιχο της νέας κατηγορίας. Δημοσιευμένα.
-- Δεν ξαναντιγράφει ό,τι υπάρχει ήδη. Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
do $$
declare
  sub_new constant text := 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ';
  ex_curl  constant text := 'Κάμψεις τετρακεφάλων καθηστός - Leg Curl';
  ex_hip   constant text := 'Άρσεις γοφών - Hip Thrust';
  ex_abd   constant text := 'Απαγωγοί';
  cat jsonb;
  leg_label text := 'LEGS - ΠΟΔΙΑ';
  r record; d jsonb; it jsonb; days jsonb; items jsonb; leg_ex text; repl text;
begin
  select data->'EQUIPMENT_BY_EXERCISE' into cat from public.exercise_catalog_versions where is_active order by id desc limit 1;

  drop table if exists _lmap;
  create temp table _lmap (old_id uuid primary key, new_id uuid not null) on commit drop;
  insert into _lmap
  select w.id, gen_random_uuid() from public.template_programs w
  where w.gender = 'ΓΥΝΑΙΚΕΣ' and w.top_category = 'ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and w.sub_category = 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ'
    and w.is_published
    and not exists (select 1 from public.template_programs x
                    where x.gender = 'ΓΥΝΑΙΚΕΣ' and x.top_category = w.top_category and x.sub_category = sub_new and x.name = w.name);

  for r in select w.*, m.new_id from public.template_programs w join _lmap m on m.old_id = w.id loop
    days := '[]'::jsonb;
    for d in select value from jsonb_array_elements(coalesce(r.data->'days','[]'::jsonb)) loop
      -- η άσκηση ποδιών που έχει ήδη η ημέρα
      select i->>'exercise' into leg_ex from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) i
       where (i->>'groupLabel') ilike '%ΠΟΔΙΑ%' limit 1;
      repl := case when leg_ex ilike '%Leg Extension%' then ex_curl
                   when leg_ex ilike '%Leg Curl%'      then ex_hip
                   when leg_ex ilike '%Leg Press%'     then ex_abd
                   else ex_hip end;
      items := '[]'::jsonb;
      for it in select value from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) loop
        if (it->>'groupLabel') ilike '%ΓΑΜΠ%' or (it->>'groupLabel') ilike '%CALV%' then
          it := it || jsonb_build_object('groupLabel', leg_label, 'exercise', repl,
                                         'equipment', coalesce(cat->repl, '[]'::jsonb));
        end if;
        items := items || jsonb_build_array(it);
      end loop;
      days := days || jsonb_build_array(d || jsonb_build_object('items', items));
    end loop;

    insert into public.template_programs
      (id, gender, top_category, top_category_photo_url, sub_category, sub_category_description, sub_category_results,
       sub_category_photo_url, name, photo_url, num_days, description, results, nutrition, notes, data,
       is_published, sort_order, created_at, updated_at)
    values (r.new_id, 'ΓΥΝΑΙΚΕΣ', r.top_category, r.top_category_photo_url, sub_new, null, null,
       r.sub_category_photo_url, r.name, r.photo_url, r.num_days, r.description, r.results, r.nutrition, r.notes,
       jsonb_set(coalesce(r.data,'{}'::jsonb), '{days}', days),
       true, r.sort_order, now(), now());
  end loop;

  update public.template_programs t
     set data = jsonb_set(t.data, '{next}', to_jsonb(m2.new_id::text))
    from _lmap m, _lmap m2
   where t.id = m.new_id and (t.data->>'next') = m2.old_id::text;
end $$;
