-- CL Nexus | Auditoria de pre-corte sobre PRODUCCION | SOLO LECTURA.
-- No guarda contraseñas ni devuelve secretos de Vault. No concede permiso de publicar.
-- Ejecutar antes del corte y en un clon restaurado; comparar con respaldo VERIFICADO.
BEGIN READ ONLY;
WITH actual AS (
 SELECT
   (SELECT count(*) FROM public.workspaces)::int workspaces,
   (SELECT count(*) FROM public.workspace_members)::int members,
   (SELECT count(*) FROM auth.users)::int auth_users,
   (SELECT count(*) FROM public.workspace_members m JOIN auth.users u ON m.user_id=u.id)::int mapped_members,
   (SELECT count(*) FROM public.debts)::int debts,
   (SELECT count(*) FROM public.transactions)::int transactions,
   (SELECT md5(coalesce(string_agg(id||'='||data::text,'|' ORDER BY id),''))
       FROM public.debts) debt_content_md5,
   (SELECT count(*) FROM vault.secrets WHERE name='deudas_access_password')::int vault_debt_secret_count,
   EXISTS(SELECT 1 FROM vault.decrypted_secrets WHERE name='deudas_access_password'
       AND decrypted_secret IS NOT NULL AND length(decrypted_secret)>0) vault_secret_decryptable,
   (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
       WHERE n.nspname='public' AND p.proname IN ('unlock_debts','has_debts_unlock','lock_debts'))::int debt_gate_rpcs,
   (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
       WHERE n.nspname='public' AND p.proname IN ('unlock_debts','has_debts_unlock','lock_debts')
       AND has_function_privilege('anon',p.oid,'EXECUTE'))::int anonymous_gate_rpcs,
   (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
       WHERE n.nspname='public' AND p.proname IN ('unlock_debts','has_debts_unlock','lock_debts')
       AND has_function_privilege('authenticated',p.oid,'EXECUTE'))::int authenticated_gate_rpcs,
   (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename IN ('debts','transactions')
       AND permissive='PERMISSIVE' AND roles='{authenticated}' AND policyname LIKE 'members_%')::int member_policies,
   (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename IN ('debts','transactions')
       AND permissive='RESTRICTIVE')::int restrictive_gate_policies,
   (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
       WHERE n.nspname='public' AND p.proname LIKE 'inv_%')::int production_inventory_rpcs,
   ((SELECT c.relrowsecurity FROM pg_class c WHERE c.oid='public.debts'::regclass) AND
    (SELECT c.relrowsecurity FROM pg_class c WHERE c.oid='public.transactions'::regclass)) debt_rls_enabled
)
SELECT *,
  (workspaces=1 AND members=3 AND auth_users=3 AND mapped_members=3
   AND vault_debt_secret_count=1 AND vault_secret_decryptable
   AND debt_gate_rpcs=3 AND anonymous_gate_rpcs=0 AND authenticated_gate_rpcs=3
   AND member_policies=8 AND restrictive_gate_policies=0
   AND production_inventory_rpcs=0 AND debt_rls_enabled) AS expected_original_baseline,
  false AS autorizacion_para_publicar
FROM actual;
ROLLBACK;
-- Important: authorization remains FALSE until real restore of Auth/Vault,
-- API login/gate test, inventories verified and coordinated rollback are complete.
