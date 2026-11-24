-- ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ — BEGINNER 1–3 και ACTIVE 1–3:
--   1ες γάμπες → Πιέσεις ποδιών - Leg Press (Leg Press Technogym· στα ACTIVE και Linear Leg press SELF ICON)
--   2ες γάμπες → Άρσεις γοφών - Hip Thrust (Hip Thrust Technogym ή Hip Thrust SELF ICON)
--   ACTIVE 1–3, 3ες γάμπες (καθιστός) → Γάμπες Όρθιος στο Calf Stretcher SELF ICON
--   ACTIVE 1–3, πρέσα που υπάρχει ήδη → + επιλογή εξοπλισμού Linear Hack Squat SELF ICON
-- Οι νέες ασκήσεις κρατούν set/επαναλήψεις/διάλειμμα/tempo/until failure. Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  cat jsonb;
  t record; days jsonb; newdays jsonb; d jsonb; di int; newitems jsonb; it jsonb;
  nth int; slot text; prog_active boolean;
  eq_lp jsonb; eq_lin jsonb; eq_hack jsonb; eq_ht_tg jsonb; eq_ht_si jsonb; eq_stretch jsonb;
  ex_lp text; ex_ht text; ex_stand text; gl_lp text; gl_ht text;
begin
  select data into cat from public.exercise_catalog_versions where is_active limit 1;
  if cat is null then raise exception 'Δεν υπάρχει ενεργός κατάλογος'; end if;

  -- εύρεση εξοπλισμού (ακριβές όνομα, χωρίς κενά στην άκρη)
  select x.key, y.e into ex_lp, eq_lp from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Πιέσεις ποδιών - Leg Press' and btrim(y.e->>'name')='Πιέσεις ποδιών Leg Press Technogym' limit 1;
  select y.e into eq_lin from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Πιέσεις ποδιών - Leg Press' and btrim(y.e->>'name')='Πιέσεις ποδιών Linear Leg press SELF ICON' limit 1;
  select y.e into eq_hack from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Πιέσεις ποδιών - Leg Press' and btrim(y.e->>'name')='Πιέσεις ποδιών - Linear Hack Squat SELF ICON' limit 1;
  select x.key, y.e into ex_ht, eq_ht_tg from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις γοφών - Hip Thrust' and btrim(y.e->>'name')='Άρσεις γοφών - Hip Thrust Technogym' limit 1;
  select y.e into eq_ht_si from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Άρσεις γοφών - Hip Thrust' and btrim(y.e->>'name')='Άρσεις γοφών - Hip Thrust SELF ICON' limit 1;
  select x.key, y.e into ex_stand, eq_stretch from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value), jsonb_array_elements(x.value) y(e)
   where btrim(x.key)='Γάμπες Όρθιος' and btrim(y.e->>'name')='Γάμπες Όρθιος στο Calf Stretcher SELF ICON' limit 1;
  if eq_lp is null or eq_lin is null or eq_hack is null or eq_ht_tg is null or eq_ht_si is null or eq_stretch is null then
    raise exception 'Λείπει εξοπλισμός από τον κατάλογο (lp=% lin=% hack=% ht_tg=% ht_si=% stretch=%)',
      eq_lp is not null, eq_lin is not null, eq_hack is not null, eq_ht_tg is not null, eq_ht_si is not null, eq_stretch is not null;
  end if;

  -- μυϊκή ομάδα από τον κατάλογο (ΠΟΔΙΑ → «LEGS - ΠΟΔΙΑ»)
  select cat->'groupLabels'->>g.key into gl_lp from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_lp)) limit 1;
  select cat->'groupLabels'->>g.key into gl_ht from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_ht)) limit 1;
  gl_lp := coalesce(gl_lp, 'LEGS - ΠΟΔΙΑ'); gl_ht := coalesce(gl_ht, 'LEGS - ΠΟΔΙΑ');

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'women_lower_beginner_active3_20261125', to_jsonb(t0) from public.template_programs t0
  where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ'
    and name in ('BEGINNER 1','BEGINNER 2','BEGINNER 3','ACTIVE 1','ACTIVE 2','ACTIVE 3');

  for t in select id, name, data from public.template_programs
           where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ'
             and name in ('BEGINNER 1','BEGINNER 2','BEGINNER 3','ACTIVE 1','ACTIVE 2','ACTIVE 3') loop
    prog_active := t.name like 'ACTIVE%';
    days := coalesce(t.data->'days','[]'::jsonb); newdays := '[]'::jsonb; nth := 0;
    for di in 0 .. jsonb_array_length(days)-1 loop
      d := days->di; slot := null;
      if exists (select 1 from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) z where z->>'groupLabel' ilike '%ΓΑΜΠ%') then
        nth := nth + 1;
        slot := case nth when 1 then 'LP' when 2 then 'HT' when 3 then (case when prog_active then 'ST' end) end;
      end if;
      newitems := '[]'::jsonb;
      for it in select value from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) loop
        if slot is not null and it->>'groupLabel' ilike '%ΓΑΜΠ%' then
          if slot = 'LP' then
            it := it || jsonb_build_object('exercise', ex_lp, 'groupLabel', gl_lp,
                    'equipment', case when prog_active then jsonb_build_array(eq_lp, eq_lin) else jsonb_build_array(eq_lp) end);
          elsif slot = 'HT' then
            it := it || jsonb_build_object('exercise', ex_ht, 'groupLabel', gl_ht, 'equipment', jsonb_build_array(eq_ht_tg, eq_ht_si));
          elsif slot = 'ST' then
            it := it || jsonb_build_object('exercise', ex_stand, 'equipment', jsonb_build_array(eq_stretch));
          end if;
        elsif prog_active and slot is null and btrim(coalesce(it->>'exercise','')) = btrim(ex_lp)
              and not exists (select 1 from jsonb_array_elements(coalesce(it->'equipment','[]'::jsonb)) q where btrim(q->>'name') = btrim(eq_hack->>'name')) then
          -- η πρέσα που υπήρχε ήδη (π.χ. ημέρα 6): + Linear Hack Squat SELF ICON
          it := jsonb_set(it, '{equipment}', coalesce(it->'equipment','[]'::jsonb) || jsonb_build_array(eq_hack));
        end if;
        newitems := newitems || jsonb_build_array(it);
      end loop;
      newdays := newdays || jsonb_build_array(jsonb_set(d, '{items}', newitems));
    end loop;
    update public.template_programs set data = jsonb_set(data, '{days}', newdays), updated_at = now() where id = t.id;
  end loop;
end $$;
