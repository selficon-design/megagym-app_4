-- Κατάσταση Κέντρου Κανόνων AI (ΧΩΡΙΣ στοιχεία πελατών).
select v.version_no, v.status, count(c.id) as cards,
       count(c.id) filter (where c.kind = 'button' and c.active) as active_button_cards
from public.ai_rule_versions v left join public.ai_rule_cards c on c.version_id = v.id
group by v.version_no, v.status
order by v.version_no
