-- =====================================================================
-- ΦΟΡΜΑ — Ιατρικό ιστορικό αθλούμενου (στα προσωπικά στοιχεία)
--   heart_problem          : καρδιολογικό πρόβλημα
--   high_blood_pressure    : υψηλή πίεση
--   doctor_allows_weights  : 'ΝΑΙ' | 'ΟΧΙ' — ο καρδιολόγος επιτρέπει άσκηση με αντιστάσεις/βάρη
-- Αν υπάρχει καρδιολογικό ή υψηλή πίεση: UNTIL FAILURE ποτέ πάνω από -3 (εφαρμογή + AI).
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
alter table public.client_profiles add column if not exists heart_problem boolean;
alter table public.client_profiles add column if not exists high_blood_pressure boolean;
alter table public.client_profiles add column if not exists doctor_allows_weights text check (doctor_allows_weights is null or doctor_allows_weights in ('ΝΑΙ','ΟΧΙ'));
