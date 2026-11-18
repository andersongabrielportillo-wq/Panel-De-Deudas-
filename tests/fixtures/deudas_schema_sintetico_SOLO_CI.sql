-- CL Nexus: fixture sintético para ensayos en PostgreSQL EFÍMERO ÚNICAMENTE.
-- NO EJECUTAR EN PRODUCCIÓN NI EN STAGING CON DATOS.
-- Replica las columnas de Deudas observadas mediante information_schema,
-- no los datos, privilegios, índices ni triggers completos de producción.
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT NULLIF(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT COALESCE(NULLIF(current_setting('request.jwt.claims',true),''),'{}')::jsonb
$$;
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE TABLE public.workspaces (
 id uuid PRIMARY KEY,
 nombre text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.workspace_members (
 workspace_id uuid NOT NULL REFERENCES public.workspaces(id),
 user_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (workspace_id,user_id)
);
CREATE TABLE public.debts (
 id text PRIMARY KEY,
 workspace_id uuid NOT NULL REFERENCES public.workspaces(id),
 data jsonb NOT NULL,
 created_by uuid,
 updated_by uuid,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE OR REPLACE FUNCTION public.is_workspace_member(p_workspace_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.workspace_members
 WHERE workspace_id=p_workspace_id AND user_id=auth.uid())
$$;
ALTER TABLE public.debts ENABLE ROW LEVEL SECURITY;
CREATE POLICY members_read_debts ON public.debts FOR SELECT TO authenticated
 USING(public.is_workspace_member(workspace_id));
CREATE POLICY members_insert_debts ON public.debts FOR INSERT TO authenticated
 WITH CHECK(public.is_workspace_member(workspace_id) AND created_by=auth.uid() AND updated_by=auth.uid());
CREATE POLICY members_update_debts ON public.debts FOR UPDATE TO authenticated
 USING(public.is_workspace_member(workspace_id))
 WITH CHECK(public.is_workspace_member(workspace_id) AND updated_by=auth.uid());
CREATE POLICY members_delete_debts ON public.debts FOR DELETE TO authenticated
 USING(public.is_workspace_member(workspace_id));
-- NO INSERT: fixture deliberately contains no customer data or credentials.
