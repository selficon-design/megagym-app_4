select t.name, d.ord, string_agg(i.ord || '.' || left(i.i->>'groupLabel',6) || ':' || btrim(i.i->>'exercise') || ' [' || (select string_agg(btrim(q->>'name'),' | ') from jsonb_array_elements(coalesce(i.i->'equipment','[]'::jsonb)) q) || ']', ' // ' order by i.ord) items
from public.template_programs t, jsonb_array_elements(t.data->'days') with ordinality d(d,ord), jsonb_array_elements(d.d->'items') with ordinality i(i,ord)
where t.gender='ΓΥΝΑΙΚΕΣ' and t.sub_category like 'ΜΕ ΕΜΦΑΣΗ ΣΤΟ ΚΑΤΩ%' and t.name in ('PRO 6','PRO MAX 1','PRO MAX 2','PRO MAX 3')
  and (i.i->>'groupLabel' ilike 'LEGS%' or i.i->>'groupLabel' ilike 'CALVES%')
group by t.name, t.sort_order, d.ord order by t.sort_order, d.ord
