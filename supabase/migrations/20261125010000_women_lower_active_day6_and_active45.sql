-- ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ
--   ACTIVE 1 ημέρα 6: πρέσα → Προσαγωγοί (Technogym Adductor)
--   ACTIVE 2 ημέρα 6: πρέσα → Απαγωγοί  (Technogym Abductor)
--   ACTIVE 3 ημέρα 6: πρέσα → Προσαγωγοί (Technogym Adductor)
--   ACTIVE 4 και 5, ημέρες 1–6, όπως το ACTIVE 1:
--     1ες γάμπες → Leg Press (Technogym ή Linear Leg press SELF ICON) · 2ες → Hip Thrust (Technogym ή SELF ICON)
--     3ες (καθιστός) → Γάμπες Όρθιος στο Calf Stretcher SELF ICON · πρέσα της ημέρας 6 → Προσαγωγοί (Technogym)
--     οι ημέρες 7–8 δεν αλλάζουν
-- Οι νέες ασκήσεις κρατούν set/επαναλήψεις/διάλειμμα/tempo/until failure. Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  cat jsonb; t record; days jsonb; newdays jsonb; d jsonb; di int; newitems jsonb; it jsonb; nth int; slot text; d6 text;
  eq_lp jsonb; eq_lin jsonb; eq_ht_tg jsonb; eq_ht_si jsonb; eq_stretch jsonb; eq_add jsonb; eq_abd jsonb;
  ex_lp text; ex_ht text; ex_stand text; ex_add text; ex_abd text; gl_lp text; gl_ht text; gl_add text; gl_abd text;
begin
  select v.data into cat from public.exercise_catalog_versions v where v.is_active limit 1;
  if cat is null then raise exception 'Δεν υπάρχει ενεργός κατάλογος'; end if;

  select x.key, y.e into ex_lp, eq_lp from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Πιέσεις ποδιών - Leg Press' and btrim(y.e->>'name')='Πιέσεις ποδιών Leg Press Technogym' limit 1;
  select y.e into eq_lin from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Πιέσεις ποδιών - Leg Press' and btrim(y.e->>'name')='Πιέσεις ποδιών Linear Leg press SELF ICON' limit 1;
  select x.key, y.e into ex_ht, eq_ht_tg from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις γοφών - Hip Thrust' and btrim(y.e->>'name')='Άρσεις γοφών - Hip Thrust Technogym' limit 1;
  select y.e into eq_ht_si from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις γοφών - Hip Thrust' and btrim(y.e->>'name')='Άρσεις γοφών - Hip Thrust SELF ICON' limit 1;
  select x.key, y.e into ex_stand, eq_stretch from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Γάμπες Όρθιος' and btrim(y.e->>'name')='Γάμπες Όρθιος στο Calf Stretcher SELF ICON' limit 1;
  select x.key, y.e into ex_add, eq_add from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Προσαγωγοί' and btrim(y.e->>'name')='Προσαγωγοί στο Technogym Adductor' limit 1;
  select x.key, y.e into ex_abd, eq_abd from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Απαγωγοί' and btrim(y.e->>'name')='Απαγωγοί στο Technogym Abductor' limit 1;
  if eq_lp is null or eq_lin is null or eq_ht_tg is null or eq_ht_si is null or eq_stretch is null or eq_add is null or eq_abd is null then
    raise exception 'Λείπει εξοπλισμός από τον κατάλογο';
  end if;

  select cat->'groupLabels'->>g.key into gl_lp  from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_lp))  limit 1;
  select cat->'groupLabels'->>g.key into gl_ht  from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_ht))  limit 1;
  select cat->'groupLabels'->>g.key into gl_add from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_add)) limit 1;
  select cat->'groupLabels'->>g.key into gl_abd from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_abd)) limit 1;
  gl_lp := coalesce(gl_lp,'LEGS - ΠΟΔΙΑ'); gl_ht := coalesce(gl_ht,'LEGS - ΠΟΔΙΑ'); gl_add := coalesce(gl_add,'LEGS - ΠΟΔΙΑ'); gl_abd := coalesce(gl_abd,'LEGS - ΠΟΔΙΑ');

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'women_lower_active_day6_active45_20261125', to_jsonb(t0) from public.template_programs t0
  where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ'
    and name in ('ACTIVE 1','ACTIVE 2','ACTIVE 3','ACTIVE 4','ACTIVE 5');

  for t in select id, name, data from public.template_programs
           where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ'
             and name in ('ACTIVE 1','ACTIVE 2','ACTIVE 3','ACTIVE 4','ACTIVE 5') loop
    d6 := case when t.name='ACTIVE 2' then 'ABD' else 'ADD' end;
    days := coalesce(t.data->'days','[]'::jsonb); newdays := '[]'::jsonb; nth := 0;
    for di in 0 .. jsonb_array_length(days)-1 loop
      d := days->di; slot := null;
      -- ACTIVE 4/5: γάμπες των ημερών 1–6 όπως στο ACTIVE 1 (τα ACTIVE 1–3 έγιναν ήδη)
      if t.name in ('ACTIVE 4','ACTIVE 5') and di < 6
         and exists (select 1 from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) z where z->>'groupLabel' ilike '%ΓΑΜΠ%') then
        nth := nth + 1;
        slot := case nth when 1 then 'LP' when 2 then 'HT' when 3 then 'ST' end;
      end if;
      newitems := '[]'::jsonb;
      for it in select value from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) loop
        if slot is not null and it->>'groupLabel' ilike '%ΓΑΜΠ%' then
          if slot='LP' then it := it || jsonb_build_object('exercise', ex_lp, 'groupLabel', gl_lp, 'equipment', jsonb_build_array(eq_lp, eq_lin));
          elsif slot='HT' then it := it || jsonb_build_object('exercise', ex_ht, 'groupLabel', gl_ht, 'equipment', jsonb_build_array(eq_ht_tg, eq_ht_si));
          elsif slot='ST' then it := it || jsonb_build_object('exercise', ex_stand, 'equipment', jsonb_build_array(eq_stretch));
          end if;
        elsif di = 5 and btrim(coalesce(it->>'exercise','')) = btrim(ex_lp) then
          -- ημέρα 6: η πρέσα γίνεται προσαγωγοί (ACTIVE 2: απαγωγοί)
          if d6='ADD' then it := it || jsonb_build_object('exercise', ex_add, 'groupLabel', gl_add, 'equipment', jsonb_build_array(eq_add));
          else             it := it || jsonb_build_object('exercise', ex_abd, 'groupLabel', gl_abd, 'equipment', jsonb_build_array(eq_abd));
          end if;
        end if;
        newitems := newitems || jsonb_build_array(it);
      end loop;
      newdays := newdays || jsonb_build_array(jsonb_set(d, '{items}', newitems));
    end loop;
    update public.template_programs set data = jsonb_set(data, '{days}', newdays), updated_at = now() where id = t.id;
  end loop;
end $$;
