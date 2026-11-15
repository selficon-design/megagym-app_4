-- Πόσος εξοπλισμός υπάρχει στον ενεργό κατάλογο για κάποιες ασκήσεις ποδιών (όχι προσωπικά δεδομένα)
select k as exercise, jsonb_array_length(v.data->'EQUIPMENT_BY_EXERCISE'->k) as n_eq
from public.exercise_catalog_versions v,
     unnest(array['Άρσεις γοφών - Hip Thrust','Λακτίσματα γλουτιαίων - Glute Kickbacks','Απαγωγοί','Προσαγωγοί','Bulgarian Squat','Άρσεις θανάτου με ελαφρώς λυγισμένα πόδια - Romanian RDL']) k
where v.is_active
