-- CL Nexus | PREPARATION ONLY: do not run until backup restore, UI deployment and authenticated test are approved.
-- Uses EXISTING production RPC public.has_debts_unlock() (no second password system).
-- Apply as one coordinated cutover with the compatible PWA, after validating a restored clone.
BEGIN;
DO $$
DECLARE v_count integer;
BEGIN
 IF to_regprocedure('public.has_debts_unlock()') IS NULL OR
    to_regprocedure('public.unlock_debts(text)') IS NULL OR
    to_regprocedure('public.lock_debts()') IS NULL
 THEN RAISE EXCEPTION 'Deudas gate RPC missing: abort cutover'; END IF;
 SELECT count(*) INTO v_count FROM pg_policies
 WHERE schemaname='public' AND tablename IN ('debts','transactions')
 AND policyname IN ('debt_unlock_required_debts','debt_unlock_required_transactions');
 IF v_count <> 0 THEN RAISE EXCEPTION 'Gate policies already exist: inspect before applying'; END IF;
 SELECT count(*) INTO v_count FROM pg_policies
 WHERE schemaname='public' AND tablename IN ('debts','transactions')
 AND roles='{authenticated}' AND permissive='PERMISSIVE'
 AND cmd IN ('SELECT','INSERT','UPDATE','DELETE')
 AND policyname LIKE 'members_%';
 IF v_count <> 8 THEN RAISE EXCEPTION 'Expected 8 original membership policies, found %: review schema drift',v_count; END IF;
 IF has_function_privilege('anon','public.has_debts_unlock()','EXECUTE') OR
    has_function_privilege('anon','public.unlock_debts(text)','EXECUTE') OR
    has_function_privilege('anon','public.lock_debts()','EXECUTE')
 THEN RAISE EXCEPTION 'Anonymous access to debt gate RPC detected: abort'; END IF;
 IF NOT has_function_privilege('authenticated','public.has_debts_unlock()','EXECUTE') OR
    NOT has_function_privilege('authenticated','public.unlock_debts(text)','EXECUTE') OR
    NOT has_function_privilege('authenticated','public.lock_debts()','EXECUTE')
 THEN RAISE EXCEPTION 'Authenticated users cannot execute required gate RPCs'; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid='public.debts'::regclass AND relrowsecurity)
 OR NOT EXISTS (SELECT 1 FROM pg_class WHERE oid='public.transactions'::regclass AND relrowsecurity)
 THEN RAISE EXCEPTION 'RLS not enabled: abort'; END IF;
END $$;
-- RESTRICTIVE policies are ANDed with all existing permissive workspace membership policies.
-- This protects both reads and writes, including REST calls that bypass the frontend.
CREATE POLICY debt_unlock_required_debts ON public.debts
 AS RESTRICTIVE FOR ALL TO authenticated
 USING (public.has_debts_unlock())
 WITH CHECK (public.has_debts_unlock());
CREATE POLICY debt_unlock_required_transactions ON public.transactions
 AS RESTRICTIVE FOR ALL TO authenticated
 USING (public.has_debts_unlock())
 WITH CHECK (public.has_debts_unlock());
COMMIT;
