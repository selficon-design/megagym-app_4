-- Σειρά PRO MAX 1, 2, 3 (21, 22, 23) στις δύο ανδρικές κατηγορίες
update public.template_programs set sort_order = 20 + substring(name from 'PRO MAX ([0-9]+)')::int
where gender = 'ΑΝΔΡΕΣ' and top_category = 'ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' and name ~ '^PRO MAX [0-9]+$'
  and sub_category in ('ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ', 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΠΑΝΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ');
