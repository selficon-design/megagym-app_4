-- ΓΥΝΑΙΚΕΣ · ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ — PRO 1–6: σειρά εξοπλισμού στα Glute Kickbacks:
-- 1) Technogym Glute Press, 2) τροχαλία Technogym Cable Jungle, 3) τροχαλία Technogym Cross Over
update public.template_programs t
   set data = jsonb_set(t.data, '{days}', (
     select jsonb_agg(
       jsonb_set(d, '{items}', coalesce((
         select jsonb_agg(
           case when i->>'exercise' = 'Λακτίσματα γλουτιαίων - Glute Kickbacks' then
             jsonb_set(i, '{equipment}', coalesce((
               select jsonb_agg(e order by case when e->>'name' ilike '%Glute Press%' then 1 when e->>'name' ilike '%Jungle%' then 2 when e->>'name' ilike '%Cross Over%' then 3 else 4 end, eo)
               from jsonb_array_elements(i->'equipment') with ordinality q(e, eo)), '[]'::jsonb))
           else i end order by io)
         from jsonb_array_elements(d->'items') with ordinality z(i, io)), '[]'::jsonb))
       order by dn)
     from jsonb_array_elements(t.data->'days') with ordinality x(d, dn))),
       updated_at = now()
 where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category='ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ ΜΕΡΟΣ ΤΟΥ ΣΩΜΑΤΟΣ' and t.name ~ '^PRO [1-6]$'
   and exists (select 1 from jsonb_array_elements(t.data->'days') d2, jsonb_array_elements(d2->'items') i2 where i2->>'exercise' = 'Λακτίσματα γλουτιαίων - Glute Kickbacks');
