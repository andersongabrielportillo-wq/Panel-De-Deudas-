-- CL Nexus | EMERGENCY ROLLBACK ONLY. NO EXECUTION UNLESS VERIFIED FAILURE.
-- Reverts ONLY two Deudas restrictive policies. Does NOT delete user/data or inventory.
-- Original PWA Git reference before release: panel-deudas-respaldo-precln-20261119
BEGIN;
DO $assert$
BEGIN
 IF (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND
      ((tablename='debts' AND policyname='debt_unlock_required_debts')
      OR (tablename='transactions' AND policyname='debt_unlock_required_transactions')))<>2
 THEN RAISE EXCEPTION 'Unexpected Deudas gate policy state: rollback aborted'; END IF;
 IF (SELECT count(*) FROM public.debts)<>1 THEN
 RAISE EXCEPTION 'Original Deudas row count changed: manual review required'; END IF;
END $assert$;
DROP POLICY debt_unlock_required_debts ON public.debts;
DROP POLICY debt_unlock_required_transactions ON public.transactions;
COMMIT;
-- This intentionally reopens original member-based Deudas REST access.
-- Use ONLY during confirmed emergency rollback and restore old web UI too.
