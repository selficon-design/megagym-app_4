-- ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ: σε κάθε ημέρα (1–12), η άσκηση ποδιών/γαμπών των PRO 4, 5, 6
-- γίνεται ίδια με του PRO 3 (άσκηση, εξοπλισμός, μυϊκή ομάδα). Οι υπόλοιπες ασκήσεις δεν αλλάζουν.
-- Κάθε πρόγραμμα κρατά τη δική του ένταση (set/επαναλήψεις/διάλειμμα/tempo/until failure). Αντίγραφο ασφαλείας πρώτα.
-- Αλλάζει μόνο όπου και τα δύο προγράμματα έχουν ακριβώς 1 άσκηση ποδιών/γαμπών στην ημέρα.
do $$
declare
  src jsonb; r record; days jsonb; newdays jsonb; d jsonb; sd jsonb; di int; newitems jsonb; it jsonb; s_it jsonb; ns int; nt int;
begin
  select data into src from public.template_programs
   where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name='PRO 3' limit 1;
  if src is null then raise exception 'Δεν βρέθηκε το PRO 3'; end if;

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'women_lower_pro3_legs_to_pro4_6_20261125', to_jsonb(t0) from public.template_programs t0
  where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name in ('PRO 4','PRO 5','PRO 6');

  for r in select id, data from public.template_programs
           where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name in ('PRO 4','PRO 5','PRO 6') loop
    days := coalesce(r.data->'days','[]'::jsonb); newdays := '[]'::jsonb;
    for di in 0 .. jsonb_array_length(days)-1 loop
      d := days->di; sd := src->'days'->di;
      select count(*) into nt from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) i where i->>'groupLabel' ilike 'LEGS%' or i->>'groupLabel' ilike 'CALVES%';
      select count(*) into ns from jsonb_array_elements(coalesce(sd->'items','[]'::jsonb)) i where i->>'groupLabel' ilike 'LEGS%' or i->>'groupLabel' ilike 'CALVES%';
      if sd is not null and nt = 1 and ns = 1 then
        select i into s_it from jsonb_array_elements(sd->'items') i where i->>'groupLabel' ilike 'LEGS%' or i->>'groupLabel' ilike 'CALVES%' limit 1;
        newitems := '[]'::jsonb;
        for it in select value from jsonb_array_elements(d->'items') loop
          if it->>'groupLabel' ilike 'LEGS%' or it->>'groupLabel' ilike 'CALVES%' then
            it := it || jsonb_build_object('exercise', s_it->'exercise', 'groupLabel', s_it->'groupLabel', 'equipment', coalesce(s_it->'equipment','[]'::jsonb));
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
