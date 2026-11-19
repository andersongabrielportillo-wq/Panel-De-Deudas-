-- Disposable PostgreSQL 17 only: full schema snapshot parity and access checks.
DO $check$
DECLARE n integer; rec record;
BEGIN
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace
 WHERE c.relkind='r' AND ((ns.nspname='public' AND c.relname LIKE 'inv_%') OR ns.nspname='inv_private');
 IF n<>24 THEN RAISE EXCEPTION 'Expected 24 CL Nexus tables, got %',n; END IF;
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace
 WHERE c.relkind='r' AND c.relrowsecurity AND ((ns.nspname='public' AND c.relname LIKE 'inv_%') OR ns.nspname='inv_private');
 IF n<>24 THEN RAISE EXCEPTION 'RLS missing in CL Nexus tables: %',n; END IF;
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
 WHERE (ns.nspname='public' AND p.proname LIKE 'inv_%') OR ns.nspname='inv_private';
 IF n<>39 THEN RAISE EXCEPTION 'Expected 39 CL Nexus functions, got %',n; END IF;
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace
 WHERE c.relkind='v' AND ns.nspname='public' AND c.relname LIKE 'inv_%'
 AND 'security_invoker=true'=ANY(COALESCE(c.reloptions,ARRAY[]::text[]));
 IF n<>3 THEN RAISE EXCEPTION 'Reports lack security_invoker: %',n; END IF;
 SELECT count(*) INTO n FROM pg_policies
 WHERE (schemaname='public' AND tablename LIKE 'inv_%') OR schemaname='inv_private';
 IF n<>13 THEN RAISE EXCEPTION 'Expected 13 RLS policies, got %',n; END IF;
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace
 WHERE c.relkind='i' AND ((ns.nspname='public' AND c.relname LIKE 'inv_%') OR ns.nspname='inv_private');
 IF n<>47 THEN RAISE EXCEPTION 'Index count mismatch: %',n; END IF;
 IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
 WHERE ((ns.nspname='public' AND p.proname LIKE 'inv_%') OR ns.nspname='inv_private')
 AND has_function_privilege('anon',p.oid,'EXECUTE')) THEN
 RAISE EXCEPTION 'Anonymous user can execute inventory RPC'; END IF;
 IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace
 WHERE c.relkind='r' AND ((ns.nspname='public' AND c.relname LIKE 'inv_%') OR ns.nspname='inv_private')
 AND (has_table_privilege('authenticated',c.oid,'INSERT')
   OR has_table_privilege('authenticated',c.oid,'UPDATE')
   OR has_table_privilege('authenticated',c.oid,'DELETE'))) THEN
 RAISE EXCEPTION 'Authenticated role has direct inventory write privilege'; END IF;
 FOR rec IN SELECT ns.nspname sc,c.relname nm FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace
 WHERE c.relkind='r' AND ((ns.nspname='public' AND c.relname LIKE 'inv_%') OR ns.nspname='inv_private')
 LOOP
 EXECUTE format('SELECT count(*) FROM %I.%I',rec.sc,rec.nm) INTO n;
 IF n<>0 THEN RAISE EXCEPTION 'Schema-only snapshot unexpectedly seeded %.%',rec.sc,rec.nm; END IF;
 END LOOP;
END $check$;
DO $preservation$
BEGIN
 IF (SELECT count(*) FROM public.workspaces)<>1 THEN RAISE EXCEPTION 'Inventario altered workspaces'; END IF;
 IF (SELECT count(*) FROM public.workspace_members)<>3 THEN RAISE EXCEPTION 'Inventario altered workspace members'; END IF;
 IF (SELECT count(*) FROM public.debts WHERE id='__shared_state__'
  AND data='{"v":2,"rev":7,"debts":[{"id":"fake-local-fixture"}],"tx":[]}'::jsonb)<>1
 THEN RAISE EXCEPTION 'Inventory schema migration changed synthetic shared Deudas state'; END IF;
 IF (SELECT count(*) FROM public.transactions)<>0 THEN RAISE EXCEPTION 'Inventario inserted transaction rows'; END IF;
 IF (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename IN ('debts','transactions'))<>8
 THEN RAISE EXCEPTION 'Inventory schema changed Deudas or transactions policies'; END IF;
END $preservation$;
SELECT 'PASS: CL Nexus schema installed with no data, 24 RLS tables, 39 RPCs, 3 safe views, 47 indexes' AS result;
