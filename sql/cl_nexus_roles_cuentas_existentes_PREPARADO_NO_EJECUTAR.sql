-- CL Nexus / CANDIDATE ONLY - NO EJECUTAR EN PRODUCCION SIN CORTE APROBADO.
-- Exactly the THREE pre-existing Panel de Deudas users receive role "admin".
-- No laboratory accounts, no email identifiers, no passwords and no new Auth users.
-- The names provided in chat are NOT used for matching: only production workspace_members.
-- Refuse to run when members are added, removed or no longer exactly three.
-- In an AUTHENTIC restored clone, after safe schema migration and approved recovery:
--   psql -X -v ON_ERROR_STOP=1 -f sql/cl_nexus_roles_cuentas_existentes_PREPARADO_NO_EJECUTAR.sql
\set ON_ERROR_STOP on
-- Read current memberships from the actual production project, never from LAB.
-- The transactional provisioner separately rechecks all three identities and exact roles.
SELECT coalesce(jsonb_agg(jsonb_build_object('user_id',wm.user_id,'rol','admin')
                          ORDER BY wm.user_id),'[]'::jsonb)::text AS roles_json
FROM public.workspace_members wm
JOIN auth.users u ON u.id=wm.user_id
JOIN public.workspaces w ON w.id=wm.workspace_id
\gset
\i sql/cl_nexus_roles_provision_PREPARADO_NO_EJECUTAR.sql
