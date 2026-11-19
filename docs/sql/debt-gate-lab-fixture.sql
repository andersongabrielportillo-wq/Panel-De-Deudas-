-- Preparación aislada de pruebas de seguridad de Deudas.
-- NO ejecutar contra producción. No altera tablas existentes del LAB.
-- El proyecto LAB no contiene public.debts ni public.workspace_members;
-- por tanto el borrador de migración de producción NO es ejecutable allí directamente.
-- Estas tablas son solo para ensayos y no contienen datos reales.
BEGIN;
CREATE SCHEMA IF NOT EXISTS debt_gate_lab;
CREATE TABLE IF NOT EXISTS debt_gate_lab.workspaces (
 id uuid PRIMARY KEY,
 label text NOT NULL
);
CREATE TABLE IF NOT EXISTS debt_gate_lab.members (
 workspace_id uuid NOT NULL REFERENCES debt_gate_lab.workspaces(id),
 user_id uuid NOT NULL,
 role text NOT NULL CHECK(role IN ('admin','secretaria')),
 PRIMARY KEY(workspace_id,user_id)
);
CREATE TABLE IF NOT EXISTS debt_gate_lab.debts (
 id text NOT NULL,
 workspace_id uuid NOT NULL REFERENCES debt_gate_lab.workspaces(id),
 data jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_by uuid NOT NULL,
 updated_by uuid NOT NULL,
 PRIMARY KEY(workspace_id,id)
);
ALTER TABLE debt_gate_lab.debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_gate_lab.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE debt_gate_lab.workspaces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON SCHEMA debt_gate_lab FROM PUBLIC,anon,authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA debt_gate_lab FROM PUBLIC,anon,authenticated;
COMMIT;
-- Paso siguiente: crear RPC de prueba SECURITY DEFINER con auth.uid() y
-- JWT de sesiones LAB reales; validar acceso denegado, acceso autorizado,
-- caducidad, revocación y simultaneidad antes de adaptar el borrador.
