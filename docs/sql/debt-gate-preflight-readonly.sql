-- Auditoría previa SOLO LECTURA. Ejecutar en proyecto destino antes de preparar la migración.
-- No devuelve credenciales, datos personales ni filas de deudas.
SELECT 'debt_table' AS check_name, to_jsonb(x) AS result
FROM (SELECT c.oid::regclass::text AS table_name, c.relrowsecurity AS rls_enabled,
 c.relforcerowsecurity AS rls_forced
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname='debts' AND c.relkind IN ('r','p')) x;
SELECT 'debt_policies' AS check_name, to_jsonb(x) AS result
FROM (SELECT policyname, permissive, roles, cmd, qual, with_check
 FROM pg_policies WHERE schemaname='public' AND tablename='debts') x;
SELECT 'debt_grants' AS check_name, to_jsonb(x) AS result
FROM (SELECT grantee, privilege_type FROM information_schema.role_table_grants
 WHERE table_schema='public' AND table_name='debts' AND grantee IN ('anon','authenticated')) x;
SELECT 'debt_columns' AS check_name, to_jsonb(x) AS result
FROM (SELECT column_name,data_type,is_nullable FROM information_schema.columns
 WHERE table_schema='public' AND table_name='debts') x;
SELECT 'workspace_membership_shape' AS check_name, to_jsonb(x) AS result
FROM (SELECT column_name,data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='workspace_members') x;
SELECT 'crypto_extension' AS check_name, to_jsonb(x) AS result
FROM (SELECT extname,n.nspname AS installed_schema FROM pg_extension e
 JOIN pg_namespace n ON n.oid=e.extnamespace WHERE extname='pgcrypto') x;
SELECT 'realtime_publication' AS check_name, to_jsonb(x) AS result
FROM (SELECT pubname,schemaname,tablename FROM pg_publication_tables
 WHERE schemaname='public' AND tablename='debts') x;
SELECT 'debt_gate_functions' AS check_name, to_jsonb(x) AS result
FROM (SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS arguments,
 p.prosecdef AS security_definer
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('debt_access_valid','debt_unlock','debt_lock')) x;
