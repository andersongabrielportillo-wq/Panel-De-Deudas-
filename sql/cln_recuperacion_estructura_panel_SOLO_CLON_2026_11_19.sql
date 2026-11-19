-- SOLO CLON TEMPORAL: mwtvmmbmudlswblwcnyj. NO EJECUTAR EN PRODUCCION.
-- Estructura comercial de origen, reconstruida desde definiciones leidas en produccion.
-- Sin Auth users, sin secretos Vault, sin datos. RLS + REVOKE por defecto.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $guard$ BEGIN
 IF to_regclass('public.workspaces') IS NOT NULL OR
    to_regclass('public.workspace_members') IS NOT NULL OR
    to_regclass('public.debts') IS NOT NULL OR
    to_regclass('public.transactions') IS NOT NULL OR
    to_regclass('app_private.debt_unlocks') IS NOT NULL OR
    to_regclass('app_private.debt_attempts') IS NOT NULL
 THEN RAISE EXCEPTION 'CLN: stop, tables already present in recovery clone'; END IF;
 IF (SELECT count(*) FROM auth.users)<>0 OR
    (SELECT count(*) FROM vault.secrets)<>0
 THEN RAISE EXCEPTION 'CLN: stop, recovery clone unexpectedly contains Auth/Vault data'; END IF;
END $guard$;
CREATE SCHEMA IF NOT EXISTS app_private;
REVOKE ALL ON SCHEMA app_private FROM PUBLIC,anon,authenticated;
CREATE TABLE public.workspaces (
 id uuid NOT NULL DEFAULT gen_random_uuid(),
 nombre text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT workspaces_pkey PRIMARY KEY (id)
);
CREATE TABLE public.workspace_members (
 workspace_id uuid NOT NULL,
 user_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT workspace_members_pkey PRIMARY KEY (workspace_id,user_id),
 CONSTRAINT workspace_members_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE,
 CONSTRAINT workspace_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
CREATE TABLE public.debts (
 id text NOT NULL,
 workspace_id uuid NOT NULL,
 data jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_by uuid,
 updated_by uuid,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT debts_pkey PRIMARY KEY (workspace_id,id),
 CONSTRAINT debts_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE,
 CONSTRAINT debts_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id),
 CONSTRAINT debts_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id)
);
CREATE INDEX debts_workspace_idx ON public.debts(workspace_id);
CREATE TABLE public.transactions (
 id text NOT NULL,
 workspace_id uuid NOT NULL,
 debt_id text,
 data jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_by uuid,
 updated_by uuid,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT transactions_pkey PRIMARY KEY (workspace_id,id),
 CONSTRAINT transactions_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id) ON DELETE CASCADE,
 CONSTRAINT transactions_workspace_id_debt_id_fkey FOREIGN KEY (workspace_id,debt_id) REFERENCES public.debts(workspace_id,id) ON DELETE CASCADE,
 CONSTRAINT transactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id),
 CONSTRAINT transactions_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id)
);
CREATE INDEX transactions_workspace_idx ON public.transactions(workspace_id);
CREATE INDEX transactions_debt_idx ON public.transactions(workspace_id,debt_id);
CREATE TABLE app_private.debt_unlocks (
 user_id uuid NOT NULL,
 session_id uuid NOT NULL,
 expires_at timestamptz NOT NULL,
 CONSTRAINT debt_unlocks_pkey PRIMARY KEY (user_id,session_id)
);
CREATE TABLE app_private.debt_attempts (
 user_id uuid NOT NULL,
 failed_count integer NOT NULL DEFAULT 0,
 window_started_at timestamptz NOT NULL DEFAULT now(),
 blocked_until timestamptz,
 CONSTRAINT debt_attempts_pkey PRIMARY KEY (user_id)
);
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.debt_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_private.debt_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.workspaces,public.workspace_members,public.debts,public.transactions,
 app_private.debt_unlocks,app_private.debt_attempts FROM PUBLIC,anon,authenticated;
DO $assert$ BEGIN
 IF (SELECT count(*) FROM public.workspaces)<>0 OR
 (SELECT count(*) FROM public.workspace_members)<>0 OR
 (SELECT count(*) FROM public.debts)<>0 OR
 (SELECT count(*) FROM public.transactions)<>0 OR
 (SELECT count(*) FROM auth.users)<>0 OR
 (SELECT count(*) FROM vault.secrets)<>0
 THEN RAISE EXCEPTION 'CLN: staging must be completely empty'; END IF;
END $assert$;
COMMIT;