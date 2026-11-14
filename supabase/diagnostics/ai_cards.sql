-- Κάρτες κανόνων AI ανά έκδοση (όχι προσωπικά δεδομένα)
select v.version_no, v.status, c.kind, c.title, c.button_key, c.active, length(c.body) as chars
from public.ai_rule_cards c join public.ai_rule_versions v on v.id = c.version_id
where v.status in ('draft','published') order by v.version_no, c.sort
