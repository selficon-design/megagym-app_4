-- =====================================================================
-- ΦΟΡΜΑ — Κέντρο Κανόνων AI
--   ai_rule_versions : εκδόσεις του «βιβλίου κανόνων» (πρόχειρο / δημοσιευμένη / αρχείο)
--   ai_rule_cards    : οι κάρτες κάθε έκδοσης
--   ai_settings      : διακόπτες έγκρισης, δοκιμαστικοί πελάτες, όριο χρήσης
--   ai_proposals     : ό,τι πρότεινε το AI (με την έκδοση κανόνων που χρησιμοποίησε)
--   ai_usage         : μετρητής χρήσης (μόνο για την Edge Function)
-- Δεν αγγίζει κανέναν υπάρχοντα πίνακα. Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================

-- Βοηθητικό: είναι ο τρέχων χρήστης owner;
create or replace function public.ai_is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'owner');
$$;

-- 1) Εκδόσεις
create table if not exists public.ai_rule_versions (
  id           uuid primary key default gen_random_uuid(),
  app          text not null default 'forma',
  version_no   integer not null,
  status       text not null check (status in ('draft','published','archived')),
  note         text,
  created_by   uuid default auth.uid() references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  published_at timestamptz,
  unique (app, version_no)
);
-- Το πολύ ένα πρόχειρο και μία δημοσιευμένη έκδοση ανά εφαρμογή
create unique index if not exists ai_rule_versions_one_draft on public.ai_rule_versions (app) where status = 'draft';
create unique index if not exists ai_rule_versions_one_published on public.ai_rule_versions (app) where status = 'published';

-- 2) Κάρτες
create table if not exists public.ai_rule_cards (
  id          uuid primary key default gen_random_uuid(),
  version_id  uuid not null references public.ai_rule_versions(id) on delete cascade,
  kind        text not null check (kind in ('general','knowledge','button','forbidden','sensitive')),
  title       text not null,
  body        text not null default '',
  button_key  text,                      -- για kind = 'button': ποιο κουμπί της εφαρμογής ενεργοποιεί την κάρτα
  scope       text not null default 'all' check (scope in ('all','program','nutrition','chat')),
  active      boolean not null default true,
  sort        integer not null default 0,
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);
create index if not exists ai_rule_cards_version_idx on public.ai_rule_cards (version_id, sort);

-- 3) Ρυθμίσεις
create table if not exists public.ai_settings (
  app                 text primary key,
  approval_program    boolean not null default true,   -- true = ο owner εγκρίνει κάθε νέο πρόγραμμα
  approval_nutrition  boolean not null default true,
  test_customer_codes text[]  not null default '{}',    -- αυτοί οι πελάτες χρησιμοποιούν το ΠΡΟΧΕΙΡΟ
  daily_limit         integer not null default 3 check (daily_limit between 0 and 100),
  updated_at          timestamptz not null default now()
);
insert into public.ai_settings (app) values ('forma') on conflict (app) do nothing;

-- 4) Προτάσεις του AI
create table if not exists public.ai_proposals (
  id                 uuid primary key default gen_random_uuid(),
  app                text not null default 'forma',
  customer_code      text not null,
  user_id            uuid references auth.users(id) on delete cascade,
  button_key         text not null,
  status             text not null check (status in ('pending','approved','rejected','auto_applied')),
  version_id         uuid references public.ai_rule_versions(id) on delete set null,
  version_no         integer,
  used_draft         boolean not null default false,
  sensitive          boolean not null default false,
  sensitive_reason   text,
  request_note       text,
  message_to_client  text,
  reasoning          text,
  proposal           jsonb not null,
  applied_program_id text,
  decided_by         uuid references auth.users(id) on delete set null,
  decided_at         timestamptz,
  decision_note      text,
  created_at         timestamptz not null default now()
);
create index if not exists ai_proposals_status_idx on public.ai_proposals (app, status, created_at desc);
create index if not exists ai_proposals_customer_idx on public.ai_proposals (customer_code, created_at desc);

-- 5) Μετρητής χρήσης (χωρίς policies: μόνο η Edge Function με το κλειδί διακομιστή)
create table if not exists public.ai_usage (
  id         bigserial primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null,
  created_at timestamptz not null default now()
);
create index if not exists ai_usage_user_time_idx on public.ai_usage (user_id, created_at);

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
alter table public.ai_rule_versions enable row level security;
alter table public.ai_rule_cards    enable row level security;
alter table public.ai_settings      enable row level security;
alter table public.ai_proposals     enable row level security;
alter table public.ai_usage         enable row level security;

