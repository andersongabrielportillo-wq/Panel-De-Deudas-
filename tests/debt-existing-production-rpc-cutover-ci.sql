-- Executed only in disposable GitHub Actions PostgreSQL 17; all identities/data are synthetic.
\i tests/fixtures/deudas_schema_sintetico_SOLO_CI.sql

-- Dependency stubs are synthetic and intentionally incapable of revealing real secrets.
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE TABLE auth.sessions(id uuid PRIMARY KEY,user_id uuid NOT NULL REFERENCES auth.users(id));
CREATE SCHEMA app_private;
CREATE TABLE app_private.debt_unlocks(user_id uuid,session_id uuid,expires_at timestamptz);
CREATE TABLE app_private.debt_attempts(user_id uuid,failed_count integer);
CREATE SCHEMA vault;
CREATE TABLE vault.secrets(name text PRIMARY KEY);
CREATE VIEW vault.decrypted_secrets AS SELECT name,'fixture-secret-not-real'::text AS decrypted_secret FROM vault.secrets;
INSERT INTO vault.secrets(name) VALUES('deudas_access_password');
\if :{?test_vault_missing}
 DELETE FROM vault.secrets WHERE name='deudas_access_password';
\endif
\if :{?test_vault_undecryptable}
 CREATE OR REPLACE VIEW vault.decrypted_secrets AS
 SELECT name,NULL::text AS decrypted_secret FROM vault.secrets;
\endif
INSERT INTO auth.users(id) VALUES('00000000-0000-0000-0000-000000000002'),('00000000-0000-0000-0000-000000000003');
INSERT INTO auth.sessions(id,user_id) VALUES('00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000002');


CREATE TABLE public.transactions (
 id text PRIMARY KEY,
 workspace_id uuid NOT NULL REFERENCES public.workspaces(id),
 data jsonb NOT NULL,
 created_by uuid,
 updated_by uuid
);
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY members_read_transactions ON public.transactions FOR SELECT TO authenticated USING(public.is_workspace_member(workspace_id));
CREATE POLICY members_insert_transactions ON public.transactions FOR INSERT TO authenticated WITH CHECK(public.is_workspace_member(workspace_id) AND created_by=auth.uid() AND updated_by=auth.uid());
CREATE POLICY members_update_transactions ON public.transactions FOR UPDATE TO authenticated USING(public.is_workspace_member(workspace_id)) WITH CHECK(public.is_workspace_member(workspace_id) AND updated_by=auth.uid());
CREATE POLICY members_delete_transactions ON public.transactions FOR DELETE TO authenticated USING(public.is_workspace_member(workspace_id));
GRANT USAGE ON SCHEMA auth, public TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.debts,public.transactions TO authenticated;

