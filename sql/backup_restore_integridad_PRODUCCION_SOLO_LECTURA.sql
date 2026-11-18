-- CL Nexus / Panel de Deudas: read-only backup/restore integrity baseline.
-- Run on production during a frozen cutover, then run again on an isolated restore.
-- Never copy raw customer data into CI or GitHub; compare totals and SHA256 out of band.
-- The digest is a checksum, NOT a backup or authorization to migrate.
BEGIN READ ONLY;
SELECT
  current_database() AS database_name,
  transaction_timestamp() AS measured_at,
  (SELECT count(*) FROM public.workspaces) AS workspaces,
  (SELECT count(*) FROM public.workspace_members) AS workspace_members,
  (SELECT count(*) FROM public.debts) AS debt_rows,
  (SELECT count(*) FROM public.debts WHERE id='__shared_state__') AS shared_state_rows,
  (SELECT count(*) FROM public.transactions) AS transaction_rows,
  (SELECT coalesce(sum(pg_column_size(data)),0) FROM public.debts) AS debt_payload_bytes,
  (SELECT max(updated_at) FROM public.debts) AS last_debt_update,
  (SELECT encode(extensions.digest(convert_to(coalesce(string_agg(id||'='||data::text,'|' ORDER BY id),''),'UTF8'),'sha256'),'hex') FROM public.debts) AS debt_checksum_sha256,
  (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename IN ('debts','transactions') AND permissive='RESTRICTIVE') AS extra_restrictive_policies,
  (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN ('unlock_debts','has_debts_unlock','lock_debts')) AS existing_debt_gate_functions;
ROLLBACK;
-- This excludes the browser-local cp_v2 cache and pending offline changes.
-- Complete both cloud backup and encrypted local exports before cutover.
