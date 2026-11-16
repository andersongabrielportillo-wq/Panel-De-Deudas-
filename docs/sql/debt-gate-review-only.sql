-- DISEÑO NO EJECUTAR EN PRODUCCIÓN. Revisar y probar en clon no productivo.
-- La aplicación actual accede directamente a public.debts y necesita adaptar desbloqueo y Realtime ANTES del corte.
-- Requiere configurar un hash bcrypt por workspace; NUNCA registrar contraseñas en SQL del repositorio.
BEGIN;
CREATE SCHEMA IF NOT EXISTS debt_private;
REVOKE ALL ON SCHEMA debt_private FROM PUBLIC, anon, authenticated;
CREATE TABLE IF NOT EXISTS debt_private.secrets (
 workspace_id uuid PRIMARY KEY,
 password_hash text NOT NULL CHECK (length(password_hash)>20),
 revision bigint NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS debt_private.unlocks (
 workspace_id uuid NOT NULL,
 user_id uuid NOT NULL,
 session_id uuid NOT NULL,
 revision bigint NOT NULL,
 expires_at timestamptz NOT NULL,
 PRIMARY KEY(workspace_id,user_id,session_id)
);
CREATE TABLE IF NOT EXISTS debt_private.attempts (
 workspace_id uuid NOT NULL,
 user_id uuid NOT NULL,
 failed_count int NOT NULL DEFAULT 0,
 blocked_until timestamptz,
 PRIMARY KEY(workspace_id,user_id)
);
REVOKE ALL ON ALL TABLES IN SCHEMA debt_private FROM PUBLIC, anon, authenticated;
ALTER TABLE debt_private.secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_private.unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_private.attempts ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.debt_access_valid(p_workspace_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $fn$
 SELECT auth.uid() IS NOT NULL AND EXISTS (
   SELECT 1 FROM public.workspace_members m
   JOIN debt_private.unlocks u ON u.workspace_id=m.workspace_id AND u.user_id=m.user_id
   JOIN debt_private.secrets s ON s.workspace_id=m.workspace_id AND s.revision=u.revision
   WHERE m.workspace_id=p_workspace_id AND m.user_id=auth.uid()
     AND u.session_id=NULLIF(auth.jwt()->>'session_id','')::uuid
     AND u.expires_at>now()
 );
$fn$;
REVOKE ALL ON FUNCTION public.debt_access_valid(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.debt_access_valid(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.debt_unlock(p_workspace_id uuid,p_password text)
RETURNS timestamptz LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
DECLARE v_uid uuid:=auth.uid();v_session uuid:=NULLIF(auth.jwt()->>'session_id','')::uuid;
 v_hash text;v_rev bigint;v_fail int;v_block timestamptz;v_exp timestamptz;
BEGIN
 IF v_uid IS NULL OR v_session IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.workspace_members WHERE workspace_id=p_workspace_id AND user_id=v_uid
 ) THEN RAISE EXCEPTION 'Acceso denegado'; END IF;
 IF p_password IS NULL OR length(p_password)<8 OR octet_length(p_password)>72 THEN
   RAISE EXCEPTION 'Credencial inválida'; END IF;
 INSERT INTO debt_private.attempts(workspace_id,user_id) VALUES(p_workspace_id,v_uid)
 ON CONFLICT DO NOTHING;
 SELECT failed_count,blocked_until INTO v_fail,v_block
 FROM debt_private.attempts WHERE workspace_id=p_workspace_id AND user_id=v_uid FOR UPDATE;
 IF v_block>now() THEN RAISE EXCEPTION 'Acceso temporalmente bloqueado'; END IF;
 SELECT password_hash,revision INTO v_hash,v_rev FROM debt_private.secrets WHERE workspace_id=p_workspace_id;
 IF v_hash IS NULL OR extensions.crypt(p_password,v_hash) IS DISTINCT FROM v_hash THEN
   UPDATE debt_private.attempts SET failed_count=CASE WHEN failed_count>=4 THEN 0 ELSE failed_count+1 END,
     blocked_until=CASE WHEN failed_count>=4 THEN now()+interval '15 minutes' ELSE NULL END
   WHERE workspace_id=p_workspace_id AND user_id=v_uid;
   -- No lanzar excepción: eso revertiría el contador de intentos.
   RETURN NULL;
 END IF;
 UPDATE debt_private.attempts SET failed_count=0,blocked_until=NULL
 WHERE workspace_id=p_workspace_id AND user_id=v_uid;
 v_exp:=now()+interval '20 minutes';
 INSERT INTO debt_private.unlocks(workspace_id,user_id,session_id,revision,expires_at)
 VALUES(p_workspace_id,v_uid,v_session,v_rev,v_exp)
 ON CONFLICT(workspace_id,user_id,session_id)
 DO UPDATE SET revision=EXCLUDED.revision,expires_at=EXCLUDED.expires_at;
 RETURN v_exp;
END;
$fn$;
REVOKE ALL ON FUNCTION public.debt_unlock(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.debt_unlock(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.debt_lock(p_workspace_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $fn$
BEGIN
 DELETE FROM debt_private.unlocks
 WHERE workspace_id=p_workspace_id AND user_id=auth.uid()
 AND session_id=NULLIF(auth.jwt()->>'session_id','')::uuid;
END;
$fn$;
REVOKE ALL ON FUNCTION public.debt_lock(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.debt_lock(uuid) TO authenticated;

-- CORTE ATÓMICO: ejecutar SOLO tras cliente compatible y respaldo verificado.
-- No mantener las políticas permisivas antiguas: Postgres combina políticas permisivas con OR.
DROP POLICY IF EXISTS members_read_debts ON public.debts;
DROP POLICY IF EXISTS members_insert_debts ON public.debts;
DROP POLICY IF EXISTS members_update_debts ON public.debts;
DROP POLICY IF EXISTS members_delete_debts ON public.debts;
CREATE POLICY debt_unlocked_read ON public.debts FOR SELECT TO authenticated
 USING (public.debt_access_valid(workspace_id));
CREATE POLICY debt_unlocked_insert ON public.debts FOR INSERT TO authenticated
 WITH CHECK (public.debt_access_valid(workspace_id) AND created_by=auth.uid() AND updated_by=auth.uid());
CREATE POLICY debt_unlocked_update ON public.debts FOR UPDATE TO authenticated
 USING (public.debt_access_valid(workspace_id))
 WITH CHECK (public.debt_access_valid(workspace_id) AND updated_by=auth.uid());
CREATE POLICY debt_unlocked_delete ON public.debts FOR DELETE TO authenticated
 USING (public.debt_access_valid(workspace_id));
-- Validar otras políticas existentes antes de usar este borrador.
COMMIT;
