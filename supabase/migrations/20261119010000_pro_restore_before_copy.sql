-- Επαναφορά των PRO 2–6 όπως ήταν πριν την αντιγραφή από το PRO 1 (από το αντίγραφο ασφαλείας)
update public.template_programs t
set data = b.data
from (select distinct on (template_id) template_id, data from public.template_programs_backup
      where reason = 'pro_copy_exercises_from_pro1' order by template_id, id) b
where b.template_id = t.id and b.data is not null;
