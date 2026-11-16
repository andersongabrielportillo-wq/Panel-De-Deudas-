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
-- Motor de inventario FICTICIO pero transaccional para pruebas de integración.
-- NO equivale a la implementación real de producción.
CREATE TABLE public.inv_stock_ci(
 item_id uuid NOT NULL REFERENCES public.inv_items(id),
 location_id smallint NOT NULL CHECK(location_id IN (1,2)),
 cantidad integer NOT NULL CHECK(cantidad>=0),
 PRIMARY KEY(item_id,location_id)
);
CREATE TABLE public.inv_movimientos_ci(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 venta_id uuid NOT NULL REFERENCES public.inv_ventas(id),
 item_id uuid NOT NULL REFERENCES public.inv_items(id),
 location_id smallint NOT NULL,
 cantidad integer NOT NULL CHECK(cantidad>0)
);
CREATE OR REPLACE FUNCTION public.inv_registrar_venta(uuid,text,jsonb,numeric,text,uuid)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE
 nuevo uuid;
 linea jsonb;
 v_item uuid;
 v_location smallint;
 v_cantidad integer;
BEGIN
 IF EXISTS(SELECT 1 FROM public.inv_ventas WHERE client_op_id=$6) THEN
  RAISE EXCEPTION 'Operacion duplicada'; END IF;
 INSERT INTO public.inv_ventas(client_op_id) VALUES ($6) RETURNING id INTO nuevo;
 FOR linea IN SELECT value FROM pg_catalog.jsonb_array_elements($3) LOOP
  v_item:=(linea->>'item_id')::uuid;
  v_location:=(linea->>'location_id')::smallint;
  v_cantidad:=(linea->>'cantidad')::integer;
  IF v_cantidad IS NULL OR v_cantidad<=0 THEN RAISE EXCEPTION 'Cantidad invalida'; END IF;
  UPDATE public.inv_stock_ci SET cantidad=cantidad-v_cantidad
  WHERE item_id=v_item AND location_id=v_location AND cantidad>=v_cantidad;
  IF NOT FOUND THEN RAISE EXCEPTION 'Existencias insuficientes'; END IF;
  INSERT INTO public.inv_movimientos_ci(venta_id,item_id,location_id,cantidad)
  VALUES(nuevo,v_item,v_location,v_cantidad);
 END LOOP;
 RETURN nuevo;
END $$;
