-- ACTIVACION COORDINADA: EJECUTAR SOLO DESPUES DE DESPLEGAR FRONTEND Y RPCS.
-- Preserva condiciones originales de autoría y membresía.
begin;
-- PRECHECK BLOQUEANTE: no aplicar si existen políticas inesperadas o falta la RPC.
-- Ejecutar en una ventana de despliegue coordinado, tras respaldar y probar.
DO $$
DECLARE
  v_table text;
  v_expected text[];
  v_actual text[];
BEGIN
  IF to_regprocedure('public.has_debts_unlock()') IS NULL THEN
    RAISE EXCEPTION 'Falta has_debts_unlock(): se cancela el despliegue';
  END IF;
  FOREACH v_table IN ARRAY ARRAY['debts','transactions'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=v_table AND c.relrowsecurity
    ) THEN
      RAISE EXCEPTION 'RLS no está activo en %. Se cancela', v_table;
    END IF;
    SELECT array_agg(policyname ORDER BY policyname) INTO v_actual
    FROM pg_policies WHERE schemaname='public' AND tablename=v_table;
    SELECT array_agg(x ORDER BY x) INTO v_expected
    FROM unnest(ARRAY[
      'members_read_'||v_table,
      'members_insert_'||v_table,
      'members_update_'||v_table,
      'members_delete_'||v_table
    ]) AS x;
    IF v_actual IS DISTINCT FROM v_expected THEN
      RAISE EXCEPTION 'Políticas inesperadas en %. Esperadas %, encontradas %',v_table,v_expected,v_actual;
    END IF;
  END LOOP;
END $$;
drop policy if exists members_read_debts on public.debts;
create policy members_read_debts on public.debts for select to authenticated
using (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()));
drop policy if exists members_insert_debts on public.debts;
create policy members_insert_debts on public.debts for insert to authenticated
with check (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()) and created_by=auth.uid() and updated_by=auth.uid());
drop policy if exists members_update_debts on public.debts;
create policy members_update_debts on public.debts for update to authenticated
using (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()))
with check (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()) and updated_by=auth.uid());
drop policy if exists members_delete_debts on public.debts;
create policy members_delete_debts on public.debts for delete to authenticated
using (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()));
drop policy if exists members_read_transactions on public.transactions;
create policy members_read_transactions on public.transactions for select to authenticated
using (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()));
drop policy if exists members_insert_transactions on public.transactions;
create policy members_insert_transactions on public.transactions for insert to authenticated
with check (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()) and created_by=auth.uid() and updated_by=auth.uid());
drop policy if exists members_update_transactions on public.transactions;
create policy members_update_transactions on public.transactions for update to authenticated
using (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()))
with check (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()) and updated_by=auth.uid());
drop policy if exists members_delete_transactions on public.transactions;
create policy members_delete_transactions on public.transactions for delete to authenticated
using (public.is_workspace_member(workspace_id) and (select public.has_debts_unlock()));
commit;
-- AUDITAR otras políticas permisivas, vistas, funciones y Realtime ANTES de ejecutar.
