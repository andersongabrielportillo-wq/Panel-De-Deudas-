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
-- Seed in a separate SQL statement so STABLE membership functions see committed fixture rows.
INSERT INTO public.workspaces(id,nombre) VALUES('00000000-0000-0000-0000-000000000001','CI only');
INSERT INTO public.workspace_members(workspace_id,user_id) VALUES('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002');
DO $$
DECLARE
 w uuid:='00000000-0000-0000-0000-000000000001';
 u uuid:='00000000-0000-0000-0000-000000000002';
 exp timestamptz;
BEGIN
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
 RAISE NOTICE 'diagnostic uid=%, session=%, member=%',auth.uid(),auth.jwt()->>'session_id',public.is_workspace_member(w);
 exp:=public.debt_unlock(w,'synthetic-password');
 IF exp IS NOT NULL THEN RAISE EXCEPTION 'Missing secret must not unlock'; END IF;
 IF public.debt_access_valid(w) IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Failed password must not grant access'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',false);
 IF public.debt_access_valid(w) IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Nonmember must be denied'; END IF;
END $$;

-- Synthetic password exists ONLY in disposable CI; never provision production here.
INSERT INTO debt_gate_secure.secrets(workspace_id,password_hash)
VALUES('00000000-0000-0000-0000-000000000001',extensions.crypt('synthetic-password',extensions.gen_salt('bf')));

DO $$
DECLARE
 w uuid:='00000000-0000-0000-0000-000000000001';
 u uuid:='00000000-0000-0000-0000-000000000002';
 s1 text:='00000000-0000-0000-0000-000000000003';
 s2 text:='00000000-0000-0000-0000-000000000005';
 exp timestamptz;
BEGIN
 PERFORM set_config('request.jwt.claim.sub',u::text,false);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('session_id',s1)::text,false);
 IF public.debt_access_valid(w) THEN RAISE EXCEPTION 'Access before unlock'; END IF;
 exp:=public.debt_unlock(w,'synthetic-password');
 IF exp IS NULL OR exp<=now() THEN RAISE EXCEPTION 'Valid password failed'; END IF;
 IF NOT public.debt_access_valid(w) THEN RAISE EXCEPTION 'Unlock not recognized'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('session_id',s2)::text,false);
 IF public.debt_access_valid(w) THEN RAISE EXCEPTION 'Session isolation failed'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('session_id',s1)::text,false);
 PERFORM public.debt_lock(w);
 IF public.debt_access_valid(w) THEN RAISE EXCEPTION 'Lock failed'; END IF;
 exp:=public.debt_unlock(w,'synthetic-password');
 IF exp IS NULL THEN RAISE EXCEPTION 'Reunlock failed'; END IF;
 UPDATE debt_gate_secure.unlocks SET expires_at=now()-interval '1 minute'
 WHERE workspace_id=w AND user_id=u AND session_id=s1::uuid;
 IF public.debt_access_valid(w) THEN RAISE EXCEPTION 'Expired unlock accepted'; END IF;
 UPDATE debt_gate_secure.secrets SET revision=revision+1 WHERE workspace_id=w;
 IF public.debt_access_valid(w) THEN RAISE EXCEPTION 'Revision rotation did not revoke'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',false);
 IF public.debt_access_valid(w) THEN RAISE EXCEPTION 'Nonmember with valid session accepted'; END IF;
END $$;
