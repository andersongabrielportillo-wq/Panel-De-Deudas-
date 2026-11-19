-- CL Nexus: ROLE CUTOVER - PREPARATION ONLY / NO EJECUTAR EN PRODUCCION.
-- Run with psql in an approved, backed-up maintenance window, AFTER the inventory schema exists.
-- Prepared role assignment ONLY for THREE explicitly selected preexisting Panel de Deudas accounts. No extra registration.
-- Never copy inv_members from LAB; authenticated identities are project-specific.
-- All three original Deudas workspace members explicitly approved for Inventory: ADMIN only.
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
CREATE TEMP TABLE cln_roles_cutover(user_id uuid PRIMARY KEY,rol text NOT NULL CHECK (rol = 'admin')) ON COMMIT DROP;
INSERT INTO cln_roles_cutover(user_id,rol)
SELECT (member->>'user_id')::uuid,(member->>'rol')::text
FROM jsonb_array_elements(:'roles_json'::jsonb) AS member;
DO $audit$
DECLARE v_workspace uuid;
BEGIN
 SELECT id INTO STRICT v_workspace FROM public.workspaces;
 IF (SELECT count(*) FROM cln_roles_cutover) <> 3
 THEN RAISE EXCEPTION 'Expected exactly 3 authorized admins'; END IF;
 IF (SELECT count(*) FROM public.workspace_members WHERE workspace_id=v_workspace) <> 3
 THEN RAISE EXCEPTION 'Expected exactly 3 existing Deudas members'; END IF;
 IF EXISTS (SELECT 1 FROM cln_roles_cutover WHERE rol <> 'admin')
 THEN RAISE EXCEPTION 'All three CL Nexus roles must be admin'; END IF;
 IF EXISTS (SELECT user_id FROM cln_roles_cutover
   EXCEPT SELECT user_id FROM public.workspace_members WHERE workspace_id=v_workspace)
 THEN RAISE EXCEPTION 'Role assignment includes an outsider'; END IF;
 IF EXISTS (SELECT user_id FROM public.workspace_members WHERE workspace_id=v_workspace
   EXCEPT SELECT user_id FROM cln_roles_cutover)
 THEN RAISE EXCEPTION 'A current Deudas member is missing from the three-admin assignment'; END IF;
 IF EXISTS (SELECT user_id FROM cln_roles_cutover
   EXCEPT SELECT id FROM auth.users)
 THEN RAISE EXCEPTION 'Role assignment includes an unknown Auth user'; END IF;
 -- The owner explicitly requested all three existing Panel de Deudas accounts.
 -- All three are admin as explicitly approved by the owner. No extra Auth users created.
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
