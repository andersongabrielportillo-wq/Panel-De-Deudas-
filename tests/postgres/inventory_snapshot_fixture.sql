-- Disposable PostgreSQL 17: production-like Deudas schema and synthetic data.
-- No production or laboratory business data or real user credentials are included.
\i tests/fixtures/deudas_schema_sintetico_SOLO_CI.sql
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE TABLE public.transactions (
  id text PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES public.workspaces(id),
  data jsonb NOT NULL,
  created_by uuid,
  updated_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY members_read_transactions ON public.transactions FOR SELECT TO authenticated USING(public.is_workspace_member(workspace_id));
CREATE POLICY members_insert_transactions ON public.transactions FOR INSERT TO authenticated WITH CHECK(public.is_workspace_member(workspace_id) AND created_by=auth.uid() AND updated_by=auth.uid());
CREATE POLICY members_update_transactions ON public.transactions FOR UPDATE TO authenticated USING(public.is_workspace_member(workspace_id)) WITH CHECK(public.is_workspace_member(workspace_id) AND updated_by=auth.uid());
CREATE POLICY members_delete_transactions ON public.transactions FOR DELETE TO authenticated USING(public.is_workspace_member(workspace_id));
INSERT INTO public.workspaces(id,nombre) VALUES('00000000-0000-0000-0000-000000000001','synthetic workspace');
INSERT INTO auth.users(id) VALUES
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003'),
 ('00000000-0000-0000-0000-000000000004');
INSERT INTO public.workspace_members(workspace_id,user_id) VALUES
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003'),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004');
INSERT INTO public.debts(id,workspace_id,data,created_by,updated_by)
VALUES('__shared_state__','00000000-0000-0000-0000-000000000001',
 '{"v":2,"rev":7,"debts":[{"id":"fake-local-fixture"}],"tx":[]}'::jsonb,
 '00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002');
