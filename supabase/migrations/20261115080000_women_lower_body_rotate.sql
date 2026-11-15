-- =====================================================================
-- ΦΟΡΜΑ — Γυναίκες «ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ»: οι θέσεις που ήταν ΓΑΜΠΕΣ
--   (μπήκαν ως Hip Thrust) γίνονται εναλλάξ, με τη σειρά που εμφανίζονται στο πρόγραμμα:
--   1η Hip Thrust → 2η Glute Kickbacks → 3η Απαγωγοί → ξανά Hip Thrust …
--   Ίδια set / επαναλήψεις / διάλειμμα / tempo / ένταση. Εξοπλισμός από τον ενεργό κατάλογο.
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα (δίνει πάντα το ίδιο αποτέλεσμα).
-- =====================================================================
do $$
declare
  rot constant text[] := array['Άρσεις γοφών - Hip Thrust','Λακτίσματα γλουτιαίων - Glute Kickbacks','Απαγωγοί'];
  cat jsonb; r record; d jsonb; it jsonb; days jsonb; items jsonb; k int; ex text;
begin
  select data->'EQUIPMENT_BY_EXERCISE' into cat from public.exercise_catalog_versions where is_active order by id desc limit 1;
  for r in select id, data from public.template_programs
           where gender='ΓΥΝΑΙΚΕΣ' and top_category='ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' loop
    k := 0; days := '[]'::jsonb;
    for d in select value from jsonb_array_elements(coalesce(r.data->'days','[]'::jsonb)) loop
      items := '[]'::jsonb;
      for it in select value from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) loop
        if (it->>'exercise') = any(rot) and (it->>'groupLabel') ilike '%ΠΟΔΙΑ%' then
          ex := rot[(k % 3) + 1]; k := k + 1;
          it := it || jsonb_build_object('exercise', ex, 'equipment', coalesce(cat->ex, '[]'::jsonb));
        end if;
        items := items || jsonb_build_array(it);
      end loop;
      days := days || jsonb_build_array(d || jsonb_build_object('items', items));
    end loop;
    update public.template_programs set data = jsonb_set(data, '{days}', days), updated_at = now() where id = r.id;
  end loop;
end $$;
