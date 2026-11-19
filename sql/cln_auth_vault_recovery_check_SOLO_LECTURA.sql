-- CL Nexus | Auth + Vault restore readiness verification (CLONE OR ORIGINAL), READ ONLY.
-- Never outputs passwords, root encryption key, API keys, JWTs, user emails or full debts.
-- Required on restored clone BEFORE migrating, with expected original hash.
-- PASS here is structural/decryption readiness, NOT a successful live Auth HTTP login.
BEGIN READ ONLY;
WITH state AS (
 SELECT
 (SELECT count(*)::int FROM auth.users) auth_users,
 (SELECT count(*)::int FROM public.workspace_members) workspace_members,
 (SELECT count(distinct wm.user_id)::int FROM public.workspace_members wm JOIN auth.users u ON u.id=wm.user_id) linked_users,
 (SELECT count(*)::int FROM public.workspaces) workspaces,
 (SELECT count(*)::int FROM public.debts) debt_rows,
 (SELECT count(*)::int FROM public.transactions) transaction_rows,
 (SELECT md5(coalesce(string_agg(id||'='||data::text,'|' ORDER BY id),'')) FROM public.debts) debt_md5,
 (SELECT count(*)::int FROM vault.secrets WHERE name='deudas_access_password') vault_secret_count,
 EXISTS(SELECT 1 FROM vault.decrypted_secrets
   WHERE name='deudas_access_password' AND decrypted_secret IS NOT NULL AND length(decrypted_secret)>0) vault_decryptable,
 (SELECT count(*)::int FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN ('unlock_debts','has_debts_unlock','lock_debts')) gate_rpcs,
 (SELECT count(*)::int FROM pg_policies
   WHERE schemaname='public' AND tablename IN ('debts','transactions')
     AND permissive='PERMISSIVE' AND policyname LIKE 'members_%') original_rls_policies,
 (SELECT count(*)::int FROM pg_policies
   WHERE schemaname='public' AND tablename IN ('debts','transactions')
     AND permissive='RESTRICTIVE') restrictive_rls_policies,
 (SELECT count(*)::int FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname IN ('unlock_debts','has_debts_unlock','lock_debts')
     AND has_function_privilege('anon',p.oid,'EXECUTE')) anon_gate_rpcs
)
SELECT *,
 (auth_users=3 AND workspace_members=3 AND linked_users=3 AND workspaces=1
   AND debt_rows=1 AND debt_md5='cae1aed74556ce96dde7f673e33d4668'
   AND vault_secret_count=1 AND vault_decryptable AND gate_rpcs=3
   AND original_rls_policies=8 AND anon_gate_rpcs=0) AS recovered_auth_vault_structural_ready,
 false AS real_http_logins_approved,
 false AS cutover_authorized
FROM state;
ROLLBACK;
