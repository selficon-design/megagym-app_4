-- ΑΝΔΡΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ ΜΕΡΟΣ:
-- 1) ξανά-αντιγραφή από ΑΝΔΡΕΣ · ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ (περνούν οι διορθώσεις των ημερών 5 και 8 στα PRO MAX)
-- 2) αντικατάσταση γαμπών:
--    BEGINNER … PRO 6 : οι 4 πρώτες μέρες με γάμπες → ΩΜΟΙ, ΠΛΑΤΗ, ΣΤΗΘΟΣ, ΔΙΚΕΦΑΛΟΙ (οι υπόλοιπες μένουν)
--    PRO MAX 1–3      : ημέρα 1 ΩΜΟΙ, 3 ΠΛΑΤΗ, 4 ΣΤΗΘΟΣ, 7 ΠΛΑΤΗ, 9 ΣΤΗΘΟΣ, 10 ΔΙΚΕΦΑΛΟΙ (5, 6, 11, 12 μένουν γάμπες)
--    Η νέα άσκηση κρατά set / επαναλήψεις / διάλειμμα / tempo / until failure — αλλάζουν άσκηση, εξοπλισμός, μυϊκή ομάδα.
-- Το ΑΝΔΡΕΣ · ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ ΔΕΝ αλλάζει. Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  top constant text := 'ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ';
  fb  constant text := 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ';
  up  constant text := 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ';
  cat jsonb;
  rep jsonb := '{}'::jsonb;      -- S/B/C/Bi → {exercise, groupLabel, eq}
  spec record; k text; e jsonb; found_eq jsonb;
  t record; days jsonb; newdays jsonb; d jsonb; di int; items jsonb; newitems jsonb; it jsonb;
  nth int; slot text; changed int;
begin
  select data into cat from public.exercise_catalog_versions where is_active limit 1;
  if cat is null then raise exception 'Δεν υπάρχει ενεργός κατάλογος'; end if;

  for spec in select * from (values
      ('S',  'SHOULDERS - ΩΜΟΙ',     'Ανασηκώσεις Ώμων - Shrugs', 'Ανασηκώσεις Ώμων με αλτήρες στο πλάι, όρθιος'),
      ('B',  'BACΚ -  ΠΛΑΤΗ',        'Σκυφτή κωπηλατική στον επικλινή με κανονική λαβή - Chest-Supported-Grip Incline Row', 'Σκυφτή κωπηλατική στον επικλινή 45° με αλτήρες κανονική λαβή'),
      ('C',  'CHEST - ΣΤΗΘΟΣ',       'Βυθίσεις στήθους - Chest Dips', 'Βυθίσεις στήθους σε δίζυγο Knee Up/Chin+Pull Up SELF ICON'),
      ('Bi', 'BICEPS - ΔΙΚΕΦΑΛΟΙ',   'Κάμψεις δικεφάλων ανάποδη λαβή (λαβή ίσια)- reverse Bicep Curl', 'Κάμψεις δικεφάλων ανάποδη λαβή (λαβή ίσια) με αλτήρες- reverse Bicep Curl')
    ) v(code, grp, ex, eqname)
  loop
    found_eq := null; k := null;
    select x.key, y.e into k, found_eq
      from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key, value), jsonb_array_elements(x.value) y(e)
     where btrim(x.key) = btrim(spec.ex) and btrim(y.e->>'name') = btrim(spec.eqname) limit 1;
    if found_eq is null then raise exception 'Δεν βρέθηκε στον κατάλογο: % / %', spec.ex, spec.eqname; end if;
    rep := rep || jsonb_build_object(spec.code, jsonb_build_object('exercise', k, 'groupLabel', spec.grp, 'eq', found_eq));
  end loop;

  -- αντίγραφο ασφαλείας
  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'men_upper_recopy_replace_calves_20261123', to_jsonb(t0) from public.template_programs t0
  where gender='ΑΝΔΡΕΣ' and top_category=top and sub_category=up;

  -- 1) ξανά-αντιγραφή (κρατά id και ορατότητα)
  update public.template_programs u
     set photo_url=f.photo_url, num_days=f.num_days, description=f.description, results=f.results, nutrition=f.nutrition, notes=f.notes,
         data=f.data, sort_order=f.sort_order, updated_at=now()
    from public.template_programs f
   where u.gender='ΑΝΔΡΕΣ' and u.top_category=top and u.sub_category=up
     and f.gender='ΑΝΔΡΕΣ' and f.top_category=top and f.sub_category=fb and f.name=u.name;
  update public.template_programs u
     set data = jsonb_set(u.data, '{next}', to_jsonb(u2.id::text))
    from public.template_programs fnext, public.template_programs u2
   where u.gender='ΑΝΔΡΕΣ' and u.top_category=top and u.sub_category=up
     and fnext.id::text = u.data->>'next' and fnext.gender='ΑΝΔΡΕΣ' and fnext.sub_category=fb
     and u2.gender='ΑΝΔΡΕΣ' and u2.top_category=top and u2.sub_category=up and u2.name=fnext.name;

  -- 2) αντικατάσταση γαμπών
  for t in select id, name, data from public.template_programs
           where gender='ΑΝΔΡΕΣ' and top_category=top and sub_category=up loop
    days := coalesce(t.data->'days', '[]'::jsonb); newdays := '[]'::jsonb; nth := 0; changed := 0;
    for di in 0 .. jsonb_array_length(days)-1 loop
      d := days->di; items := coalesce(d->'items', '[]'::jsonb); slot := null;
      if exists (select 1 from jsonb_array_elements(items) z where z->>'groupLabel' ilike '%ΓΑΜΠ%') then
        nth := nth + 1;
        if t.name like 'PRO MAX%' then
          slot := case di+1 when 1 then 'S' when 3 then 'B' when 4 then 'C' when 7 then 'B' when 9 then 'C' when 10 then 'Bi' else null end;
        else
          slot := case nth when 1 then 'S' when 2 then 'B' when 3 then 'C' when 4 then 'Bi' else null end;
        end if;
      end if;
      if slot is not null then
        newitems := '[]'::jsonb;
        for it in select value from jsonb_array_elements(items) loop
          if it->>'groupLabel' ilike '%ΓΑΜΠ%' then
            it := it || jsonb_build_object('exercise', rep->slot->>'exercise', 'groupLabel', rep->slot->>'groupLabel',
                                           'equipment', jsonb_build_array(rep->slot->'eq'));
            changed := changed + 1;
          end if;
          newitems := newitems || jsonb_build_array(it);
        end loop;
        d := jsonb_set(d, '{items}', newitems);
      end if;
      newdays := newdays || jsonb_build_array(d);
    end loop;
    if changed > 0 then
      update public.template_programs set data = jsonb_set(data, '{days}', newdays), updated_at = now() where id = t.id;
    end if;
  end loop;
end $$;
