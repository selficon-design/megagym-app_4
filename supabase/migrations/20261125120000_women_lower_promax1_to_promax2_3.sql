-- Γυναίκες «ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ»: όλες οι ημέρες του PRO MAX 1 (ασκήσεις, μυϊκή ομάδα, εξοπλισμός, αερόβια)
-- περνούν στις ίδιες ημέρες των PRO MAX 2 και PRO MAX 3.
-- Κάθε πρόγραμμα κρατά τη δική του ένταση ανά ημέρα: η άσκηση στη θέση Ν της ημέρας παίρνει
-- SET/REP/διάλειμμα/TEMPO/FAILURE από τη θέση Ν της ίδιας ημέρας του προγράμματος (αν λείπει, από την 1η άσκηση της ημέρας).
do $$
declare
  src jsonb; r record; newdays jsonb;
begin
  select data into src from public.template_programs
   where gender='ΓΥΝΑΙΚΕΣ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name='PRO MAX 1' limit 1;
  if src is null then raise exception 'Δεν βρέθηκε το PRO MAX 1'; end if;

  for r in select id, data from public.template_programs
            where gender='ΓΥΝΑΙΚΕΣ' and sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and name in ('PRO MAX 2','PRO MAX 3')
  loop
    insert into public.template_programs_backup (template_id, reason, data) values (r.id, 'women_lower_promax1_to_promax2_3_20261125', r.data);

    select jsonb_agg(
      case when src->'days'->(n::int-1) is not null then
        jsonb_set(d, '{items}', coalesce((
          select jsonb_agg(case when coalesce(si->>'type','muscle')='muscle'
                                then si || coalesce((
                                     select jsonb_strip_nulls(jsonb_build_object('set', ti->'set', 'rep', ti->'rep', 'rest', ti->'rest', 'tempo', ti->'tempo', 'failure', ti->'failure'))
                                     from jsonb_array_elements(d->'items') with ordinality y(ti, tio)
                                     where coalesce(ti->>'type','muscle')='muscle'
                                     order by (tio = sio) desc, tio limit 1), '{}'::jsonb)
                                else si end order by sio)
          from jsonb_array_elements(src->'days'->(n::int-1)->'items') with ordinality z(si, sio)), '[]'::jsonb))
      else d end order by n)
    into newdays
    from jsonb_array_elements(r.data->'days') with ordinality x(d, n);

    update public.template_programs set data = jsonb_set(data, '{days}', newdays), updated_at = now() where id = r.id;
  end loop;
end $$;
