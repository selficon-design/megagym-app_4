-- =====================================================================
-- ΦΟΡΜΑ — ΓΥΝΑΙΚΕΣ · ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ · «ΜΕ ΑΚΟΜΗ ΠΕΡΙΣΣΟΤΕΡΗ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ»
--   Ίδια ονόματα/σειρά/κείμενα με το «ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ» των γυναικών, νέα κατανομή ομάδων:
--   • 4 (ή 8) ημέρες:  1) ΣΤΗΘΟΣ, ΠΟΔΙΑ, ΠΟΔΙΑ, ΚΟΙΛΙΑΚΟΙ   2) ΠΛΑΤΗ, ΔΙΚΕΦΑΛΟΙ, ΠΟΔΙΑ, ΠΟΔΙΑ
--                       3) ΩΜΟΙ, ΤΡΙΚΕΦΑΛΟΙ, ΠΟΔΙΑ, ΚΟΙΛΙΑΚΟΙ  4) ΠΟΔΙΑ, ΓΑΜΠΕΣ, ΠΟΔΙΑ, ΠΟΔΙΑ   (τα 8 = δύο φορές)
--   • 6 ή 12 ημέρες: κύκλος 3 ημερών (1–3 όπως πάνω) που επαναλαμβάνεται.
--   Set/επαναλήψεις/διάλειμμα/tempo/ένταση: από την ίδια θέση της ίδιας ημέρας του αρχικού προγράμματος.
--   Ασκήσεις: ό,τι έχει το αρχικό πρόγραμμα για κάθε ομάδα· στα ΠΟΔΙΑ εναλλάξ οι ασκήσεις ποδιών του
--   αρχικού + Hip Thrust, Glute Kickbacks, Απαγωγοί (χωρίς επανάληψη μέσα στην ίδια ημέρα).
--   Τα αερόβια της κάθε ημέρας μένουν στην ίδια θέση (αρχή/τέλος). Δημοσιευμένα.
-- Δεν ξαναντιγράφει ό,τι υπάρχει ήδη. Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
do $$
declare
  sub_src constant text := 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ';
  sub_new constant text := 'ΜΕ ΑΚΟΜΗ ΠΕΡΙΣΣΟΤΕΡΗ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ';
  pat4 constant text[] := array['CHEST,LEGS,LEGS,ABS','BACK,BICEPS,LEGS,LEGS','SHOULDERS,TRICEPS,LEGS,ABS','LEGS,CALVES,LEGS,LEGS'];
  pat3 constant text[] := array['CHEST,LEGS,LEGS,ABS','BACK,BICEPS,LEGS,LEGS','SHOULDERS,TRICEPS,LEGS,ABS'];
  extras constant text[] := array['Άρσεις γοφών - Hip Thrust','Λακτίσματα γλουτιαίων - Glute Kickbacks','Απαγωγοί'];
  cat jsonb; r record;
  sdays jsonb; n int; di int; sday jsonb; muscles jsonb; cardio_pre jsonb; cardio_post jsonb;
  keys text[]; p int; key text; srcit jsonb; params jsonb; newit jsonb; items jsonb; days jsonb;
  legpool jsonb; lc int; used text[]; tries int; cand jsonb; seen_mus boolean; it jsonb;
