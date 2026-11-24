-- Γυναίκες «ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ»: οι ημέρες 7–12 του PRO 1 (ασκήσεις, μυϊκή ομάδα, εξοπλισμός, αερόβια)
-- περνούν στις ημέρες 7–12 των PRO 2 και PRO 3. Κάθε πρόγραμμα κρατά τη δική του ένταση: αν η άσκηση υπήρχε ήδη στην ίδια ημέρα
-- κρατά τα δικά της SET/REP/διάλειμμα/TEMPO/FAILURE, αλλιώς παίρνει τις πιο συχνές τιμές του προγράμματος. Οι ημέρες 1–6 δεν αλλάζουν.
do $$
declare
  src jsonb;
  r record;
  st jsonb;
  newdays jsonb;
begin
  select data into src from public.template_programs
   where gender='ΓΥΝΑΙΚΕΣ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name='PRO 1' limit 1;
  if src is null then return; end if;

  for r in select id, data from public.template_programs
            where gender='ΓΥΝΑΙΚΕΣ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name in ('PRO 2','PRO 3')
  loop
    insert into public.template_programs_backup (template_id, reason, data) values (r.id, 'women_lower_pro1_days7_12_to_pro2_3_20261125', r.data);

    -- η «ένταση» του προγράμματος: η πιο συχνή τιμή σε όλες τις ασκήσεις του
    select jsonb_build_object(
      'set',     (select i->'set'     from jsonb_array_elements(r.data->'days') d, jsonb_array_elements(d->'items') i where coalesce(i->>'type','muscle')='muscle' and i ? 'set'     group by i->'set'     order by count(*) desc limit 1),
      'rest',    (select i->'rest'    from jsonb_array_elements(r.data->'days') d, jsonb_array_elements(d->'items') i where coalesce(i->>'type','muscle')='muscle' and i ? 'rest'    group by i->'rest'    order by count(*) desc limit 1),
      'tempo',   (select i->'tempo'   from jsonb_array_elements(r.data->'days') d, jsonb_array_elements(d->'items') i where coalesce(i->>'type','muscle')='muscle' and i ? 'tempo'   group by i->'tempo'   order by count(*) desc limit 1),
      'failure', (select i->'failure' from jsonb_array_elements(r.data->'days') d, jsonb_array_elements(d->'items') i where coalesce(i->>'type','muscle')='muscle' and i ? 'failure' group by i->'failure' order by count(*) desc limit 1)
    ) into st;
    st := jsonb_strip_nulls(st);

    select jsonb_agg(
      case when n between 7 and 12 and src->'days'->(n::int-1) is not null then
        jsonb_set(d, '{items}', coalesce((
          select jsonb_agg(case when coalesce(si->>'type','muscle')='muscle'
                                then si || st || coalesce((   -- αν η ίδια άσκηση υπάρχει ήδη στην ίδια ημέρα, κρατά τις δικές της τιμές (π.χ. κοιλιακοί 13 έως 15)
                                     select jsonb_strip_nulls(jsonb_build_object('set', ti->'set', 'rep', ti->'rep', 'rest', ti->'rest', 'tempo', ti->'tempo', 'failure', ti->'failure'))
                                     from jsonb_array_elements(d->'items') ti where ti->>'exercise' = si->>'exercise' limit 1), '{}'::jsonb)
                                else si end order by sio)
          from jsonb_array_elements(src->'days'->(n::int-1)->'items') with ordinality z(si, sio)), '[]'::jsonb))
      else d end order by n)
    into newdays
    from jsonb_array_elements(r.data->'days') with ordinality x(d, n);

    update public.template_programs set data = jsonb_set(data, '{days}', newdays), updated_at = now() where id = r.id;
  end loop;
end $$;
