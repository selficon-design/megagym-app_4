-- Στήλες και κανόνες του πίνακα workout_logs (ΧΩΡΙΣ στοιχεία πελατών).
select 'col' as k, column_name as a, data_type || ' ' || is_nullable as b, coalesce(column_default,'') as c
from information_schema.columns where table_schema = 'public' and table_name = 'workout_logs'
union all
select 'check', conname, left(pg_get_constraintdef(oid), 200), '' from pg_constraint where conrelid = 'public.workout_logs'::regclass
union all
select 'policy', policyname, cmd, left(coalesce(with_check, qual, ''), 200) from pg_policies where schemaname='public' and tablename='workout_logs'