begin
  select data->'EQUIPMENT_BY_EXERCISE' into cat from public.exercise_catalog_versions where is_active order by id desc limit 1;

  drop table if exists _xmap;
  create temp table _xmap (old_id uuid primary key, new_id uuid not null) on commit drop;
  insert into _xmap
  select w.id, gen_random_uuid() from public.template_programs w
  where w.gender='ΓΥΝΑΙΚΕΣ' and w.top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and w.sub_category=sub_src and w.is_published
    and not exists (select 1 from public.template_programs x where x.gender='ΓΥΝΑΙΚΕΣ' and x.top_category=w.top_category and x.sub_category=sub_new and x.name=w.name);

  for r in select w.*, m.new_id from public.template_programs w join _xmap m on m.old_id = w.id loop
    sdays := coalesce(r.data->'days','[]'::jsonb); n := jsonb_array_length(sdays);
    if n = 0 then continue; end if;

    -- δεξαμενή ασκήσεων ποδιών: του αρχικού (με τον εξοπλισμό του) + επιπλέον από τον κατάλογο
    select coalesce(jsonb_agg(x order by ord), '[]'::jsonb) into legpool from (
      select distinct on (i->>'exercise') i as x, (d.o*100 + ii.o) as ord
      from jsonb_array_elements(sdays) with ordinality d(day,o)
      cross join lateral jsonb_array_elements(coalesce(d.day->'items','[]'::jsonb)) with ordinality ii(i,o)
      where (i->>'groupLabel') ilike 'LEGS%' order by i->>'exercise', d.o*100 + ii.o) q;
    for p in 1..array_length(extras,1) loop
      if not exists (select 1 from jsonb_array_elements(legpool) e where e->>'exercise' = extras[p]) then
        legpool := legpool || jsonb_build_array(jsonb_build_object('type','muscle','groupLabel','LEGS - ΠΟΔΙΑ','exercise',extras[p],'equipment',coalesce(cat->extras[p],'[]'::jsonb)));
      end if;
    end loop;
    lc := 0;

    days := '[]'::jsonb;
    for di in 0..n-1 loop
      sday := sdays->di;
      keys := string_to_array(case when n % 3 = 0 then pat3[(di % 3)+1] else pat4[(di % 4)+1] end, ',');
      -- μυϊκές ασκήσεις & αερόβια (πριν/μετά) της αρχικής ημέρας
      muscles := '[]'::jsonb; cardio_pre := '[]'::jsonb; cardio_post := '[]'::jsonb; seen_mus := false;
      for it in select value from jsonb_array_elements(coalesce(sday->'items','[]'::jsonb)) loop
        if it->>'type' = 'cardio' then
          if seen_mus then cardio_post := cardio_post || jsonb_build_array(it); else cardio_pre := cardio_pre || jsonb_build_array(it); end if;
        else muscles := muscles || jsonb_build_array(it); seen_mus := true; end if;
      end loop;

      items := cardio_pre; used := array[]::text[];
      for p in 1..4 loop
        key := keys[p];
        -- set/rep/... από την ίδια θέση της ημέρας (ή την τελευταία μυϊκή)
        params := coalesce(muscles->(least(p, greatest(jsonb_array_length(muscles),1)) - 1), '{}'::jsonb);
        params := jsonb_strip_nulls(jsonb_build_object('set',params->'set','rep',params->'rep','rest',params->'rest','tempo',params->'tempo','failure',params->'failure'));
        if key = 'LEGS' then
          tries := 0;
          loop
            cand := legpool->(lc % greatest(jsonb_array_length(legpool),1)); lc := lc + 1; tries := tries + 1;
            exit when cand is null or not ((cand->>'exercise') = any(used)) or tries > jsonb_array_length(legpool);
          end loop;
          srcit := cand;
        else
          select i into srcit from jsonb_array_elements(muscles) i where (i->>'groupLabel') ilike (case key
              when 'CHEST' then 'CHEST%' when 'ABS' then 'ABDOM%' when 'BACK' then 'BAC%' when 'BICEPS' then 'BICEP%'
              when 'SHOULDERS' then 'SHOULDER%' when 'TRICEPS' then 'TRICEP%' when 'CALVES' then 'CALV%' end) limit 1;
          if srcit is null then
            select i into srcit from jsonb_array_elements(sdays) d, jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) i
             where (i->>'groupLabel') ilike (case key
              when 'CHEST' then 'CHEST%' when 'ABS' then 'ABDOM%' when 'BACK' then 'BAC%' when 'BICEPS' then 'BICEP%'
              when 'SHOULDERS' then 'SHOULDER%' when 'TRICEPS' then 'TRICEP%' when 'CALVES' then 'CALV%' end) limit 1;
          end if;
        end if;
        if srcit is null then continue; end if;
        used := used || (srcit->>'exercise');
        newit := (srcit - 'set' - 'rep' - 'rest' - 'tempo' - 'failure') || params;
        items := items || jsonb_build_array(newit);
      end loop;
      items := items || cardio_post;
      days := days || jsonb_build_array(sday || jsonb_build_object('items', items));
    end loop;

    insert into public.template_programs
      (id, gender, top_category, top_category_photo_url, sub_category, sub_category_description, sub_category_results,
       sub_category_photo_url, name, photo_url, num_days, description, results, nutrition, notes, data,
       is_published, sort_order, created_at, updated_at)
    values (r.new_id, 'ΓΥΝΑΙΚΕΣ', r.top_category, r.top_category_photo_url, sub_new, null, null,
       r.sub_category_photo_url, r.name, r.photo_url, r.num_days, r.description, r.results, r.nutrition, r.notes,
       jsonb_set(r.data, '{days}', days), true, r.sort_order, now(), now());
  end loop;

  update public.template_programs t
     set data = jsonb_set(t.data, '{next}', to_jsonb(m2.new_id::text))
    from _xmap m, _xmap m2
   where t.id = m.new_id and (t.data->>'next') = m2.old_id::text;
end $$;
