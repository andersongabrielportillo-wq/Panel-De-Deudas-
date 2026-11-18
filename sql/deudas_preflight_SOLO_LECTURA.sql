-- CL Nexus / Deudas: READ-ONLY schema preflight; safe even when tables do not exist.
-- Never returns passwords, client records, or debt payloads.
SELECT
 to_regclass('public.workspaces') IS NOT NULL AS workspaces_present,
 to_regclass('public.workspace_members') IS NOT NULL AS workspace_members_present,
 to_regclass('public.debts') IS NOT NULL AS debts_present,
 (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='debts') AS debt_rls_policies,
 (SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.debts')) AS debt_rls_enabled,
 (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('debt_unlock','debt_lock','debt_access_valid')) AS gate_rpc_count,
 (SELECT count(*) FROM pg_namespace WHERE nspname='debt_gate_secure') AS gate_private_schema_count;
-- If the schema matches production, run a separate authorized row-count query.
-- Metadata checks do NOT validate backup integrity, session JWT or deployment readiness.
