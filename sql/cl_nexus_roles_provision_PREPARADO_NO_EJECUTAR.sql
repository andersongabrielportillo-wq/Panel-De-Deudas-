-- CL Nexus: ROLE CUTOVER - PREPARATION ONLY / NO EJECUTAR EN PRODUCCION.
-- Run with psql in an approved, backed-up maintenance window, AFTER the inventory schema exists.
-- Example: psql -v roles_json='[{"user_id":"...","rol":"admin"},{"user_id":"...","rol":"secretaria"},{"user_id":"...","rol":"admin"}]' -f THIS_FILE
-- Never copy inv_members from LAB; authenticated identities are project-specific.
-- Only explicitly listed users get inventory access; other Deudas members remain unprivileged here.
\set ON_ERROR_STOP on
BEGIN;
DO $preflight$
BEGIN
 IF to_regclass('public.inv_members') IS NULL OR to_regclass('public.workspace_members') IS NULL
 THEN RAISE EXCEPTION 'Required membership table missing'; END IF;
 IF (SELECT count(*) FROM public.workspaces)<>1
 THEN RAISE EXCEPTION 'Expected exactly one production workspace; abort'; END IF;
 IF EXISTS (SELECT 1 FROM public.inv_members)
 THEN RAISE EXCEPTION 'Inventory members already provisioned: inspect before modifying'; END IF;
END $preflight$;
CREATE TEMP TABLE cln_roles_cutover(user_id uuid PRIMARY KEY,rol text NOT NULL CHECK (rol IN ('admin','secretaria'))) ON COMMIT DROP;
INSERT INTO cln_roles_cutover(user_id,rol)
SELECT (member->>'user_id')::uuid,(member->>'rol')::text
FROM jsonb_array_elements(:'roles_json'::jsonb) AS member;
DO $audit$
DECLARE v_workspace uuid;
BEGIN
 SELECT id INTO STRICT v_workspace FROM public.workspaces;
 IF (SELECT count(*) FROM cln_roles_cutover) NOT BETWEEN 2 AND 3
 THEN RAISE EXCEPTION 'Expected exactly 2 or 3 explicitly authorized members'; END IF;
 IF NOT EXISTS(SELECT 1 FROM cln_roles_cutover WHERE rol='admin')
 OR NOT EXISTS(SELECT 1 FROM cln_roles_cutover WHERE rol='secretaria')
 THEN RAISE EXCEPTION 'Both Administrador and Secretaria must be explicitly mapped'; END IF;
 IF EXISTS (SELECT user_id FROM cln_roles_cutover
   EXCEPT SELECT user_id FROM public.workspace_members WHERE workspace_id=v_workspace)
 THEN RAISE EXCEPTION 'Role assignment includes an outsider'; END IF;
 IF EXISTS (SELECT user_id FROM cln_roles_cutover
   EXCEPT SELECT id FROM auth.users)
 THEN RAISE EXCEPTION 'Role assignment includes an unknown Auth user'; END IF;
 -- Intentionally do NOT require every Deudas workspace member to receive CL Nexus privileges.
 -- The owner and secretary may be the only two authorized inventory operators.
 -- A third Deudas-only user must NOT be silently promoted to CL Nexus admin.
END $audit$;
INSERT INTO public.inv_members(user_id,rol)
SELECT user_id,rol FROM cln_roles_cutover;
DO $verify$
BEGIN
 IF (SELECT count(*) FROM public.inv_members)<>(SELECT count(*) FROM cln_roles_cutover)
 THEN RAISE EXCEPTION 'Membership verification failed'; END IF;
END $verify$;
COMMIT;
-- Only do this after testing with authentic sessions and reviewing requested roles.
