-- Γυναίκες «ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ», ACTIVE 1–5: ο διάδρομος σε ΟΛΕΣ τις ημέρες, εναλλάξ —
-- μονές ημέρες (1, 3, 5, 7) ΠΡΙΝ την προπόνηση, ζυγές (2, 4, 6, 8) ΜΕΤΑ, όπως διορθώθηκε στο ACTIVE 1.
-- Όπου η ημέρα είχε ήδη διάδρομο κρατά τα δικά του στοιχεία, αλλιώς παίρνει του ACTIVE 1. Αντίγραφο ασφαλείας πρώτα.
do $$
declare
  tm jsonb;
  r record;
  newdays jsonb;
begin
  select i into tm
  from public.template_programs t, jsonb_array_elements(t.data->'days') d, jsonb_array_elements(d->'items') i
  where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ' and t.name='ACTIVE 1'
    and i->>'type'='cardio' and upper(i->>'equipment') in ('ΔΙΑΔΡΟΜΟΣ') limit 1;
  if tm is null then return; end if;

  for r in select id, data from public.template_programs
            where gender='ΓΥΝΑΙΚΕΣ' and sub_category='ΓΥΜΝΑΖΕΙ ΟΛΟ ΤΟ ΣΩΜΑ' and name ~ '^ACTIVE [1-5]$'
  loop
    insert into public.template_programs_backup (template_id, reason, data) values (r.id, 'women_full_active_treadmill_alternate', r.data);
    select jsonb_agg(jsonb_set(d, '{items}',
      (with own as (select i from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) i where i->>'type'='cardio' and i->>'equipment' in ('ΔΙΑΔΡΟΜΟΣ','Διάδρομος') limit 1),
            rest as (select coalesce(jsonb_agg(i order by o), '[]'::jsonb) a from jsonb_array_elements(coalesce(d->'items','[]'::jsonb)) with ordinality z(i,o)
                     where not (coalesce(i->>'type','')='cardio' and coalesce(i->>'equipment','') in ('ΔΙΑΔΡΟΜΟΣ','Διάδρομος'))),
            c as (select coalesce((select i from own), tm) x)
       select case when n % 2 = 1 then jsonb_build_array((select x from c)) || (select a from rest)
                   else (select a from rest) || jsonb_build_array((select x from c)) end)
    ) order by n)
    into newdays
    from jsonb_array_elements(r.data->'days') with ordinality y(d, n);
    update public.template_programs set data = jsonb_set(data, '{days}', newdays) where id = r.id;
  end loop;
end $$;
