-- Γυναίκες: οι φωτογραφίες των προγραμμάτων «ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ» περνούν στα ίδια προγράμματα (ίδιο όνομα)
-- των κατηγοριών «ΜΕ ΕΜΦΑΣΗ…» και «ΜΕ ΑΚΟΜΗ ΠΕΡΙΣΣΟΤΕΡΗ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ»
update public.template_programs t
set photo_url = s.photo_url
from public.template_programs s
where t.gender = 'ΓΥΝΑΙΚΕΣ' and s.gender = 'ΓΥΝΑΙΚΕΣ'
  and s.sub_category = 'ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ'
  and t.sub_category in ('ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ', 'ΜΕ ΑΚΟΜΗ ΠΕΡΙΣΣΟΤΕΡΗ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ')
  and t.name = s.name
  and coalesce(s.photo_url, '') <> '';
