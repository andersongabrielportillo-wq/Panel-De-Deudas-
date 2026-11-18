-- CL Nexus / Deudas: READ-ONLY pre-cutover report. No credentials or debt payloads returned.
-- Execute separately on staging and production; inspect each result before any migration.
SELECT
  (SELECT count(*) FROM public.workspaces) AS workspace_count,
  (SELECT count(*) FROM public.workspace_members) AS membership_count,
  (SELECT count(*) FROM public.debts WHERE id='__shared_state__') AS shared_debt_rows,
  (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='debts') AS debt_rls_policies,
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.debts'::regclass) AS debt_rls_enabled,
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN ('debt_unlock','debt_lock','debt_access_valid')) AS gate_rpc_count,
  (SELECT count(*) FROM pg_namespace WHERE nspname='debt_gate_secure') AS gate_private_schema_count;
-- NOTE: counts alone are NOT a backup, a test of JWT session_id, or approval to deploy.
-- Never export debt contents or passwords into CI logs.
