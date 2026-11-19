-- CL Nexus / CANDIDATE ONLY - DO NOT RUN BEFORE CONTROLLED CUTOVER.
-- Map TWO existing Panel de Deudas Auth accounts by their complete production emails.
-- Never use laboratory UUIDs, create auth.users, or change existing login credentials.
-- Example (PRIVATE LOCAL TERMINAL after verification, never commit real addresses):
--   psql -X -v ON_ERROR_STOP=1 -v admin_email='confirmed-admin@example.invalid' -v secretaria_email='confirmed-secretary@example.invalid' -f sql/cl_nexus_roles_cuentas_existentes_PREPARADO_NO_EJECUTAR.sql
-- Must run only after the reviewed inventory schema exists, backup/recovery and auth validation.
\set ON_ERROR_STOP on
\if :{?admin_email}
\else
  \echo 'Missing admin_email: refusing role provisioning.'
  \quit 3
\endif
\if :{?secretaria_email}
\else
  \echo 'Missing secretaria_email: refusing role provisioning.'
  \quit 3
\endif
-- No logged credentials, no exposed emails: exact identity matching in original Auth project.
-- Resolve only users who ALREADY belong to the production Deudas workspace.
-- If either identity is missing/ambiguous, existing role provisioning aborts atomically.
SELECT coalesce(jsonb_agg(jsonb_build_object('user_id',u.id,'rol',requested.rol)
                         ORDER BY requested.rol),'[]'::jsonb)::text AS roles_json
FROM (
 VALUES ('admin',lower(btrim(:'admin_email'))),
        ('secretaria',lower(btrim(:'secretaria_email')))
) requested(rol,email)
JOIN auth.users u ON lower(u.email)=requested.email
JOIN public.workspace_members wm ON wm.user_id=u.id
JOIN public.workspaces w ON w.id=wm.workspace_id
\gset
-- Strict transactional preflight: exactly 2 distinct people, 1 admin, 1 secretaria,
-- both within the original production Auth/workspace; third account remains Deudas-only.
\i sql/cl_nexus_roles_provision_PREPARADO_NO_EJECUTAR.sql
