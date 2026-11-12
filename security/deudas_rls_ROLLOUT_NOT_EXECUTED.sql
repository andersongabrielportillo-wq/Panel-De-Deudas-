-- ACTIVACION COORDINADA: EJECUTAR SOLO DESPUES DE DESPLEGAR FRONTEND Y RPCS.
-- Preserva condiciones originales de autoría y membresía.
begin;
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
