-- Dependencias MINIMAS FICTICIAS para probar migraciones de contratos en PostgreSQL efimero.
-- NO reproduce la implementacion real de inv_registrar_venta: no certifica stock.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
DO $$ BEGIN CREATE ROLE authenticated NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE anon NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE TABLE public.inv_members(user_id uuid PRIMARY KEY,rol text NOT NULL);
CREATE TABLE public.inv_vendedores(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),nombre text NOT NULL,activo boolean NOT NULL DEFAULT true,creado_en timestamptz DEFAULT now());
CREATE TABLE public.inv_items(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),nombre_original text NOT NULL,categoria text,estado text NOT NULL DEFAULT 'activo');
CREATE TABLE public.inv_ventas(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),client_op_id uuid UNIQUE NOT NULL,anulada_en timestamptz);
CREATE OR REPLACE FUNCTION public.inv_registrar_venta(uuid,text,jsonb,numeric,text,uuid)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE nuevo uuid;
BEGIN
 -- STUB EXCLUSIVAMENTE DE COMPILACION; NO simula ni descuenta stock.
 INSERT INTO public.inv_ventas(client_op_id) VALUES ($6) RETURNING id INTO nuevo;
 RETURN nuevo;
END $$;