-- Mock the EXISTING production signature, not the older draft RPC signature.
-- Deliberately replace secret checking with a fixture-only on/off setting.
CREATE FUNCTION public.has_debts_unlock() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT current_setting('test_gate.unlocked',true)='on'
$$;
CREATE FUNCTION public.unlock_debts(p_password text) RETURNS boolean LANGUAGE sql AS $$ SELECT false $$;
CREATE FUNCTION public.lock_debts() RETURNS void LANGUAGE plpgsql AS 'BEGIN RETURN; END;';
-- Match production RPC EXECUTE permissions; no unrestricted PUBLIC access.
REVOKE ALL ON FUNCTION public.has_debts_unlock() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.unlock_debts(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.lock_debts() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.has_debts_unlock() TO authenticated;
GRANT EXECUTE ON FUNCTION public.unlock_debts(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lock_debts() TO authenticated;

INSERT INTO public.workspaces(id,nombre) VALUES ('00000000-0000-0000-0000-000000000001','synthetic');
INSERT INTO public.workspace_members(workspace_id,user_id) VALUES('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002');
INSERT INTO public.workspace_members(workspace_id,user_id) VALUES('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003');
INSERT INTO public.debts(id,workspace_id,data,created_by,updated_by) VALUES('synthetic-1','00000000-0000-0000-0000-000000000001','{}','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
INSERT INTO public.transactions(id,workspace_id,data,created_by,updated_by) VALUES('synthetic-1','00000000-0000-0000-0000-000000000001','{}','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');

-- Exact SQL intended for a future coordinated cutover; run only against CI fixture.
\i sql/deudas_gate_existing_production_rpc_PREPARADO_NO_EJECUTAR.sql

DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public'
 AND tablename IN ('debts','transactions') AND policyname LIKE 'debt_unlock_required_%'
 AND permissive='RESTRICTIVE' AND cmd='ALL' AND roles='{authenticated}';
 IF n<>2 THEN RAISE EXCEPTION 'Expected 2 RESTRICTIVE policies, found %',n; END IF;
END $$;

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
SELECT set_config('test_gate.unlocked','off',false);
DO $$
DECLARE n integer; rejected boolean:=false;
BEGIN
 SELECT count(*) INTO n FROM public.debts;
 IF n<>0 THEN RAISE EXCEPTION 'Locked user can read debts'; END IF;
 SELECT count(*) INTO n FROM public.transactions;
 IF n<>0 THEN RAISE EXCEPTION 'Locked user can read transactions'; END IF;
 BEGIN
 INSERT INTO public.debts(id,workspace_id,data,created_by,updated_by)
 VALUES('blocked','00000000-0000-0000-0000-000000000001','{}','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
 EXCEPTION WHEN insufficient_privilege THEN rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'Locked INSERT debts allowed'; END IF;
 rejected:=false;
 BEGIN
 INSERT INTO public.transactions(id,workspace_id,data,created_by,updated_by)
 VALUES('blocked','00000000-0000-0000-0000-000000000001','{}','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
 EXCEPTION WHEN insufficient_privilege THEN rejected:=true;
 END;
 IF NOT rejected THEN RAISE EXCEPTION 'Locked INSERT transactions allowed'; END IF;
 UPDATE public.debts SET data='{"changed":true}' WHERE id='synthetic-1';
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>0 THEN RAISE EXCEPTION 'Locked UPDATE debts affected % rows',n; END IF;
 DELETE FROM public.transactions WHERE id='synthetic-1';
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>0 THEN RAISE EXCEPTION 'Locked DELETE transactions affected % rows',n; END IF;
END $$;

SELECT set_config('test_gate.unlocked','on',false);
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM public.debts;
 IF n<>1 THEN RAISE EXCEPTION 'Unlocked SELECT debts failed'; END IF;
 SELECT count(*) INTO n FROM public.transactions;
 IF n<>1 THEN RAISE EXCEPTION 'Unlocked SELECT transactions failed'; END IF;
 UPDATE public.debts SET data='{"updated":true}' WHERE id='synthetic-1';
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'Unlocked UPDATE failed'; END IF;
 INSERT INTO public.transactions(id,workspace_id,data,created_by,updated_by)
 VALUES('temporary','00000000-0000-0000-0000-000000000001','{}','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
 DELETE FROM public.transactions WHERE id='temporary';
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>1 THEN RAISE EXCEPTION 'Unlocked DELETE failed'; END IF;
END $$;

SELECT set_config('test_gate.unlocked','off',false);
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM public.debts;
 IF n<>0 THEN RAISE EXCEPTION 'Revoked gate still permits read'; END IF;
 UPDATE public.debts SET data='{}' WHERE id='synthetic-1';
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>0 THEN RAISE EXCEPTION 'Revoked gate still permits write'; END IF;
END $$;
RESET ROLE;

-- Check policy-only rollback (NOT a database/data restore) against the disposable fixture.
\i sql/deudas_gate_existing_production_rpc_ROLLBACK_NO_EJECUTAR.sql
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public'
 AND tablename IN ('debts','transactions') AND policyname LIKE 'debt_unlock_required_%';
 IF n<>0 THEN RAISE EXCEPTION 'Gate rollback left % policies',n; END IF;
 SELECT count(*) INTO n FROM pg_policies WHERE schemaname='public'
 AND tablename IN ('debts','transactions') AND permissive='PERMISSIVE';
 IF n<>8 THEN RAISE EXCEPTION 'Rollback modified preexisting policies: %',n; END IF;
END $$;
