-- CL Nexus / CANDIDATE ONLY - DO NOT RUN BEFORE CONTROLLED CUTOVER.
-- Map THREE existing Panel de Deudas Auth accounts by their complete production emails and explicit roles.
-- Never use laboratory UUIDs, create auth.users, or change existing login credentials.
-- Example (PRIVATE LOCAL TERMINAL after verification, never commit real addresses):
--   psql -X -v ON_ERROR_STOP=1 -v admin_email='confirmed-admin@example.invalid' -v secretaria_email='confirmed-secretary@example.invalid' -v third_email='confirmed-third@example.invalid' -v third_role='admin' -f sql/cl_nexus_roles_cuentas_existentes_PREPARADO_NO_EJECUTAR.sql
-- Must run only after the reviewed inventory schema exists, backup/recovery and auth validation.
\set ON_ERROR_STOP on
\if :{?admin_email}
\else
  DO $missing_required_argument$ BEGIN RAISE EXCEPTION 'Missing admin_email: refusing role provisioning.'; END $missing_required_argument$;
\endif
\if :{?secretaria_email}
\else
  DO $missing_required_argument$ BEGIN RAISE EXCEPTION 'Missing secretaria_email: refusing role provisioning.'; END $missing_required_argument$;
\endif
\if :{?third_email}
\else
  DO $missing_required_argument$ BEGIN RAISE EXCEPTION 'Missing third_email: refusing role provisioning.'; END $missing_required_argument$;
\endif
\if :{?third_role}
\else
  DO $missing_required_argument$ BEGIN RAISE EXCEPTION 'Missing third_role: refusing role provisioning.'; END $missing_required_argument$;
\endif
-- No logged credentials, no exposed emails: exact identity matching in original Auth project.
-- Resolve only users who ALREADY belong to the production Deudas workspace.
-- If any identity is missing/ambiguous, or the third role is not explicit, provisioning aborts atomically.
SELECT coalesce(jsonb_agg(jsonb_build_object('user_id',u.id,'rol',requested.rol)
                         ORDER BY requested.rol),'[]'::jsonb)::text AS roles_json
FROM (
 VALUES ('admin',lower(btrim(:'admin_email'))),
        ('secretaria',lower(btrim(:'secretaria_email'))),
        (lower(btrim(:'third_role')),lower(btrim(:'third_email')))
) requested(rol,email)
JOIN auth.users u ON lower(u.email)=requested.email
JOIN public.workspace_members wm ON wm.user_id=u.id
JOIN public.workspaces w ON w.id=wm.workspace_id
\gset
-- Strict transactional preflight: exactly 3 distinct existing people, at least one admin
-- and one secretaria, and the third role explicitly chosen by the owner.
\i sql/cl_nexus_roles_provision_PREPARADO_NO_EJECUTAR.sql