drop policy if exists "ai versions owner read" on public.ai_rule_versions;
create policy "ai versions owner read" on public.ai_rule_versions for select using (public.ai_is_owner());
drop policy if exists "ai versions owner note" on public.ai_rule_versions;
create policy "ai versions owner note" on public.ai_rule_versions for update using (public.ai_is_owner()) with check (public.ai_is_owner());
-- (δημιουργία / δημοσίευση / διαγραφή εκδόσεων ΜΟΝΟ μέσω των συναρτήσεων παρακάτω)

-- Κάρτες: ο owner τις διαβάζει όλες, αλλά αλλάζει ΜΟΝΟ κάρτες του προχείρου
drop policy if exists "ai cards owner read" on public.ai_rule_cards;
create policy "ai cards owner read" on public.ai_rule_cards for select using (public.ai_is_owner());
drop policy if exists "ai cards owner insert draft" on public.ai_rule_cards;
create policy "ai cards owner insert draft" on public.ai_rule_cards for insert with check (
  public.ai_is_owner() and exists (select 1 from public.ai_rule_versions v where v.id = version_id and v.status = 'draft'));
drop policy if exists "ai cards owner update draft" on public.ai_rule_cards;
create policy "ai cards owner update draft" on public.ai_rule_cards for update using (
  public.ai_is_owner() and exists (select 1 from public.ai_rule_versions v where v.id = version_id and v.status = 'draft'))
  with check (
  public.ai_is_owner() and exists (select 1 from public.ai_rule_versions v where v.id = version_id and v.status = 'draft'));
drop policy if exists "ai cards owner delete draft" on public.ai_rule_cards;
create policy "ai cards owner delete draft" on public.ai_rule_cards for delete using (
  public.ai_is_owner() and exists (select 1 from public.ai_rule_versions v where v.id = version_id and v.status = 'draft'));

drop policy if exists "ai settings owner read" on public.ai_settings;
create policy "ai settings owner read" on public.ai_settings for select using (public.ai_is_owner());
drop policy if exists "ai settings owner update" on public.ai_settings;
create policy "ai settings owner update" on public.ai_settings for update using (public.ai_is_owner()) with check (public.ai_is_owner());

-- Προτάσεις: ο πελάτης βλέπει τις δικές του, ο owner όλες και αποφασίζει
drop policy if exists "ai proposals own read" on public.ai_proposals;
create policy "ai proposals own read" on public.ai_proposals for select using (user_id = auth.uid() or public.ai_is_owner());
drop policy if exists "ai proposals owner decide" on public.ai_proposals;
create policy "ai proposals owner decide" on public.ai_proposals for update using (public.ai_is_owner()) with check (public.ai_is_owner());

-- ---------------------------------------------------------------------
-- Συναρτήσεις εκδόσεων (ατομικές: όλα ή τίποτα)
-- ---------------------------------------------------------------------

-- Νέο πρόχειρο: αντίγραφο της δημοσιευμένης έκδοσης (ή κενό αν δεν υπάρχει). Αν υπάρχει ήδη πρόχειρο, το επιστρέφει.
create or replace function public.ai_create_draft(p_app text default 'forma')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_draft uuid; v_pub uuid; v_no integer;
begin
  if not public.ai_is_owner() then raise exception 'Μόνο ο owner'; end if;
  select id into v_draft from ai_rule_versions where app = p_app and status = 'draft';
  if v_draft is not null then return v_draft; end if;
  select coalesce(max(version_no), 0) + 1 into v_no from ai_rule_versions where app = p_app;
  insert into ai_rule_versions (app, version_no, status) values (p_app, v_no, 'draft') returning id into v_draft;
  select id into v_pub from ai_rule_versions where app = p_app and status = 'published';
  if v_pub is not null then
    insert into ai_rule_cards (version_id, kind, title, body, button_key, scope, active, sort)
      select v_draft, kind, title, body, button_key, scope, active, sort from ai_rule_cards where version_id = v_pub;
  end if;
  return v_draft;
end $$;

