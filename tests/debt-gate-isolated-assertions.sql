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

-- Behavioral checks with synthetic JWTs, no real user records.
DO $$
DECLARE
 w uuid:='00000000-0000-0000-0000-000000000001';
 u uuid:='00000000-0000-0000-0000-000000000002';
 exp timestamptz;
BEGIN
 INSERT INTO public.workspaces(id,nombre) VALUES(w,'CI only');
 INSERT INTO public.workspace_members(workspace_id,user_id) VALUES(w,u);
 PERFORM set_config('request.jwt.claim.sub',u::text,false);
 PERFORM set_config('request.jwt.claims','{"session_id":"not-a-uuid"}',false);
 IF public.debt_access_valid(w) IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Malformed session must fail closed'; END IF;
 PERFORM public.debt_lock(w); -- malformed session must not raise.
 BEGIN
   exp:=public.debt_unlock(w,'synthetic-password');
   RAISE EXCEPTION 'Malformed session unexpectedly unlocked';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM='Malformed session unexpectedly unlocked' THEN RAISE; END IF;
 END;
 PERFORM set_config('request.jwt.claims','{"session_id":"00000000-0000-0000-0000-000000000003"}',false);
 IF public.debt_access_valid(w) IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'No provisioned secret must deny access'; END IF;
 exp:=public.debt_unlock(w,'synthetic-password');
 IF exp IS NOT NULL THEN RAISE EXCEPTION 'Missing secret must not unlock'; END IF;
 IF public.debt_access_valid(w) IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Failed password must not grant access'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',false);
 IF public.debt_access_valid(w) IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Nonmember must be denied'; END IF;
END $$;
