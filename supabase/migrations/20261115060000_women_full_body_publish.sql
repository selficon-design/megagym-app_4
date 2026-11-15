-- =====================================================================
-- ΦΟΡΜΑ — Δημοσίευση των 20 προγραμμάτων γυναικών «ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ · ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ»
--   (τα αντίγραφα των ανδρών). Το παλιό «BEGINNER 2 (αντίγραφο)» μένει κρυφό.
-- =====================================================================
update public.template_programs w
   set is_published = true, updated_at = now()
 where w.gender = 'ΓΥΝΑΙΚΕΣ' and w.top_category = 'ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and w.sub_category = 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ'
   and w.is_published = false
   and exists (select 1 from public.template_programs m
               where m.gender = 'ΑΝΔΡΕΣ' and m.top_category = w.top_category and m.sub_category = w.sub_category and m.name = w.name);
