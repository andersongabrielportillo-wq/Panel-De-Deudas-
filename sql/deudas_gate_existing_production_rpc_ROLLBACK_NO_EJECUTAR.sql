-- CL Nexus | EMERGENCY SECURITY CUTOVER ROLLBACK | NOT A DATA RESTORE.
-- Only run after explicitly deciding to return to the previous un-gated Deudas API.
-- This removes the extra gate, reducing security to pre-cutover workspace membership RLS.
BEGIN;
DROP POLICY IF EXISTS debt_unlock_required_debts ON public.debts;
DROP POLICY IF EXISTS debt_unlock_required_transactions ON public.transactions;
COMMIT;
-- Also roll back the PWA to the matching pre-cutover release; never erase local debt caches.
