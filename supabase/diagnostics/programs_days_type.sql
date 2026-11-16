-- Τύπος στήλης (όχι προσωπικά δεδομένα)
select table_name, column_name, data_type from information_schema.columns where table_schema='public' and table_name in ('programs','template_programs') and column_name in ('days','data')
