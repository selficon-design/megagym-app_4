-- ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ — PRO 1–6, ημέρα 11: Γάμπες Καθιστός → Λακτίσματα γλουτιαίων - Glute Kickbacks
-- (εξοπλισμός: όλες οι επιλογές του καταλόγου). Κρατά set/επαναλήψεις/διάλειμμα/tempo/until failure. Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  cat jsonb; ex_kb text; eqs jsonb; gl text; r record; days jsonb; newdays jsonb; d jsonb; di int; newitems jsonb; it jsonb;
begin
  select v.data into cat from public.exercise_catalog_versions v where v.is_active limit 1;
  select x.key, x.value into ex_kb, eqs from jsonb_each(cat->'EQUIPMENT_BY_EXERCISE') x(key,value) where btrim(x.key)='Λακτίσματα γλουτιαίων - Glute Kickbacks' limit 1;
  if ex_kb is null or jsonb_array_length(coalesce(eqs,'[]'::jsonb)) = 0 then raise exception 'Δεν βρέθηκαν τα Glute Kickbacks στον κατάλογο'; end if;
  select cat->'groupLabels'->>g.key into gl from jsonb_each(cat->'EXERCISES') g where exists (select 1 from jsonb_array_elements_text(g.value) n where btrim(n)=btrim(ex_kb)) limit 1;
  gl := coalesce(gl, 'LEGS - ΠΟΔΙΑ');

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'women_lower_pro1_6_day11_kickbacks_20261125', to_jsonb(t0) from public.template_programs t0
  where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name ~ '^PRO [1-6]$';

  for r in select id, data from public.template_programs
           where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name ~ '^PRO [1-6]$' loop
    days := coalesce(r.data->'days','[]'::jsonb); newdays := '[]'::jsonb;
    for di in 0 .. jsonb_array_length(days)-1 loop
      d := days->di;
      if di = 10 then
        newitems := '[]'::jsonb;
        for it in select value from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) loop
          if btrim(coalesce(it->>'exercise','')) in ('Γάμπες Καθηστός','Γάμπες Καθιστός') then
            it := it || jsonb_build_object('exercise', ex_kb, 'groupLabel', gl, 'equipment', eqs);
          end if;
          newitems := newitems || jsonb_build_array(it);
        end loop;
        d := jsonb_set(d, '{items}', newitems);
      end if;
      newdays := newdays || jsonb_build_array(d);
    end loop;
    update public.template_programs set data = jsonb_set(data, '{days}', newdays), updated_at = now() where id = r.id;
  end loop;
end $$;
