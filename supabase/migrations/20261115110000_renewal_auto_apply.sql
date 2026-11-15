-- =====================================================================
-- ΦΟΡΜΑ — Ανανέωση προγράμματος: αυτόματη εμφάνιση μετά από λίγο
--   ai_proposals.auto_apply_at : πότε εφαρμόζεται μόνη της η πρόταση (αν δεν την απορρίψει/εγκρίνει πρώτα ο owner)
--   ai_settings.auto_apply_seconds : μετά από πόσα δευτερόλεπτα (προς το παρόν 20)
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
alter table public.ai_proposals add column if not exists auto_apply_at timestamptz;
alter table public.ai_settings  add column if not exists auto_apply_seconds integer not null default 20 check (auto_apply_seconds between 0 and 86400);

-- όσες ανανεώσεις περιμένουν ήδη (όχι ευαίσθητες) εφαρμόζονται με το επόμενο άνοιγμα της εφαρμογής
update public.ai_proposals set auto_apply_at = now()
 where button_key = 'program_renewal' and status = 'pending' and coalesce(sensitive, false) = false and auto_apply_at is null;
