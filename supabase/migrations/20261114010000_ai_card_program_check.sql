-- =====================================================================
-- ΦΟΡΜΑ — Κάρτα «Έλεγχος προγράμματος» στο Κέντρο Κανόνων AI (στο ΠΡΟΧΕΙΡΟ)
--   Οι 3 κανόνες του ιδιοκτήτη μεταφέρονται από τον κώδικα σε κάρτα, ώστε να αλλάζουν
--   από την εφαρμογή. Ο owner τη βλέπει, τη διορθώνει και πατά «Δημοσίευση».
--   Αν δεν υπάρχει πρόχειρο, δημιουργείται (αντίγραφο της δημοσιευμένης έκδοσης).
--   Δεν προστίθεται δεύτερη φορά αν υπάρχει ήδη κάρτα για το κουμπί στο πρόχειρο.
-- =====================================================================
do $$
declare v_draft uuid; v_pub uuid; v_no integer; v_sort integer;
begin
  select id into v_draft from public.ai_rule_versions where app = 'forma' and status = 'draft';
  if v_draft is null then
    select coalesce(max(version_no), 0) + 1 into v_no from public.ai_rule_versions where app = 'forma';
    insert into public.ai_rule_versions (app, version_no, status, note, created_by)
      values ('forma', v_no, 'draft', 'Κάρτα «Έλεγχος προγράμματος»', null) returning id into v_draft;
    select id into v_pub from public.ai_rule_versions where app = 'forma' and status = 'published';
    if v_pub is not null then
      insert into public.ai_rule_cards (version_id, kind, title, body, button_key, scope, active, sort)
        select v_draft, kind, title, body, button_key, scope, active, sort from public.ai_rule_cards where version_id = v_pub;
    end if;
  end if;

  if exists (select 1 from public.ai_rule_cards where version_id = v_draft and kind = 'button' and button_key = 'program_check') then
    return;
  end if;
  select coalesce(max(sort), 0) + 10 into v_sort from public.ai_rule_cards where version_id = v_draft;

  insert into public.ai_rule_cards (version_id, kind, title, body, button_key, scope, active, sort) values (
    v_draft, 'button', 'Έλεγχος προγράμματος — κανόνες TRANSFORMATION',
$body$Ελέγχεις πρόγραμμα που έφτιαξε μόνος του ο αθλούμενος. Για κάθε θέμα κάνεις ΜΙΑ πρόταση με εξήγηση και ερώτηση «να το αλλάξω ή συνεχίζεις;». Αν όλα είναι εντάξει, το λες καθαρά και δεν προτείνεις τίποτα.

1. ΔΙΑΛΕΙΜΜΑ (Αύξηση μυϊκού ιστού): από 90 δευτερόλεπτα και πάνω.
   - 90sec → εντάξει.
   - 120sec και πάνω → πρότεινε ότι θα μπορούσε να ξεκινήσει από 90sec. Ερώτηση: «Θέλεις να το αλλάξω σε 90 δευτερόλεπτα ή να συνεχίσεις με τον χρόνο διαλείμματος που έχεις βάλει;»
   - Κάτω από 90sec → πρότεινε 90sec.

2. ΕΠΑΝΑΛΗΨΕΙΣ: αν είναι «13 έως 15», πες ότι καλύτερο θα ήταν «10 έως 12» ή «8 έως 10». Ερώτηση: «Θέλεις να το αλλάξω σε 10 έως 12 ή να συνεχίσεις με 13 έως 15;»

3. UNTIL FAILURE:
   - -3 ή -2 → εντάξει.
   - -1 ή 0 → εξήγησε ότι αυτό δεν είναι πρόγραμμα TRANSFORMATION: δεν μπορείς σε όλα τα set να πηγαίνεις until failure. Πιο ασφαλές είναι until failure -3, ή μόνο στο 1-2 τελευταίο set until failure -1 ή 0. Το until failure δίνει τα μέγιστα αποτελέσματα όταν ακολουθείται το πρωτόκολλο TRANSFORMATION. Πρότεινε αλλαγή σε -3.

Όταν το ίδιο θέμα υπάρχει σε πολλές ασκήσεις, κάνε μία πρόταση που τις περιλαμβάνει όλες.$body$,
    'program_check', 'program', true, v_sort);
end $$;
