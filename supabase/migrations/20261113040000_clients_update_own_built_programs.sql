-- =====================================================================
-- ΦΟΡΜΑ — Ο αθλούμενος μπορεί να αλλάζει ΜΟΝΟ τα προγράμματα που έφτιαξε ο ίδιος
-- («Φτιάχνω δικό μου πρόγραμμα» → days.fromClientBuilder = true), π.χ. όταν δέχεται
-- τις προτάσεις του «Ελέγχου προγράμματος». Τα προγράμματα του προπονητή δεν αλλάζουν.
-- Μπορεί να ξανατρέξει χωρίς πρόβλημα.
-- =====================================================================
drop policy if exists "clients update own built programs" on public.programs;
create policy "clients update own built programs" on public.programs for update
  using (
    coalesce(days->>'fromClientBuilder','') = 'true'
    and exists (select 1 from public.customers c where c.code = programs.customer_code and c.claimed_by = auth.uid())
  )
  with check (
    coalesce(days->>'fromClientBuilder','') = 'true'
    and exists (select 1 from public.customers c where c.code = programs.customer_code and c.claimed_by = auth.uid())
  );
