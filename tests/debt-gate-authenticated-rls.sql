-- CL Nexus disposable PostgreSQL only: exercise RLS as authenticated, not superuser.
-- All IDs and data are synthetic. Never execute on production.
GRANT USAGE ON SCHEMA public,auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid(),auth.jwt(),public.is_workspace_member(uuid) TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.debts TO authenticated;
INSERT INTO public.debts(id,workspace_id,data,created_by,updated_by)
VALUES('ci-debt-1','00000000-0000-0000-0000-000000000001','{"synthetic":true}',
'00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
SELECT set_config('request.jwt.claims','{"session_id":"00000000-0000-0000-0000-000000000007"}',false);
DO $$
BEGIN
 IF (SELECT count(*) FROM public.debts)<>0 THEN RAISE EXCEPTION 'RLS exposed debt before unlock'; END IF;
END $$;
SELECT public.debt_unlock('00000000-0000-0000-0000-000000000001','synthetic-password');
DO $$
BEGIN
 IF (SELECT count(*) FROM public.debts)<>1 THEN RAISE EXCEPTION 'RLS blocked valid unlocked member'; END IF;
END $$;
SELECT public.debt_lock('00000000-0000-0000-0000-000000000001');
DO $$
BEGIN
 IF (SELECT count(*) FROM public.debts)<>0 THEN RAISE EXCEPTION 'RLS exposed debt after lock'; END IF;
END $$;
RESET ROLE;
