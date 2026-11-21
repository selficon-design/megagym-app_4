-- Leg curl σε όλα τα έτοιμα προγράμματα:
--   • άσκηση → «Κάμψεις τετρακεφάλων - Leg Curl» (όπως λέγεται στο Excel· η παλιά «…καθηστός - Leg Curl» δεν υπάρχει πια)
--   • BEGINNER 1–3: εξοπλισμός μόνο «καθηστός - Leg Curl Technogym»
--   • ACTIVE, POWER, ADVANCED, PRO, PRO MAX: «καθηστός» + «ξαπλωτός (μπρούμυτα) - Prone Leg Curl Technogym»
-- Ο εξοπλισμός παίρνεται από τον ενεργό κατάλογο (με φωτογραφίες κ.λπ.). Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  ex_new constant text := 'Κάμψεις τετρακεφάλων - Leg Curl';
  seat jsonb; prone jsonb;
begin
  select e into seat from public.exercise_catalog_versions v, jsonb_array_elements(v.data->'EQUIPMENT_BY_EXERCISE'->ex_new) e
   where v.is_active and e->>'name' ilike '%καθηστός%Leg Curl Technogym%' limit 1;
  select e into prone from public.exercise_catalog_versions v, jsonb_array_elements(v.data->'EQUIPMENT_BY_EXERCISE'->ex_new) e
   where v.is_active and e->>'name' ilike '%Prone Leg Curl%' limit 1;
  if seat is null or prone is null then raise notice 'leg curl equipment not found in catalog'; return; end if;

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'leg_curl_fix', data from public.template_programs t
  where exists (select 1 from jsonb_array_elements(t.data->'days') d, jsonb_array_elements(d->'items') i
                where i->>'exercise' in ('Κάμψεις τετρακεφάλων καθηστός - Leg Curl', ex_new));

  update public.template_programs t
  set data = jsonb_set(t.data, '{days}', (
    select jsonb_agg(
      case when jsonb_typeof(d->'items')='array' then jsonb_set(d, '{items}', (
        select jsonb_agg(
          case when i->>'exercise' in ('Κάμψεις τετρακεφάλων καθηστός - Leg Curl', ex_new)
               then i || jsonb_build_object('exercise', ex_new,
                                            'equipment', case when t.name ilike 'BEGINNER%' then jsonb_build_array(seat) else jsonb_build_array(seat, prone) end)
               else i end order by io)
        from jsonb_array_elements(d->'items') with ordinality x(i, io)))
      else d end order by dn)
    from jsonb_array_elements(t.data->'days') with ordinality y(d, dn)))
  where exists (select 1 from jsonb_array_elements(t.data->'days') d, jsonb_array_elements(d->'items') i
                where i->>'exercise' in ('Κάμψεις τετρακεφάλων καθηστός - Leg Curl', ex_new));
end $$;
