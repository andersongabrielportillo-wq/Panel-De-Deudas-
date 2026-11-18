-- CL Nexus: DRAFT ONLY. DO NOT RUN ON PRODUCTION.
-- Staging rehearsal must use an isolated database/project with production-like workspace_members.
-- The migration is deliberately fail-closed; it DOES NOT install a password hash.
-- Deploy matching frontend and seed a bcrypt hash through a secure, separately approved channel.
BEGIN;
CREATE SCHEMA IF NOT EXISTS debt_gate_secure;
REVOKE ALL ON SCHEMA debt_gate_secure FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS debt_gate_secure.secrets(
 workspace_id uuid PRIMARY KEY REFERENCES public.workspaces(id),
 password_hash text NOT NULL,
 revision bigint NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS debt_gate_secure.unlocks(
 workspace_id uuid NOT NULL REFERENCES public.workspaces(id),
 user_id uuid NOT NULL,
 session_id uuid NOT NULL,
 revision bigint NOT NULL,
 expires_at timestamptz NOT NULL,
 PRIMARY KEY(workspace_id,user_id,session_id)
);
CREATE TABLE IF NOT EXISTS debt_gate_secure.attempts(
 workspace_id uuid NOT NULL REFERENCES public.workspaces(id),
 user_id uuid NOT NULL,
 failed_count integer NOT NULL DEFAULT 0,
 blocked_until timestamptz,
 PRIMARY KEY(workspace_id,user_id)
);
REVOKE ALL ON ALL TABLES IN SCHEMA debt_gate_secure FROM PUBLIC, anon, authenticated;
CREATE OR REPLACE FUNCTION public.debt_access_valid(p_workspace_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT auth.uid() IS NOT NULL
 AND public.is_workspace_member(p_workspace_id)
 AND COALESCE((auth.jwt()->>'session_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}
 AND EXISTS (
  SELECT 1 FROM debt_gate_secure.unlocks u
  JOIN debt_gate_secure.secrets s ON s.workspace_id=u.workspace_id AND s.revision=u.revision
  WHERE u.workspace_id=p_workspace_id AND u.user_id=auth.uid()
    AND u.session_id=(CASE WHEN COALESCE((auth.jwt()->>'session_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',false) THEN (auth.jwt()->>'session_id')::uuid ELSE NULL END)
    AND u.expires_at>now()
 );
$$;
CREATE OR REPLACE FUNCTION public.debt_lock(p_workspace_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
BEGIN
 DELETE FROM debt_gate_secure.unlocks
 WHERE workspace_id=p_workspace_id AND user_id=auth.uid()
 AND session_id=(CASE WHEN COALESCE((auth.jwt()->>'session_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',false) THEN (auth.jwt()->>'session_id')::uuid ELSE NULL END);
END;
$$;
CREATE OR REPLACE FUNCTION public.debt_unlock(p_workspace_id uuid,p_password text)
RETURNS timestamptz LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE
 v_uid uuid:=auth.uid();
 v_session uuid:=(CASE WHEN COALESCE((auth.jwt()->>'session_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',false) THEN (auth.jwt()->>'session_id')::uuid ELSE NULL END);
 v_hash text;v_rev bigint;v_fail integer;v_block timestamptz;v_exp timestamptz;
BEGIN
 IF v_uid IS NULL OR v_session IS NULL OR NOT public.is_workspace_member(p_workspace_id)
 THEN RAISE EXCEPTION 'Acceso denegado'; END IF;
 IF p_password IS NULL OR length(p_password)<8 OR octet_length(p_password)>72
 THEN RAISE EXCEPTION 'Credencial inválida'; END IF;
 INSERT INTO debt_gate_secure.attempts(workspace_id,user_id)
 VALUES(p_workspace_id,v_uid) ON CONFLICT DO NOTHING;
 SELECT failed_count,blocked_until INTO v_fail,v_block
 FROM debt_gate_secure.attempts
 WHERE workspace_id=p_workspace_id AND user_id=v_uid FOR UPDATE;
 IF v_block>now() THEN RAISE EXCEPTION 'Acceso temporalmente bloqueado'; END IF;
 SELECT password_hash,revision INTO v_hash,v_rev
 FROM debt_gate_secure.secrets WHERE workspace_id=p_workspace_id;
 IF v_hash IS NULL OR extensions.crypt(p_password,v_hash) IS DISTINCT FROM v_hash THEN
  UPDATE debt_gate_secure.attempts
  SET failed_count=CASE WHEN failed_count>=4 THEN 0 ELSE failed_count+1 END,
  blocked_until=CASE WHEN failed_count>=4 THEN now()+interval '15 minutes' ELSE NULL END
  WHERE workspace_id=p_workspace_id AND user_id=v_uid;
  RETURN NULL;
 END IF;
 UPDATE debt_gate_secure.attempts SET failed_count=0,blocked_until=NULL
 WHERE workspace_id=p_workspace_id AND user_id=v_uid;
 v_exp:=now()+interval '20 minutes';
 INSERT INTO debt_gate_secure.unlocks(workspace_id,user_id,session_id,revision,expires_at)
 VALUES(p_workspace_id,v_uid,v_session,v_rev,v_exp)
 ON CONFLICT(workspace_id,user_id,session_id)
 DO UPDATE SET revision=EXCLUDED.revision,expires_at=EXCLUDED.expires_at;
 RETURN v_exp;
END;
$$;
REVOKE ALL ON FUNCTION public.debt_access_valid(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.debt_lock(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.debt_unlock(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.debt_access_valid(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debt_lock(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debt_unlock(uuid,text) TO authenticated;
-- Keep existing PERMISSIVE membership policies; this policy adds an obligatory AND.
CREATE POLICY debts_require_extra_unlock ON public.debts
 AS RESTRICTIVE FOR ALL TO authenticated
 USING (public.debt_access_valid(workspace_id))
 WITH CHECK (public.debt_access_valid(workspace_id));
-- WARNING: RLS becomes fail-closed until secret is provisioned and frontend deployed.
-- Explicit production approval and a coordinated cutover are mandatory.
COMMIT;
,false)
 AND EXISTS (
  SELECT 1 FROM debt_gate_secure.unlocks u
  JOIN debt_gate_secure.secrets s ON s.workspace_id=u.workspace_id AND s.revision=u.revision
  WHERE u.workspace_id=p_workspace_id AND u.user_id=auth.uid()
    AND u.session_id=(CASE WHEN COALESCE((auth.jwt()->>'session_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',false) THEN (auth.jwt()->>'session_id')::uuid ELSE NULL END)
    AND u.expires_at>now()
 );
$$;
CREATE OR REPLACE FUNCTION public.debt_lock(p_workspace_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
BEGIN
 DELETE FROM debt_gate_secure.unlocks
 WHERE workspace_id=p_workspace_id AND user_id=auth.uid()
 AND session_id=(CASE WHEN COALESCE((auth.jwt()->>'session_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',false) THEN (auth.jwt()->>'session_id')::uuid ELSE NULL END);
END;
$$;
CREATE OR REPLACE FUNCTION public.debt_unlock(p_workspace_id uuid,p_password text)
RETURNS timestamptz LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE
 v_uid uuid:=auth.uid();
 v_session uuid:=(CASE WHEN COALESCE((auth.jwt()->>'session_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',false) THEN (auth.jwt()->>'session_id')::uuid ELSE NULL END);
 v_hash text;v_rev bigint;v_fail integer;v_block timestamptz;v_exp timestamptz;
BEGIN
 IF v_uid IS NULL OR v_session IS NULL OR NOT public.is_workspace_member(p_workspace_id)
 THEN RAISE EXCEPTION 'Acceso denegado'; END IF;
 IF p_password IS NULL OR length(p_password)<8 OR octet_length(p_password)>72
 THEN RAISE EXCEPTION 'Credencial inválida'; END IF;
 INSERT INTO debt_gate_secure.attempts(workspace_id,user_id)
 VALUES(p_workspace_id,v_uid) ON CONFLICT DO NOTHING;
 SELECT failed_count,blocked_until INTO v_fail,v_block
 FROM debt_gate_secure.attempts
 WHERE workspace_id=p_workspace_id AND user_id=v_uid FOR UPDATE;
 IF v_block>now() THEN RAISE EXCEPTION 'Acceso temporalmente bloqueado'; END IF;
 SELECT password_hash,revision INTO v_hash,v_rev
 FROM debt_gate_secure.secrets WHERE workspace_id=p_workspace_id;
 IF v_hash IS NULL OR extensions.crypt(p_password,v_hash) IS DISTINCT FROM v_hash THEN
  UPDATE debt_gate_secure.attempts
  SET failed_count=CASE WHEN failed_count>=4 THEN 0 ELSE failed_count+1 END,
  blocked_until=CASE WHEN failed_count>=4 THEN now()+interval '15 minutes' ELSE NULL END
  WHERE workspace_id=p_workspace_id AND user_id=v_uid;
  RETURN NULL;
 END IF;
 UPDATE debt_gate_secure.attempts SET failed_count=0,blocked_until=NULL
 WHERE workspace_id=p_workspace_id AND user_id=v_uid;
 v_exp:=now()+interval '20 minutes';
 INSERT INTO debt_gate_secure.unlocks(workspace_id,user_id,session_id,revision,expires_at)
 VALUES(p_workspace_id,v_uid,v_session,v_rev,v_exp)
 ON CONFLICT(workspace_id,user_id,session_id)
 DO UPDATE SET revision=EXCLUDED.revision,expires_at=EXCLUDED.expires_at;
 RETURN v_exp;
END;
$$;
REVOKE ALL ON FUNCTION public.debt_access_valid(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.debt_lock(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.debt_unlock(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.debt_access_valid(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debt_lock(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debt_unlock(uuid,text) TO authenticated;
-- Keep existing PERMISSIVE membership policies; this policy adds an obligatory AND.
CREATE POLICY debts_require_extra_unlock ON public.debts
 AS RESTRICTIVE FOR ALL TO authenticated
 USING (public.debt_access_valid(workspace_id))
 WITH CHECK (public.debt_access_valid(workspace_id));
-- WARNING: RLS becomes fail-closed until secret is provisioned and frontend deployed.
-- Explicit production approval and a coordinated cutover are mandatory.
COMMIT;
