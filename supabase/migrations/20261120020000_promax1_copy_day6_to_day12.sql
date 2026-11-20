-- PRO MAX 1: η ημέρα 6 γράφεται όπως είναι στην ημέρα 12 (ασκήσεις — το όνομα της ημέρας 12 μένει). Αντίγραφο ασφαλείας πρώτα.
insert into public.template_programs_backup (template_id, reason, data)
select id, 'promax1_copy_day6_to_day12', data from public.template_programs
where id = 'bd4ed0e6-bf27-41a5-b5fd-2e13e73ab806';

update public.template_programs t
set data = jsonb_set(t.data, '{days,11,items}', coalesce(t.data->'days'->5->'items', '[]'::jsonb))
where t.id = 'bd4ed0e6-bf27-41a5-b5fd-2e13e73ab806' and jsonb_array_length(t.data->'days') = 12;
