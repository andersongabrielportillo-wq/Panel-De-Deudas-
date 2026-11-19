-- CL Nexus schema-only completeness check; safe in LAB, a restored clone or production.
-- This does NOT install any schema or copy data.
-- Compare counts with validated LAB source: 21 public tables + 3 private tables,
-- 39 functions (37 public inv_* + 2 inv_private), 3 views, 47 indexes,
-- 3 sequences, 6 non-internal triggers, 48 foreign keys and 13 policies.
BEGIN READ ONLY;
WITH objects AS (
 SELECT
   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE c.relkind='r' AND n.nspname='public' AND c.relname LIKE 'inv_%') AS public_tables,
   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE c.relkind='r' AND n.nspname='inv_private') AS private_tables,
   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE c.relkind='v' AND n.nspname='public' AND c.relname LIKE 'inv_%') AS public_views,
   (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname LIKE 'inv_%') AS public_functions,
   (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='inv_private') AS private_functions,
   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE c.relkind='i' AND ((n.nspname='public' AND c.relname LIKE 'inv_%') OR n.nspname='inv_private')) AS indexes,
   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE c.relkind='S' AND n.nspname='public' AND c.relname LIKE 'inv_%') AS sequences,
   (SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE NOT t.tgisinternal AND ((n.nspname='public' AND c.relname LIKE 'inv_%') OR n.nspname='inv_private')) AS triggers,
   (SELECT count(*) FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE k.contype='f' AND ((n.nspname='public' AND c.relname LIKE 'inv_%') OR n.nspname='inv_private')) AS foreign_keys,
   (SELECT count(*) FROM pg_policies WHERE (schemaname='public' AND tablename LIKE 'inv_%') OR schemaname='inv_private') AS policies
)
SELECT *, (public_tables=21 AND private_tables=3 AND public_views=3 AND public_functions=37
 AND private_functions=2 AND indexes=47 AND sequences=3 AND triggers=6
 AND foreign_keys=48 AND policies=13) AS matches_lab_schema
FROM objects;
ROLLBACK;
-- An exact count match is necessary, not sufficient: compare definitions, permissions,
-- RLS and all column/constraint details before a production migration.
