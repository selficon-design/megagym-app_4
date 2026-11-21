-- «Απαγωγοί»: ο εξοπλισμός «Προσαγωγοί στο Technogym Abductor» (παλιό όνομα) γίνεται «Απαγωγοί στο Technogym Abductor»,
-- όπως στο Excel (με τα στοιχεία του από τον ενεργό κατάλογο). Αντίγραφο ασφαλείας πρώτα.
do $$
declare neweq jsonb;
begin
  select e into neweq from public.exercise_catalog_versions v, jsonb_array_elements(v.data->'EQUIPMENT_BY_EXERCISE'->'Απαγωγοί') e
   where v.is_active and e->>'name' = 'Απαγωγοί στο Technogym Abductor' limit 1;
  if neweq is null then raise notice 'abductor equipment not found in catalog'; return; end if;

  insert into public.template_programs_backup (template_id, reason, data)
  select id, 'abductor_equipment_fix', data from public.template_programs t
  where t.data::text like '%Προσαγωγοί στο Technogym Abductor%';

  update public.template_programs t
  set data = jsonb_set(t.data, '{days}', (
    select jsonb_agg(
      case when jsonb_typeof(d->'items')='array' then jsonb_set(d, '{items}', (
        select jsonb_agg(
          case when i->>'exercise' = 'Απαγωγοί' and jsonb_typeof(i->'equipment')='array'
               then jsonb_set(i, '{equipment}', (
                      select coalesce(jsonb_agg(case when coalesce(e->>'name', e#>>'{}') = 'Προσαγωγοί στο Technogym Abductor' then neweq else e end order by eo), '[]'::jsonb)
                      from jsonb_array_elements(i->'equipment') with ordinality q(e, eo)))
               else i end order by io)
        from jsonb_array_elements(d->'items') with ordinality x(i, io)))
      else d end order by dn)
    from jsonb_array_elements(t.data->'days') with ordinality y(d, dn)))
  where t.data::text like '%Προσαγωγοί στο Technogym Abductor%';
end $$;
