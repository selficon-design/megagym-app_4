-- =====================================================================
-- ΦΟΡΜΑ — Κατάλογος ασκήσεων από το Excel (BUILDER.xlsx)
--   Κάθε «Ανέβασμα Excel» γράφει μια νέα έκδοση. Μόνο μία είναι ενεργή·
--   οι παλιές μένουν για επαναφορά. Η εφαρμογή διαβάζει την ενεργή έκδοση
--   (αν δεν υπάρχει καμία, χρησιμοποιεί τον ενσωματωμένο κατάλογο).
--   data = { EXERCISES, EQUIPMENT_BY_EXERCISE, GYMS, groupLabels }
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.exercise_catalog_versions (
  id           bigserial primary key,
  data         jsonb not null,
  file_name    text,
  summary      jsonb,          -- πλήθη / αλλαγές για το ιστορικό
  is_active    boolean not null default false,
  created_by   uuid default auth.uid() references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  activated_at timestamptz
);
create unique index if not exists exercise_catalog_one_active
  on public.exercise_catalog_versions (is_active) where is_active;
alter table public.exercise_catalog_versions enable row level security;

-- Όλοι οι συνδεδεμένοι βλέπουν την ενεργή έκδοση· ο owner βλέπει και το ιστορικό.
drop policy if exists "exercise catalog read" on public.exercise_catalog_versions;
create policy "exercise catalog read" on public.exercise_catalog_versions for select to authenticated
  using (is_active or public.ai_is_owner());
-- Οι αλλαγές γίνονται μόνο μέσα από τις δύο συναρτήσεις παρακάτω (χωρίς άμεσο insert/update/delete).

-- Νέα έκδοση από Excel → γίνεται αμέσως ενεργή.
create or replace function public.exercise_catalog_publish(p_data jsonb, p_file_name text, p_summary jsonb)
returns bigint language plpgsql security definer set search_path = public as $$
declare new_id bigint;
begin
  if not public.ai_is_owner() then raise exception 'Μόνο ο owner αλλάζει τον κατάλογο.' using errcode = '42501'; end if;
  if p_data is null or coalesce(jsonb_typeof(p_data->'EXERCISES'), '') <> 'object' or coalesce(jsonb_typeof(p_data->'EQUIPMENT_BY_EXERCISE'), '') <> 'object' then
    raise exception 'Μη έγκυρος κατάλογος.' using errcode = '22023';
  end if;
  update public.exercise_catalog_versions set is_active = false where is_active;
  insert into public.exercise_catalog_versions (data, file_name, summary, is_active, created_by, activated_at)
  values (p_data, left(p_file_name, 200), p_summary, true, auth.uid(), now())
  returning id into new_id;
  return new_id;
end $$;

-- Επαναφορά παλιάς έκδοσης. p_id = null → επιστροφή στον ενσωματωμένο κατάλογο της εφαρμογής.
create or replace function public.exercise_catalog_activate(p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.ai_is_owner() then raise exception 'Μόνο ο owner αλλάζει τον κατάλογο.' using errcode = '42501'; end if;
  if p_id is not null and not exists (select 1 from public.exercise_catalog_versions where id = p_id) then
    raise exception 'Η έκδοση δεν βρέθηκε.' using errcode = 'P0002';
  end if;
  update public.exercise_catalog_versions set is_active = false where is_active;
  if p_id is not null then
    update public.exercise_catalog_versions set is_active = true, activated_at = now() where id = p_id;
  end if;
end $$;

revoke all on function public.exercise_catalog_publish(jsonb, text, jsonb) from public, anon;
revoke all on function public.exercise_catalog_activate(bigint) from public, anon;
grant execute on function public.exercise_catalog_publish(jsonb, text, jsonb) to authenticated;
grant execute on function public.exercise_catalog_activate(bigint) to authenticated;
