-- Έτοιμα προγράμματα με κατηγορία εκτός της επίσημης λίστας (ΧΩΡΙΣ στοιχεία πελατών).
select gender, top_category, coalesce(sub_category, '') as sub_category, name, created_at::date as created
from public.template_programs
where top_category not in ('ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ', 'ΚΑΥΣΗΣ ΛΙΠΟΥΣ')
   or (top_category = 'ΚΑΥΣΗΣ ΛΙΠΟΥΣ' and coalesce(sub_category, '') not in ('ΚΑΥΣΗ ΛΙΠΟΥΣ ΜΕ ΒΑΡΗ', 'ΚΑΥΣΗ ΛΙΠΟΥΣ ΜΕ ΑΕΡΟΒΙΟ', 'ΚΑΥΣΗ ΛΙΠΟΥΣ ΜΕ ΒΑΡΗ ΚΑΙ ΑΕΡΟΒΙΟ'))
order by created_at
