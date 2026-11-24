-- ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ — ACTIVE 4 και ACTIVE 5:
--   ημέρα 7: γάμπες → Απαγωγοί (Technogym Abductor)
--   ημέρα 8: Άρσεις θανάτου με λυγισμένα πόδια (RDL) → Άρσεις θανάτου με αλύγιστα πόδια (μπάρα ή αλτήρες)
-- Κρατούν set/επαναλήψεις/διάλειμμα/tempo/until failure. Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  cat jsonb; t record; days jsonb; newdays jsonb; d jsonb; di int; newitems jsonb; it jsonb;
  ex_abd text; eq_abd jsonb; gl_abd text; ex_sl text; eq_sl_bar jsonb; eq_sl_db jsonb; ex_rdl constant text := 'Άρσεις θανάτου με λυγισμένα πόδια - RDL';
begin
  select v.data into cat from public.exercise_catalog_versions v where v.is_active limit 1;
  select x.key, y.e into ex_abd, eq_abd from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Απαγωγοί' and btrim(y.e->>'name')='Απαγωγοί στο Technogym Abductor' limit 1;
  select x.key, y.e into ex_sl, eq_sl_bar from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις θανάτου με αλύγιστα πόδια - Straight-Leg Deadlift' and btrim(y.e->>'name')='Άρσεις θανάτου με αλύγιστα πόδια με μπάρα - Straight-Leg Deadlift' limit 1;
  select y.e into eq_sl_db from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις θανάτου με αλύγιστα πόδια - Straight-Leg Deadlift' and btrim(y.e->>'name')='Άρσεις θανάτου με αλύγιστα πόδια με αλτήρες- Straight-Leg Deadlift' limit 1;
  if eq_abd is null or eq_sl_bar is null or eq_sl_db is null then raise exception 'Λείπει εξοπλισμός από τον κατάλογο'; end if;
  select cat->'groupLabels'->>g.key into gl_abd from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_abd)) limit 1;
  gl_abd := coalesce(gl_abd, 'LEGS - ΠΟΔΙΑ');

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'women_lower_active45_days7_8_20261125', to_jsonb(t0) from public.template_programs t0
  where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name in ('ACTIVE 4','ACTIVE 5');

  for t in select id, data from public.template_programs
           where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name in ('ACTIVE 4','ACTIVE 5') loop
    days := coalesce(t.data->'days','[]'::jsonb); newdays := '[]'::jsonb;
    for di in 0 .. jsonb_array_length(days)-1 loop
      d := days->di; newitems := '[]'::jsonb;
      for it in select value from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) loop
        if di = 6 and it->>'groupLabel' ilike '%ΓΑΜΠ%' then
          it := it || jsonb_build_object('exercise', ex_abd, 'groupLabel', gl_abd, 'equipment', jsonb_build_array(eq_abd));
        elsif di = 7 and btrim(coalesce(it->>'exercise','')) = ex_rdl then
          it := it || jsonb_build_object('exercise', ex_sl, 'equipment', jsonb_build_array(eq_sl_bar, eq_sl_db));
        end if;
        newitems := newitems || jsonb_build_array(it);
      end loop;
      newdays := newdays || jsonb_build_array(jsonb_set(d, '{items}', newitems));
    end loop;
    update public.template_programs set data = jsonb_set(data, '{days}', newdays), updated_at = now() where id = t.id;
  end loop;
end $$;