-- Δημοσίευση πρόχειρου Ή επαναφορά παλιάς έκδοσης: η τρέχουσα δημοσιευμένη πάει στο αρχείο.
create or replace function public.ai_publish_version(p_version_id uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_app text; v_status text;
begin
  if not public.ai_is_owner() then raise exception 'Μόνο ο owner'; end if;
  select app, status into v_app, v_status from ai_rule_versions where id = p_version_id for update;
  if v_app is null then raise exception 'Δεν βρέθηκε η έκδοση'; end if;
  if v_status = 'published' then return; end if;
  update ai_rule_versions set status = 'archived' where app = v_app and status = 'published';
  update ai_rule_versions set status = 'published', published_at = now(),
         note = coalesce(nullif(trim(p_note), ''), note)
   where id = p_version_id;
end $$;

-- Απόρριψη του προχείρου (σβήνει το πρόχειρο και τις κάρτες του)
create or replace function public.ai_discard_draft(p_app text default 'forma')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.ai_is_owner() then raise exception 'Μόνο ο owner'; end if;
  -- οι προτάσεις που το χρησιμοποίησαν κρατούν τον αριθμό έκδοσης (version_no)
  delete from ai_rule_versions where app = p_app and status = 'draft';
end $$;

revoke all on function public.ai_create_draft(text) from public, anon;
revoke all on function public.ai_publish_version(uuid, text) from public, anon;
revoke all on function public.ai_discard_draft(text) from public, anon;
grant execute on function public.ai_create_draft(text) to authenticated;
grant execute on function public.ai_publish_version(uuid, text) to authenticated;
grant execute on function public.ai_discard_draft(text) to authenticated;

-- ---------------------------------------------------------------------
-- Αρχικό πρόχειρο με κάρτες-παραδείγματα (ΜΟΝΟ αν δεν υπάρχει καμία έκδοση).
-- Δεν δημοσιεύεται αυτόματα: ο owner το διαβάζει, το προσαρμόζει και πατά «Δημοσίευση».
-- ---------------------------------------------------------------------
do $$
declare v uuid;
begin
  if exists (select 1 from public.ai_rule_versions where app = 'forma') then return; end if;
  insert into public.ai_rule_versions (app, version_no, status, note, created_by)
    values ('forma', 1, 'draft', 'Αρχικές κάρτες-παραδείγματα', null) returning id into v;
  insert into public.ai_rule_cards (version_id, kind, title, body, button_key, scope, sort) values
  (v, 'general', 'Ποιος είσαι και πώς μιλάς',
   'Είσαι ο ψηφιακός προπονητής των προγραμμάτων TRANSFORMATION του MEGA GYM. Μιλάς ελληνικά, στον ενικό, φιλικά και με ενθουσιασμό, αλλά σύντομα και καθαρά. Ενθαρρύνεις τον πελάτη και του εξηγείς με απλά λόγια τι αλλάζει και γιατί.',
   null, 'all', 10),
  (v, 'button', 'Ανανέωση προγράμματος',
   'Ο πελάτης ζήτησε νέο πρόγραμμα. Κοίτα το τελευταίο του πρόγραμμα και το ημερολόγιο προπονήσεων.
- Κράτα την ίδια κατηγορία (Αύξηση Μυϊκού Ιστού ή Καύση Λίπους) και τον ίδιο αριθμό ημερών, εκτός αν ο πελάτης ζητήσει κάτι άλλο.
- Άλλαξε περίπου τις μισές ασκήσεις με άλλες της ίδιας μυϊκής ομάδας, για νέο ερέθισμα. Κράτα τις βασικές πολυαρθρικές.
- Αν προπονείται σταθερά (τουλάχιστον 3 φορές την εβδομάδα τις τελευταίες 4 εβδομάδες) με 3 σετ, ανέβασε σε 4 σετ. Αν προπονείται σπάνια, μην ανεβάσεις τον όγκο.
- Αν ο πελάτης γράψει τι θέλει (π.χ. «περισσότερο πόδια»), λάβε το υπόψη.
- Στο μήνυμα προς τον πελάτη εξήγησε σε 2-3 προτάσεις τι άλλαξε.',
   'program_renewal', 'program', 20),
  (v, 'forbidden', 'Τι δεν κάνεις ποτέ',
   '- Ποτέ ιατρικές διαγνώσεις ή συμβουλές για φάρμακα και συμπληρώματα.
- Ποτέ ασκήσεις που δεν υπάρχουν στη λίστα ασκήσεων της εφαρμογής.
- Ποτέ 6 σετ σε πελάτη που προπονείται λιγότερο από 6 μήνες.
- Ποτέ θερμίδες κάτω από -500kcal.',
   null, 'all', 30),
  (v, 'sensitive', 'Πότε χρειάζεται άνθρωπος',
   'Σήμανε την περίπτωση ως ευαίσθητη (να την ελέγξει άνθρωπος πριν φτάσει στον πελάτη) αν ο πελάτης αναφέρει: πόνο, τραυματισμό, χειρουργείο, εγκυμοσύνη, πρόβλημα υγείας (καρδιά, πίεση, διαβήτης κ.λπ.), φαρμακευτική αγωγή, ή αν είναι ανήλικος. Σήμανε ευαίσθητη και κάθε περίπτωση που δεν είσαι σίγουρος.',
   null, 'all', 40),
  (v, 'knowledge', 'UNTIL FAILURE',
   'UNTIL FAILURE 0 = μέχρι τη μυϊκή αποτυχία. -1, -2, -3 = σταματάς 1, 2 ή 3 επαναλήψεις πριν την αποτυχία. Οι αρχάριοι ξεκινούν από -3 ή -2. Στόχος είναι σταδιακά το 0. Ποτέ +1, +2, +3 (με βοήθεια παρτενέρ). «Καλύτερα UNDER παρά OVER».',
   null, 'program', 50);
end $$;
