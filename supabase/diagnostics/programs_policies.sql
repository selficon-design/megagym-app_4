-- Πολιτικές πρόσβασης του πίνακα programs (μόνο κανόνες, όχι δεδομένα)
select policyname, cmd, roles::text, left(coalesce(qual,''),220) as using_expr, left(coalesce(with_check,''),220) as check_expr
from pg_policies where schemaname='public' and tablename='programs' order by cmd, policyname
