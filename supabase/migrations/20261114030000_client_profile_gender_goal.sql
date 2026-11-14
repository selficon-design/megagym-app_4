-- =====================================================================
-- ΦΟΡΜΑ — Προσωπικά στοιχεία: φύλο & στόχος
--   gender : 'ΑΝΔΡΑΣ' | 'ΓΥΝΑΙΚΑ' (χρειάζεται για τις επιλογές της ανανέωσης προγράμματος)
--   goal   : ελεύθερο κείμενο, π.χ. «ΑΥΞΗΣΗ ΜΥΪΚΟΥ ΙΣΤΟΥ»
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
alter table public.client_profiles add column if not exists gender text check (gender is null or gender in ('ΑΝΔΡΑΣ','ΓΥΝΑΙΚΑ'));
alter table public.client_profiles add column if not exists goal text;
