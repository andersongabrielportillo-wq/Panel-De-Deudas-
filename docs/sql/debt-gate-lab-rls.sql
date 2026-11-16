-- SOLO LAB: RLS para deudas ficticias, sin modificar producción.
BEGIN;
GRANT USAGE ON SCHEMA debt_gate_lab TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON debt_gate_lab.debts TO authenticated;
-- Los datos de miembros y los secretos siguen sin acceso directo.
DROP POLICY IF EXISTS debt_lab_read ON debt_gate_lab.debts;
DROP POLICY IF EXISTS debt_lab_insert ON debt_gate_lab.debts;
DROP POLICY IF EXISTS debt_lab_update ON debt_gate_lab.debts;
DROP POLICY IF EXISTS debt_lab_delete ON debt_gate_lab.debts;
CREATE POLICY debt_lab_read ON debt_gate_lab.debts FOR SELECT TO authenticated
 USING (public.debt_lab_access_valid(workspace_id));
CREATE POLICY debt_lab_insert ON debt_gate_lab.debts FOR INSERT TO authenticated
 WITH CHECK (public.debt_lab_access_valid(workspace_id) AND created_by=auth.uid() AND updated_by=auth.uid());
CREATE POLICY debt_lab_update ON debt_gate_lab.debts FOR UPDATE TO authenticated
 USING (public.debt_lab_access_valid(workspace_id))
 WITH CHECK (public.debt_lab_access_valid(workspace_id) AND updated_by=auth.uid());
CREATE POLICY debt_lab_delete ON debt_gate_lab.debts FOR DELETE TO authenticated
 USING (public.debt_lab_access_valid(workspace_id));
COMMIT;