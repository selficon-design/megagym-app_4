-- ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ: μόνο πόδια/γάμπες του PRO 6 → PRO MAX 1, 2, 3 (ημέρα προς ημέρα).
--   Σε κάθε ημέρα, η άσκηση ΓΑΜΠΩΝ του PRO MAX γίνεται η άσκηση ποδιών του PRO 6 (άσκηση, εξοπλισμός, μυϊκή ομάδα).
--   Όπου η ημέρα δεν έχει γάμπες (ημέρες με 1 άσκηση ποδιών), αλλάζει η μοναδική άσκηση ποδιών.
--   Η άλλη άσκηση ποδιών (στις ημέρες με 2) και όλες οι υπόλοιπες ασκήσεις μένουν ίδιες.
-- Τα PRO MAX κρατούν τη δική τους ένταση (set/επαναλήψεις/διάλειμμα/tempo/until failure). Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  src jsonb; r record; days jsonb; newdays jsonb; d jsonb; sd jsonb; di int; newitems jsonb; it jsonb; s_it jsonb;
  ii int; target int; nlegs int;
begin
  select data into src from public.template_programs
   where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name='PRO 6' limit 1;
  if src is null then raise exception 'Δεν βρέθηκε το PRO 6'; end if;

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'women_lower_pro6_legs_to_promax1_3_20261125', to_jsonb(t0) from public.template_programs t0
  where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name in ('PRO MAX 1','PRO MAX 2','PRO MAX 3');

  for r in select id, data from public.template_programs
           where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name in ('PRO MAX 1','PRO MAX 2','PRO MAX 3') loop
    days := coalesce(r.data->'days','[]'::jsonb); newdays := '[]'::jsonb;
    for di in 0 .. jsonb_array_length(days)-1 loop
      d := days->di; sd := src->'days'->di; s_it := null; target := null;
      select i into s_it from jsonb_array_elements(coalesce(sd->'items','[]'::jsonb)) i
       where i->>'groupLabel' ilike 'LEGS%' or i->>'groupLabel' ilike 'CALVES%' limit 1;
      if s_it is not null then
        -- στόχος: οι γάμπες της ημέρας· αλλιώς η μοναδική άσκηση ποδιών
        select (o-1)::int into target from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) with ordinality x(i,o)
         where i->>'groupLabel' ilike 'CALVES%' order by o limit 1;
        if target is null then
          select count(*) into nlegs from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) i where i->>'groupLabel' ilike 'LEGS%';
          if nlegs = 1 then
            select (o-1)::int into target from jsonb_array_elements(d->'items') with ordinality x(i,o) where i->>'groupLabel' ilike 'LEGS%' limit 1;
          end if;
        end if;
      end if;
      if target is not null then
        newitems := '[]'::jsonb; ii := 0;
        for it in select value from jsonb_array_elements(d->'items') loop
          if ii = target then
            it := it || jsonb_build_object('exercise', s_it->'exercise', 'groupLabel', s_it->'groupLabel', 'equipment', coalesce(s_it->'equipment','[]'::jsonb));
          end if;
          newitems := newitems || jsonb_build_array(it); ii := ii + 1;
        end loop;
        d := jsonb_set(d, '{items}', newitems);
      end if;
      newdays := newdays || jsonb_build_array(d);
    end loop;
    update public.template_programs set data = jsonb_set(data, '{days}', newdays), updated_at = now() where id = r.id;
  end loop;
end $$;
