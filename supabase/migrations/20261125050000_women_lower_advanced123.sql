-- ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ — ADVANCED 1, 2, 3:
--   1ες γάμπες (ημέρα 1) → Άρσεις θανάτου με λυγισμένα πόδια - RDL (μπάρα ή αλτήρες)
--   2ες γάμπες (ημέρα 3) → Άρσεις θανάτου με αλύγιστα πόδια - Straight-Leg Deadlift (μπάρα ή αλτήρες)
--   3ες γάμπες (ημέρα 5) → Προσαγωγοί (ADVANCED 2: Απαγωγοί), Technogym
-- Κρατούν set/επαναλήψεις/διάλειμμα/tempo/until failure. Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  cat jsonb; t record; days jsonb; newdays jsonb; d jsonb; di int; newitems jsonb; it jsonb; nth int; slot text;
  ex_rdl text; eq_rdl_bar jsonb; eq_rdl_db jsonb; ex_sl text; eq_sl_bar jsonb; eq_sl_db jsonb;
  ex_add text; eq_add jsonb; ex_abd text; eq_abd jsonb; gl_rdl text; gl_sl text; gl_add text; gl_abd text;
begin
  select v.data into cat from public.exercise_catalog_versions v where v.is_active limit 1;
  select x.key, y.e into ex_rdl, eq_rdl_bar from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις θανάτου με λυγισμένα πόδια - RDL' and btrim(y.e->>'name')='Άρσεις θανάτου με λυγισμένα πόδια με μπάρα - RDL' limit 1;
  select y.e into eq_rdl_db from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις θανάτου με λυγισμένα πόδια - RDL' and btrim(y.e->>'name')='Άρσεις θανάτου με λυγισμένα πόδια με αλτήρες - RDL' limit 1;
  select x.key, y.e into ex_sl, eq_sl_bar from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις θανάτου με αλύγιστα πόδια - Straight-Leg Deadlift' and btrim(y.e->>'name')='Άρσεις θανάτου με αλύγιστα πόδια με μπάρα - Straight-Leg Deadlift' limit 1;
  select y.e into eq_sl_db from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις θανάτου με αλύγιστα πόδια - Straight-Leg Deadlift' and btrim(y.e->>'name')='Άρσεις θανάτου με αλύγιστα πόδια με αλτήρες- Straight-Leg Deadlift' limit 1;
  select x.key, y.e into ex_add, eq_add from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Προσαγωγοί' and btrim(y.e->>'name')='Προσαγωγοί στο Technogym Adductor' limit 1;
  select x.key, y.e into ex_abd, eq_abd from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Απαγωγοί' and btrim(y.e->>'name')='Απαγωγοί στο Technogym Abductor' limit 1;
  if eq_rdl_bar is null or eq_rdl_db is null or eq_sl_bar is null or eq_sl_db is null or eq_add is null or eq_abd is null then
    raise exception 'Λείπει εξοπλισμός από τον κατάλογο';
  end if;
  select cat->'groupLabels'->>g.key into gl_rdl from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_rdl)) limit 1;
  select cat->'groupLabels'->>g.key into gl_sl  from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_sl))  limit 1;
  select cat->'groupLabels'->>g.key into gl_add from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_add)) limit 1;
  select cat->'groupLabels'->>g.key into gl_abd from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_abd)) limit 1;
  gl_rdl := coalesce(gl_rdl,'LEGS - ΠΟΔΙΑ'); gl_sl := coalesce(gl_sl,'LEGS - ΠΟΔΙΑ'); gl_add := coalesce(gl_add,'LEGS - ΠΟΔΙΑ'); gl_abd := coalesce(gl_abd,'LEGS - ΠΟΔΙΑ');

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'women_lower_advanced123_20261125', to_jsonb(t0) from public.template_programs t0
  where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ'
    and name in ('ADVANCED 1','ADVANCED 2','ADVANCED 3');

  for t in select id, name, data from public.template_programs
           where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ'
             and name in ('ADVANCED 1','ADVANCED 2','ADVANCED 3') loop
    days := coalesce(t.data->'days','[]'::jsonb); newdays := '[]'::jsonb; nth := 0;
    for di in 0 .. jsonb_array_length(days)-1 loop
      d := days->di; slot := null;
      if exists (select 1 from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) z where z->>'groupLabel' ilike '%ΓΑΜΠ%') then
        nth := nth + 1;
        slot := case nth when 1 then 'RDL' when 2 then 'SL' when 3 then (case when t.name='ADVANCED 2' then 'ABD' else 'ADD' end) end;
      end if;
      newitems := '[]'::jsonb;
      for it in select value from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) loop
        if slot is not null and it->>'groupLabel' ilike '%ΓΑΜΠ%' then
          if    slot='RDL' then it := it || jsonb_build_object('exercise', ex_rdl, 'groupLabel', gl_rdl, 'equipment', jsonb_build_array(eq_rdl_bar, eq_rdl_db));
          elsif slot='SL'  then it := it || jsonb_build_object('exercise', ex_sl,  'groupLabel', gl_sl,  'equipment', jsonb_build_array(eq_sl_bar, eq_sl_db));
          elsif slot='ADD' then it := it || jsonb_build_object('exercise', ex_add, 'groupLabel', gl_add, 'equipment', jsonb_build_array(eq_add));
          elsif slot='ABD' then it := it || jsonb_build_object('exercise', ex_abd, 'groupLabel', gl_abd, 'equipment', jsonb_build_array(eq_abd));
          end if;
        end if;
        newitems := newitems || jsonb_build_array(it);
      end loop;
      newdays := newdays || jsonb_build_array(jsonb_set(d, '{items}', newitems));
    end loop;
    update public.template_programs set data = jsonb_set(data, '{days}', newdays), updated_at = now() where id = t.id;
  end loop;
end $$;
