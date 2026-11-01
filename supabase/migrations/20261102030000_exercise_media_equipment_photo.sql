-- ΦΟΡΜΑ — και η φωτογραφία ΕΞΟΠΛΙΣΜΟΥ αποθηκεύεται ανά «τίτλος άσκησης + εξοπλισμός»
-- (κάθε συνδυασμός είναι ξεχωριστή άσκηση με 3 στοιχεία: φωτο εξοπλισμού, φωτο άσκησης, βίντεο).
alter table public.exercise_media add column if not exists equipment_photo_url text;
