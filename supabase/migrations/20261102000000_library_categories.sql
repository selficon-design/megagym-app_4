-- =====================================================================
-- ΦΟΡΜΑ — Κατηγορίες Βιβλιοθήκης + αποθήκευση φωτογραφιών
--   library_categories : φωτογραφία / περιγραφή / αποτελέσματα για κάθε κάρτα
--                        κατηγορίας της βιβλιοθήκης (μία φορά, όχι μέσα σε κάθε πρόγραμμα)
--   bucket library-images : φωτογραφίες κατηγοριών & προγραμμάτων (δημόσιες για ανάγνωση,
--                           ανεβάζει / σβήνει μόνο ο owner)
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
create table if not exists public.library_categories (
  gender        text not null,                 -- 'ΑΝΔΡΕΣ' | 'ΓΥΝΑΙΚΕΣ'
  top_category  text not null,                 -- 'ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ' | 'ΚΑΥΣΗΣ ΛΙΠΟΥΣ'
  sub_category  text not null default '',      -- '' = η κάρτα της κύριας κατηγορίας
  photo_url     text,
  description   text,
  results       text,
  updated_by    uuid default auth.uid() references auth.users(id) on delete set null,
  updated_at    timestamptz not null default now(),
  primary key (gender, top_category, sub_category)
);
alter table public.library_categories enable row level security;

drop policy if exists "library categories read" on public.library_categories;
create policy "library categories read" on public.library_categories for select to authenticated using (true);
drop policy if exists "library categories owner insert" on public.library_categories;
create policy "library categories owner insert" on public.library_categories for insert with check (public.ai_is_owner());
drop policy if exists "library categories owner update" on public.library_categories;
create policy "library categories owner update" on public.library_categories for update using (public.ai_is_owner()) with check (public.ai_is_owner());
drop policy if exists "library categories owner delete" on public.library_categories;
create policy "library categories owner delete" on public.library_categories for delete using (public.ai_is_owner());

-- Μεταφορά όσων υπάρχουν ήδη μέσα στα προγράμματα (η πρώτη φωτογραφία με τη σειρά της βιβλιοθήκης)
insert into public.library_categories (gender, top_category, sub_category, photo_url, updated_by)
select distinct on (gender, top_category) gender, top_category, '', top_category_photo_url, null
from public.template_programs
where coalesce(top_category_photo_url, '') <> '' and top_category in ('ΑΥΞΗΣΗ ΜΥΙΚΟΥ ΙΣΤΟΥ', 'ΚΑΥΣΗΣ ΛΙΠΟΥΣ')
order by gender, top_category, sort_order asc nulls last, created_at desc
on conflict (gender, top_category, sub_category) do nothing;

insert into public.library_categories (gender, top_category, sub_category, photo_url, description, results, updated_by)
select distinct on (gender, top_category, sub_category) gender, top_category, sub_category,
       nullif(sub_category_photo_url, ''), nullif(sub_category_description, ''), nullif(sub_category_results, ''), null
from public.template_programs
where coalesce(sub_category, '') <> '' and top_category = 'ΚΑΥΣΗΣ ΛΙΠΟΥΣ'
  and (coalesce(sub_category_photo_url, '') <> '' or coalesce(sub_category_description, '') <> '' or coalesce(sub_category_results, '') <> '')
order by gender, top_category, sub_category, sort_order asc nulls last, created_at desc
on conflict (gender, top_category, sub_category) do nothing;

-- Χώρος αποθήκευσης φωτογραφιών (έως 10MB/αρχείο, μόνο εικόνες)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('library-images', 'library-images', true, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "library images owner insert" on storage.objects;
create policy "library images owner insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'library-images' and public.ai_is_owner());
drop policy if exists "library images owner update" on storage.objects;
create policy "library images owner update" on storage.objects for update to authenticated
  using (bucket_id = 'library-images' and public.ai_is_owner()) with check (bucket_id = 'library-images' and public.ai_is_owner());
drop policy if exists "library images owner delete" on storage.objects;
create policy "library images owner delete" on storage.objects for delete to authenticated
  using (bucket_id = 'library-images' and public.ai_is_owner());
-- Η ανάγνωση γίνεται από το δημόσιο link του bucket (public = true).
