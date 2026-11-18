-- Assertions executed only in ephemeral PostgreSQL CI after draft migration.
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_policies
 WHERE schemaname='public' AND tablename='debts'
 AND policyname='debts_require_extra_unlock'
 AND permissive='RESTRICTIVE' AND cmd='ALL'
 AND 'authenticated'=ANY(roles);
 IF n<>1 THEN RAISE EXCEPTION 'Missing restrictive debt gate RLS'; END IF;
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace
 WHERE ns.nspname='public' AND p.proname IN ('debt_unlock','debt_lock','debt_access_valid')
 AND p.prosecdef;
 IF n<>3 THEN RAISE EXCEPTION 'Missing SECURITY DEFINER RPC'; END IF;
 SELECT count(*) INTO n FROM information_schema.role_routine_grants
 WHERE routine_schema='public' AND routine_name IN ('debt_unlock','debt_lock','debt_access_valid')
 AND grantee='PUBLIC';
 IF n<>0 THEN RAISE EXCEPTION 'Public execute grant detected'; END IF;
 IF (SELECT public.debt_access_valid('00000000-0000-0000-0000-000000000001'::uuid)) IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Anonymous access must fail closed'; END IF;
END $$;
