-- =====================================================================
-- ΦΟΡΜΑ — Όλα τα έτοιμα προγράμματα ΓΥΝΑΙΚΩΝ: UNTIL FAILURE μία μονάδα κάτω
--   0 → -1, -1 → -2, -2 → -3, -3 μένει -3 (όχι κάτω από -3). Μόνο ασκήσεις με βάρη.
--   Σημάδι data.failureShifted = true ώστε να μη γίνει ποτέ δεύτερη φορά.
-- =====================================================================
update public.template_programs t
   set data = jsonb_set(
         jsonb_set(t.data, '{days}', (
           select coalesce(jsonb_agg(
             d || jsonb_build_object('items', (
               select coalesce(jsonb_agg(
                 case when coalesce(i->>'type','muscle') <> 'cardio' and (i->>'failure') ~ '^-?[0-9]+$'
                      then i || jsonb_build_object('failure', greatest((i->>'failure')::int - 1, -3))
                      else i end order by io), '[]'::jsonb)
               from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) with ordinality x(i, io)))
             order by dord), '[]'::jsonb)
           from jsonb_array_elements(coalesce(t.data->'days','[]'::jsonb)) with ordinality y(d, dord))),
         '{failureShifted}', 'true'::jsonb),
       updated_at = now()
 where t.gender = 'ΓΥΝΑΙΚΕΣ' and coalesce((t.data->>'failureShifted')::boolean, false) = false;
