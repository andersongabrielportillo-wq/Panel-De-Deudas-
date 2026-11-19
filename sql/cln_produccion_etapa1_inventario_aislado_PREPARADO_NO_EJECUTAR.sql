-- CL Nexus | PRODUCTION NON-DESTRUCTIVE STAGE 1. Prepared from tested laboratory schema.
-- Installs ONLY new inventory tables/functions/triggers; NEVER touches existing Deudas RLS, Auth/Vault or data.
-- No roles, locations or articles imported. PWA deployment and debt gate occur in later coordinated stage.
-- Full Auth/Vault disaster-restore remains unverified; owner explicitly chose not to make it a deployment prerequisite.

BEGIN;
-- STAGE 1 ONLY: NON-DESTRUCTIVE INVENTORY SCHEMA, DATA / DEUDAS UNTOUCHED.
-- Before applying ensure original workspace, existing Auth, Vault, debt hash and RLS.
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='120s';
DO $cln_production_guard$
DECLARE v_workspaces integer; v_members integer;
BEGIN
 IF current_database()<>'postgres' THEN
  RAISE EXCEPTION 'Wrong database: stop'; END IF;
 IF to_regclass('public.debts') IS NULL OR
    to_regclass('public.workspace_members') IS NULL OR
    to_regprocedure('public.has_debts_unlock()') IS NULL THEN
  RAISE EXCEPTION 'Original Deudas structures missing'; END IF;
 IF (SELECT count(*) FROM auth.users)<>3 OR
    (SELECT count(*) FROM public.workspace_members)<>3 OR
    (SELECT count(*) FROM public.workspaces)<>1 THEN
  RAISE EXCEPTION 'Original Auth or workspace membership changed'; END IF;
 IF (SELECT count(*) FROM public.debts)<>1 OR
    (SELECT md5(coalesce(string_agg(id||'='||data::text,'|' ORDER BY id),'')) FROM public.debts)
      <> 'cae1aed74556ce96dde7f673e33d4668' THEN
  RAISE EXCEPTION 'Original commercial debt fingerprint changed; stop'; END IF;
 IF NOT EXISTS(SELECT 1 FROM vault.decrypted_secrets
   WHERE name='deudas_access_password' AND length(decrypted_secret)>0)
 THEN RAISE EXCEPTION 'Existing Vault secret not decryptable'; END IF;
 IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid
   WHERE n.nspname='public' AND c.relname LIKE 'inv_%')<>0
 OR (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
   WHERE n.nspname='public' AND p.proname LIKE 'inv_%')<>0
 OR to_regnamespace('inv_private') IS NOT NULL
 THEN RAISE EXCEPTION 'Inventory objects exist already: stop; do not overwrite'; END IF;
 IF (SELECT count(*) FROM pg_policies
  WHERE schemaname='public' AND tablename IN ('debts','transactions')
  AND permissive='RESTRICTIVE')<>0
 THEN RAISE EXCEPTION 'Unexpected Deudas gate policies, inspect before migration'; END IF;
END $cln_production_guard$;

CREATE SCHEMA IF NOT EXISTS inv_private;

REVOKE ALL ON SCHEMA inv_private FROM PUBLIC, anon, authenticated;

CREATE TABLE "inv_private"."garantia_autorizaciones" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "item_id" uuid NOT NULL,
  "cantidad" integer NOT NULL,
  "destino" smallint NOT NULL,
  "usuario" uuid NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "transaccion_id" bigint,
  "backend_pid" integer,
  "operacion_id" uuid
);

CREATE TABLE "inv_private"."reparacion_autorizaciones" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "reparacion_id" uuid NOT NULL,
  "item_id" uuid NOT NULL,
  "cantidad" integer NOT NULL,
  "operacion" text NOT NULL,
  "usuario" uuid NOT NULL,
  "transaccion_id" bigint NOT NULL,
  "backend_pid" integer NOT NULL,
  "operacion_id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "inv_private"."reparacion_movimientos_autorizados" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "operacion_id" uuid NOT NULL,
  "reparacion_id" uuid NOT NULL,
  "item_id" uuid NOT NULL,
  "cantidad" integer NOT NULL,
  "origen" smallint,
  "destino" smallint,
  "usuario" uuid NOT NULL,
  "transaccion_id" bigint NOT NULL,
  "backend_pid" integer NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_cliente_referencias" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "cliente_id" uuid NOT NULL,
  "orden" smallint NOT NULL,
  "nombre" text NOT NULL,
  "telefono" text,
  "direccion" text,
  "parentesco" text
);

CREATE TABLE "public"."inv_clientes" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "nombre" text NOT NULL,
  "dui" text,
  "direccion" text,
  "ubicacion" text,
  "telefono" text,
  "vivienda" text,
  "lugar_trabajo" text,
  "telefono_trabajo" text,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "actualizado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_contrato_detalles" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "contrato_id" uuid NOT NULL,
  "item_id" uuid NOT NULL,
  "cantidad" integer NOT NULL,
  "precio_credito_unitario" numeric(14,2) NOT NULL,
  "comision_linea" numeric(14,2) DEFAULT 0 NOT NULL
);

CREATE TABLE "public"."inv_contrato_primas" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "contrato_id" uuid NOT NULL,
  "monto" numeric(14,2) NOT NULL,
  "estado" text DEFAULT 'pendiente'::text NOT NULL,
  "fecha_recibida" timestamp with time zone,
  "registrado_por" uuid,
  "actualizado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_contratos" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "numero" text NOT NULL,
  "cliente_id" uuid NOT NULL,
  "vendedor_id" uuid NOT NULL,
  "venta_id" uuid,
  "fecha" date DEFAULT CURRENT_DATE NOT NULL,
  "modalidad" text DEFAULT 'credito'::text NOT NULL,
  "frecuencia" text,
  "plan" text DEFAULT 'normal'::text NOT NULL,
  "cuota" numeric(14,2),
  "saldo_inicial" numeric(14,2),
  "fecha_plan" date,
  "ruta" text,
  "dia_cobro" text,
  "receptor_alterno" text,
  "comision_total" numeric(14,2) DEFAULT 0 NOT NULL,
  "comision_estado" text DEFAULT 'pendiente'::text NOT NULL,
  "observaciones" text,
  "estado" text DEFAULT 'borrador'::text NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "actualizado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_entry_requests" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "item_id" uuid NOT NULL,
  "location_id" smallint NOT NULL,
  "cantidad" integer NOT NULL,
  "estado" text DEFAULT 'pendiente'::text NOT NULL,
  "observaciones" text,
  "solicitado_por" uuid NOT NULL,
  "revisado_por" uuid,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "revisado_en" timestamp with time zone
);

CREATE TABLE "public"."inv_items" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "nombre_original" text NOT NULL,
  "legacy_key" text,
  "categoria" text,
  "estado" text DEFAULT 'activo'::text NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_locations" (
  "id" smallint NOT NULL,
  "nombre" text NOT NULL
);

CREATE TABLE "public"."inv_members" (
  "user_id" uuid NOT NULL,
  "rol" text NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_movements" (
  "id" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  "client_op_id" uuid NOT NULL,
  "item_id" uuid NOT NULL,
  "tipo" text NOT NULL,
  "origen" smallint,
  "destino" smallint,
  "cantidad" integer NOT NULL,
  "fecha" date NOT NULL,
  "vendedor" text,
  "observaciones" text,
  "usuario" uuid DEFAULT auth.uid() NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_prima_eventos" (
  "id" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  "prima_id" uuid NOT NULL,
  "estado_anterior" text,
  "estado_nuevo" text NOT NULL,
  "usuario" uuid NOT NULL,
  "fecha" timestamp with time zone DEFAULT now() NOT NULL,
  "observaciones" text
);

CREATE TABLE "public"."inv_recepcion_detalles" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "recepcion_id" uuid NOT NULL,
  "item_id" uuid NOT NULL,
  "location_id" smallint NOT NULL,
  "cantidad" integer NOT NULL
);

CREATE TABLE "public"."inv_recepciones" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "proveedor" text NOT NULL,
  "referencia" text NOT NULL,
  "fecha_recepcion" date DEFAULT CURRENT_DATE NOT NULL,
  "observaciones" text,
  "estado" text DEFAULT 'pendiente'::text NOT NULL,
  "solicitado_por" uuid NOT NULL,
  "revisado_por" uuid,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "revisado_en" timestamp with time zone
);

CREATE TABLE "public"."inv_reparaciones" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "item_id" uuid NOT NULL,
  "cantidad" integer NOT NULL,
  "destino_tipo" text NOT NULL,
  "destino_nombre" text NOT NULL,
  "estado" text DEFAULT 'pendiente'::text NOT NULL,
  "motivo" text NOT NULL,
  "observaciones" text,
  "fecha_registro" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_envio" timestamp with time zone,
  "fecha_retorno" timestamp with time zone,
  "registrado_por" uuid NOT NULL,
  "actualizado_por" uuid,
  "cantidad_recibida" integer DEFAULT 0 NOT NULL,
  "cantidad_baja" integer DEFAULT 0 NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_returns" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "item_id" uuid NOT NULL,
  "location_id" smallint NOT NULL,
  "cantidad" integer NOT NULL,
  "estado" text DEFAULT 'pendiente'::text NOT NULL,
  "motivo" text,
  "registrado_por" uuid NOT NULL,
  "revisado_por" uuid,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "revisado_en" timestamp with time zone,
  "venta_detalle_id" uuid
);

CREATE TABLE "public"."inv_stock" (
  "item_id" uuid NOT NULL,
  "location_id" smallint NOT NULL,
  "cantidad" integer DEFAULT 0 NOT NULL
);

CREATE TABLE "public"."inv_vendedores" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "nombre" text NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_vendedores_manual" (
  "id" uuid NOT NULL,
  "nombre" text NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "creado_por" uuid DEFAULT auth.uid() NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_venta_anulacion_movimientos" (
  "venta_detalle_id" uuid NOT NULL,
  "movimiento_id" bigint NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE "public"."inv_venta_detalles" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "venta_id" uuid NOT NULL,
  "item_id" uuid NOT NULL,
  "location_id" smallint NOT NULL,
  "cantidad" integer NOT NULL,
  "precio_unitario" numeric(14,2) NOT NULL,
  "descuento" numeric(14,2) DEFAULT 0 NOT NULL,
  "subtotal" numeric(14,2) GENERATED ALWAYS AS (((cantidad)::numeric * precio_unitario)) STORED,
  "movimiento_id" bigint
);

CREATE TABLE "public"."inv_ventas" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "numero" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  "vendedor_id" uuid NOT NULL,
  "modalidad" text NOT NULL,
  "fecha" date DEFAULT CURRENT_DATE NOT NULL,
  "subtotal" numeric(14,2) DEFAULT 0 NOT NULL,
  "descuento" numeric(14,2) DEFAULT 0 NOT NULL,
  "total" numeric(14,2) DEFAULT 0 NOT NULL,
  "estado" text DEFAULT 'registrada'::text NOT NULL,
  "observaciones" text,
  "registrado_por" uuid NOT NULL,
  "client_op_id" uuid NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "solicitud_hash" text,
  "anulada_en" timestamp with time zone,
  "anulada_por" uuid,
  "motivo_anulacion" text
);

ALTER TABLE "inv_private"."garantia_autorizaciones" ADD CONSTRAINT "garantia_autorizaciones_pkey" PRIMARY KEY (id);

ALTER TABLE "inv_private"."reparacion_autorizaciones" ADD CONSTRAINT "reparacion_autorizaciones_pkey" PRIMARY KEY (id);

ALTER TABLE "inv_private"."reparacion_movimientos_autorizados" ADD CONSTRAINT "reparacion_movimientos_autorizados_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_cliente_referencias" ADD CONSTRAINT "inv_cliente_referencias_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_clientes" ADD CONSTRAINT "inv_clientes_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_contrato_detalles" ADD CONSTRAINT "inv_contrato_detalles_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_contrato_primas" ADD CONSTRAINT "inv_contrato_primas_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_entry_requests" ADD CONSTRAINT "inv_entry_requests_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_items" ADD CONSTRAINT "inv_items_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_locations" ADD CONSTRAINT "inv_locations_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_members" ADD CONSTRAINT "inv_members_pkey" PRIMARY KEY (user_id);

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_prima_eventos" ADD CONSTRAINT "inv_prima_eventos_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_recepcion_detalles" ADD CONSTRAINT "inv_recepcion_detalles_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_recepciones" ADD CONSTRAINT "inv_recepciones_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_returns" ADD CONSTRAINT "inv_returns_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_stock" ADD CONSTRAINT "inv_stock_pkey" PRIMARY KEY (item_id, location_id);

ALTER TABLE "public"."inv_vendedores" ADD CONSTRAINT "inv_vendedores_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_vendedores_manual" ADD CONSTRAINT "inv_vendedores_manual_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_venta_anulacion_movimientos" ADD CONSTRAINT "inv_venta_anulacion_movimientos_pkey" PRIMARY KEY (venta_detalle_id);

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_venta_detalles_pkey" PRIMARY KEY (id);

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_pkey" PRIMARY KEY (id);

ALTER TABLE "inv_private"."reparacion_autorizaciones" ADD CONSTRAINT "reparacion_autorizaciones_operacion_id_key" UNIQUE (operacion_id);

ALTER TABLE "inv_private"."reparacion_movimientos_autorizados" ADD CONSTRAINT "reparacion_movimientos_autorizados_operacion_id_key" UNIQUE (operacion_id);

ALTER TABLE "public"."inv_cliente_referencias" ADD CONSTRAINT "inv_cliente_referencias_cliente_id_orden_key" UNIQUE (cliente_id, orden);

ALTER TABLE "public"."inv_contrato_primas" ADD CONSTRAINT "inv_contrato_primas_contrato_id_key" UNIQUE (contrato_id);

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_numero_key" UNIQUE (numero);

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_venta_id_key" UNIQUE (venta_id);

ALTER TABLE "public"."inv_items" ADD CONSTRAINT "inv_items_legacy_key_key" UNIQUE (legacy_key);

ALTER TABLE "public"."inv_locations" ADD CONSTRAINT "inv_locations_nombre_key" UNIQUE (nombre);

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_client_op_id_key" UNIQUE (client_op_id);

ALTER TABLE "public"."inv_recepcion_detalles" ADD CONSTRAINT "inv_recepcion_detalles_recepcion_id_item_id_location_id_key" UNIQUE (recepcion_id, item_id, location_id);

ALTER TABLE "public"."inv_venta_anulacion_movimientos" ADD CONSTRAINT "inv_venta_anulacion_movimientos_movimiento_id_key" UNIQUE (movimiento_id);

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_venta_detalles_movimiento_id_key" UNIQUE (movimiento_id);

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_client_op_id_key" UNIQUE (client_op_id);

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_numero_key" UNIQUE (numero);

ALTER TABLE "inv_private"."garantia_autorizaciones" ADD CONSTRAINT "garantia_autorizaciones_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "inv_private"."garantia_autorizaciones" ADD CONSTRAINT "garantia_autorizaciones_destino_check" CHECK (destino = ANY (ARRAY[1, 2, 4]));

ALTER TABLE "inv_private"."reparacion_autorizaciones" ADD CONSTRAINT "reparacion_autorizaciones_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "inv_private"."reparacion_autorizaciones" ADD CONSTRAINT "reparacion_autorizaciones_operacion_check" CHECK (operacion = ANY (ARRAY['envio'::text, 'recepcion'::text, 'baja'::text]));

ALTER TABLE "inv_private"."reparacion_movimientos_autorizados" ADD CONSTRAINT "reparacion_movimientos_autorizados_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "inv_private"."reparacion_movimientos_autorizados" ADD CONSTRAINT "reparacion_movimientos_autorizados_check" CHECK (origen = 3 AND destino = 4 OR origen = 4 AND destino = 3 OR origen = 4 AND destino IS NULL);

ALTER TABLE "public"."inv_cliente_referencias" ADD CONSTRAINT "inv_cliente_referencias_orden_check" CHECK (orden = ANY (ARRAY[1, 2]));

ALTER TABLE "public"."inv_clientes" ADD CONSTRAINT "inv_clientes_dui_formato" CHECK (dui IS NULL OR dui ~ '^[0-9]{8}-[0-9]$'::text);

ALTER TABLE "public"."inv_clientes" ADD CONSTRAINT "inv_clientes_nombre_check" CHECK (length(btrim(nombre)) >= 2 AND length(btrim(nombre)) <= 200);

ALTER TABLE "public"."inv_clientes" ADD CONSTRAINT "inv_clientes_vivienda_check" CHECK ((vivienda = ANY (ARRAY['alquila'::text, 'propia'::text])) OR vivienda IS NULL);

ALTER TABLE "public"."inv_contrato_detalles" ADD CONSTRAINT "inv_contrato_detalles_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "public"."inv_contrato_detalles" ADD CONSTRAINT "inv_contrato_detalles_comision_linea_check" CHECK (comision_linea >= 0::numeric);

ALTER TABLE "public"."inv_contrato_detalles" ADD CONSTRAINT "inv_contrato_detalles_precio_credito_unitario_check" CHECK (precio_credito_unitario >= 0::numeric);

ALTER TABLE "public"."inv_contrato_primas" ADD CONSTRAINT "inv_contrato_primas_check" CHECK (estado = 'pendiente'::text AND fecha_recibida IS NULL OR estado = 'recibida'::text AND fecha_recibida IS NOT NULL);

ALTER TABLE "public"."inv_contrato_primas" ADD CONSTRAINT "inv_contrato_primas_estado_check" CHECK (estado = ANY (ARRAY['pendiente'::text, 'recibida'::text]));

ALTER TABLE "public"."inv_contrato_primas" ADD CONSTRAINT "inv_contrato_primas_monto_check" CHECK (monto >= 0::numeric);

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_comision_estado_check" CHECK (comision_estado = ANY (ARRAY['pendiente'::text, 'pagada'::text]));

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_comision_total_check" CHECK (comision_total >= 0::numeric);

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_cuota_check" CHECK (cuota IS NULL OR cuota >= 0::numeric);

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_estado_check" CHECK (estado = ANY (ARRAY['borrador'::text, 'confirmado'::text, 'anulado'::text]));

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_frecuencia_check" CHECK ((frecuencia = ANY (ARRAY['semanal'::text, 'quincenal'::text, 'mensual'::text])) OR frecuencia IS NULL);

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_modalidad_check" CHECK (modalidad = ANY (ARRAY['credito'::text, 'contado'::text]));

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_plan_check" CHECK (plan = ANY (ARRAY['normal'::text, '3_pagos'::text, '6_pagos'::text]));

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_saldo_inicial_check" CHECK (saldo_inicial IS NULL OR saldo_inicial >= 0::numeric);

ALTER TABLE "public"."inv_entry_requests" ADD CONSTRAINT "inv_entry_requests_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "public"."inv_entry_requests" ADD CONSTRAINT "inv_entry_requests_estado_check" CHECK (estado = ANY (ARRAY['pendiente'::text, 'aprobada'::text, 'rechazada'::text]));

ALTER TABLE "public"."inv_entry_requests" ADD CONSTRAINT "inv_entry_review_consistency" CHECK (estado = 'pendiente'::text AND revisado_por IS NULL AND revisado_en IS NULL OR (estado = ANY (ARRAY['aprobada'::text, 'rechazada'::text])) AND revisado_por IS NOT NULL AND revisado_en IS NOT NULL);

ALTER TABLE "public"."inv_items" ADD CONSTRAINT "inv_items_estado_check" CHECK (estado = ANY (ARRAY['activo'::text, 'archivado'::text, 'inactivo'::text]));

ALTER TABLE "public"."inv_members" ADD CONSTRAINT "inv_members_rol_check" CHECK (rol = ANY (ARRAY['admin'::text, 'secretaria'::text, 'empleado'::text]));

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_ajuste_no_directo" CHECK (tipo <> 'ajuste'::text);

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_fecha_check" CHECK (fecha <= CURRENT_DATE);

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_ruta_check" CHECK ((tipo = ANY (ARRAY['entrada'::text, 'devolucion'::text])) AND origen IS NULL AND destino IS NOT NULL OR tipo = 'salida'::text AND origen IS NOT NULL AND destino IS NULL OR tipo = 'traslado'::text AND origen IS NOT NULL AND destino IS NOT NULL AND origen <> destino OR tipo = 'ajuste'::text);

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_tipo_check" CHECK (tipo = ANY (ARRAY['entrada'::text, 'salida'::text, 'traslado'::text, 'devolucion'::text, 'ajuste'::text]));

ALTER TABLE "public"."inv_recepcion_detalles" ADD CONSTRAINT "inv_recepcion_detalles_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "public"."inv_recepciones" ADD CONSTRAINT "inv_recepciones_estado_check" CHECK (estado = ANY (ARRAY['pendiente'::text, 'aprobada'::text, 'rechazada'::text]));

ALTER TABLE "public"."inv_recepciones" ADD CONSTRAINT "inv_recepciones_proveedor_check" CHECK (length(btrim(proveedor)) >= 2 AND length(btrim(proveedor)) <= 200);

ALTER TABLE "public"."inv_recepciones" ADD CONSTRAINT "inv_recepciones_referencia_check" CHECK (length(btrim(referencia)) >= 1 AND length(btrim(referencia)) <= 120);

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_cantidades_check" CHECK (cantidad_recibida >= 0 AND cantidad_baja >= 0 AND (cantidad_recibida + cantidad_baja) <= cantidad);

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_destino_nombre_check" CHECK (length(btrim(destino_nombre)) > 0);

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_destino_tipo_check" CHECK (destino_tipo = ANY (ARRAY['proveedor'::text, 'taller'::text]));

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_estado_check" CHECK (estado = ANY (ARRAY['pendiente'::text, 'enviado'::text, 'recibido'::text, 'reparado'::text, 'baja'::text]));

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_motivo_check" CHECK (length(btrim(motivo)) > 0);

ALTER TABLE "public"."inv_returns" ADD CONSTRAINT "inv_returns_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "public"."inv_returns" ADD CONSTRAINT "inv_returns_estado_check" CHECK (estado = ANY (ARRAY['pendiente'::text, 'aprobada'::text, 'rechazada'::text]));

ALTER TABLE "public"."inv_stock" ADD CONSTRAINT "inv_stock_cantidad_check" CHECK (cantidad >= 0);

ALTER TABLE "public"."inv_vendedores" ADD CONSTRAINT "inv_vendedores_nombre_valido" CHECK (length(btrim(nombre)) > 0);

ALTER TABLE "public"."inv_vendedores_manual" ADD CONSTRAINT "inv_vendedores_manual_nombre_check" CHECK (length(btrim(nombre)) >= 2 AND length(btrim(nombre)) <= 200);

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_detalle_descuento_valido" CHECK (descuento <= (cantidad::numeric * precio_unitario));

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_venta_detalles_cantidad_check" CHECK (cantidad > 0);

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_venta_detalles_descuento_check" CHECK (descuento >= 0::numeric);

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_venta_detalles_location_id_check" CHECK (location_id = ANY (ARRAY[1, 2]));

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_venta_detalles_precio_unitario_check" CHECK (precio_unitario >= 0::numeric);

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_descuento_check" CHECK (descuento >= 0::numeric);

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_estado_check" CHECK (estado = ANY (ARRAY['registrada'::text, 'anulada'::text]));

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_modalidad_check" CHECK (modalidad = ANY (ARRAY['contado'::text, 'credito'::text]));

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_subtotal_check" CHECK (subtotal >= 0::numeric);

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_total_check" CHECK (total >= 0::numeric);

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_total_valido" CHECK (total = (subtotal - descuento));

ALTER TABLE "inv_private"."garantia_autorizaciones" ADD CONSTRAINT "garantia_autorizaciones_destino_fkey" FOREIGN KEY (destino) REFERENCES inv_locations(id);

ALTER TABLE "inv_private"."garantia_autorizaciones" ADD CONSTRAINT "garantia_autorizaciones_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "inv_private"."reparacion_autorizaciones" ADD CONSTRAINT "reparacion_autorizaciones_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "inv_private"."reparacion_autorizaciones" ADD CONSTRAINT "reparacion_autorizaciones_reparacion_id_fkey" FOREIGN KEY (reparacion_id) REFERENCES inv_reparaciones(id);

ALTER TABLE "inv_private"."reparacion_autorizaciones" ADD CONSTRAINT "reparacion_autorizaciones_usuario_fkey" FOREIGN KEY (usuario) REFERENCES auth.users(id);

ALTER TABLE "inv_private"."reparacion_movimientos_autorizados" ADD CONSTRAINT "reparacion_movimientos_autorizados_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "inv_private"."reparacion_movimientos_autorizados" ADD CONSTRAINT "reparacion_movimientos_autorizados_reparacion_id_fkey" FOREIGN KEY (reparacion_id) REFERENCES inv_reparaciones(id);

ALTER TABLE "inv_private"."reparacion_movimientos_autorizados" ADD CONSTRAINT "reparacion_movimientos_autorizados_usuario_fkey" FOREIGN KEY (usuario) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_cliente_referencias" ADD CONSTRAINT "inv_cliente_referencias_cliente_id_fkey" FOREIGN KEY (cliente_id) REFERENCES inv_clientes(id) ON DELETE RESTRICT;

ALTER TABLE "public"."inv_contrato_detalles" ADD CONSTRAINT "inv_contrato_detalles_contrato_id_fkey" FOREIGN KEY (contrato_id) REFERENCES inv_contratos(id) ON DELETE RESTRICT;

ALTER TABLE "public"."inv_contrato_detalles" ADD CONSTRAINT "inv_contrato_detalles_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "public"."inv_contrato_primas" ADD CONSTRAINT "inv_contrato_primas_contrato_id_fkey" FOREIGN KEY (contrato_id) REFERENCES inv_contratos(id) ON DELETE RESTRICT;

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_cliente_id_fkey" FOREIGN KEY (cliente_id) REFERENCES inv_clientes(id);

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_vendedor_id_fkey" FOREIGN KEY (vendedor_id) REFERENCES inv_vendedores(id);

ALTER TABLE "public"."inv_contratos" ADD CONSTRAINT "inv_contratos_venta_id_fkey" FOREIGN KEY (venta_id) REFERENCES inv_ventas(id);

ALTER TABLE "public"."inv_entry_requests" ADD CONSTRAINT "inv_entry_requests_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "public"."inv_entry_requests" ADD CONSTRAINT "inv_entry_requests_location_id_fkey" FOREIGN KEY (location_id) REFERENCES inv_locations(id);

ALTER TABLE "public"."inv_entry_requests" ADD CONSTRAINT "inv_entry_requests_revisado_por_fkey" FOREIGN KEY (revisado_por) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_entry_requests" ADD CONSTRAINT "inv_entry_requests_solicitado_por_fkey" FOREIGN KEY (solicitado_por) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_members" ADD CONSTRAINT "inv_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_destino_fkey" FOREIGN KEY (destino) REFERENCES inv_locations(id);

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_origen_fkey" FOREIGN KEY (origen) REFERENCES inv_locations(id);

ALTER TABLE "public"."inv_movements" ADD CONSTRAINT "inv_movements_usuario_fkey" FOREIGN KEY (usuario) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_prima_eventos" ADD CONSTRAINT "inv_prima_eventos_prima_id_fkey" FOREIGN KEY (prima_id) REFERENCES inv_contrato_primas(id) ON DELETE RESTRICT;

ALTER TABLE "public"."inv_recepcion_detalles" ADD CONSTRAINT "inv_recepcion_detalles_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "public"."inv_recepcion_detalles" ADD CONSTRAINT "inv_recepcion_detalles_location_id_fkey" FOREIGN KEY (location_id) REFERENCES inv_locations(id);

ALTER TABLE "public"."inv_recepcion_detalles" ADD CONSTRAINT "inv_recepcion_detalles_recepcion_id_fkey" FOREIGN KEY (recepcion_id) REFERENCES inv_recepciones(id);

ALTER TABLE "public"."inv_recepciones" ADD CONSTRAINT "inv_recepciones_revisado_por_fkey" FOREIGN KEY (revisado_por) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_recepciones" ADD CONSTRAINT "inv_recepciones_solicitado_por_fkey" FOREIGN KEY (solicitado_por) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_actualizado_por_fkey" FOREIGN KEY (actualizado_por) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "public"."inv_reparaciones" ADD CONSTRAINT "inv_reparaciones_registrado_por_fkey" FOREIGN KEY (registrado_por) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_returns" ADD CONSTRAINT "inv_returns_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "public"."inv_returns" ADD CONSTRAINT "inv_returns_location_id_fkey" FOREIGN KEY (location_id) REFERENCES inv_locations(id);

ALTER TABLE "public"."inv_returns" ADD CONSTRAINT "inv_returns_registrado_por_fkey" FOREIGN KEY (registrado_por) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_returns" ADD CONSTRAINT "inv_returns_revisado_por_fkey" FOREIGN KEY (revisado_por) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_returns" ADD CONSTRAINT "inv_returns_venta_detalle_id_fkey" FOREIGN KEY (venta_detalle_id) REFERENCES inv_venta_detalles(id);

ALTER TABLE "public"."inv_stock" ADD CONSTRAINT "inv_stock_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "public"."inv_stock" ADD CONSTRAINT "inv_stock_location_id_fkey" FOREIGN KEY (location_id) REFERENCES inv_locations(id);

ALTER TABLE "public"."inv_vendedores_manual" ADD CONSTRAINT "inv_vendedores_manual_id_fkey" FOREIGN KEY (id) REFERENCES inv_vendedores(id) ON DELETE RESTRICT;

ALTER TABLE "public"."inv_venta_anulacion_movimientos" ADD CONSTRAINT "inv_venta_anulacion_movimientos_movimiento_id_fkey" FOREIGN KEY (movimiento_id) REFERENCES inv_movements(id);

ALTER TABLE "public"."inv_venta_anulacion_movimientos" ADD CONSTRAINT "inv_venta_anulacion_movimientos_venta_detalle_id_fkey" FOREIGN KEY (venta_detalle_id) REFERENCES inv_venta_detalles(id);

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_venta_detalles_item_id_fkey" FOREIGN KEY (item_id) REFERENCES inv_items(id);

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_venta_detalles_movimiento_id_fkey" FOREIGN KEY (movimiento_id) REFERENCES inv_movements(id);

ALTER TABLE "public"."inv_venta_detalles" ADD CONSTRAINT "inv_venta_detalles_venta_id_fkey" FOREIGN KEY (venta_id) REFERENCES inv_ventas(id);

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_anulada_por_fkey" FOREIGN KEY (anulada_por) REFERENCES auth.users(id);

ALTER TABLE "public"."inv_ventas" ADD CONSTRAINT "inv_ventas_vendedor_id_fkey" FOREIGN KEY (vendedor_id) REFERENCES inv_vendedores(id);

CREATE UNIQUE INDEX garantia_autorizacion_transaccion_item_unico ON inv_private.garantia_autorizaciones USING btree (transaccion_id, item_id) WHERE (transaccion_id IS NOT NULL);

CREATE UNIQUE INDEX garantia_operacion_id_unico ON inv_private.garantia_autorizaciones USING btree (operacion_id) WHERE (operacion_id IS NOT NULL);

CREATE UNIQUE INDEX reparacion_autorizacion_operacion_unica ON inv_private.reparacion_autorizaciones USING btree (transaccion_id, reparacion_id, operacion_id);

CREATE INDEX idx_inv_detalles_articulo ON public.inv_venta_detalles USING btree (item_id);

CREATE INDEX idx_inv_detalles_venta ON public.inv_venta_detalles USING btree (venta_id);

CREATE INDEX idx_inv_reparaciones_item_estado ON public.inv_reparaciones USING btree (item_id, estado);

CREATE INDEX idx_inv_returns_venta_detalle ON public.inv_returns USING btree (venta_detalle_id) WHERE (venta_detalle_id IS NOT NULL);

CREATE INDEX idx_inv_ventas_fecha ON public.inv_ventas USING btree (fecha);

CREATE INDEX idx_inv_ventas_vendedor_fecha ON public.inv_ventas USING btree (vendedor_id, fecha);

CREATE UNIQUE INDEX inv_clientes_dui_unico ON public.inv_clientes USING btree (dui) WHERE (dui IS NOT NULL);

CREATE INDEX inv_clientes_nombre_busqueda ON public.inv_clientes USING btree (lower(nombre));

CREATE INDEX inv_contrato_detalles_contrato_idx ON public.inv_contrato_detalles USING btree (contrato_id);

CREATE INDEX inv_contratos_cliente_idx ON public.inv_contratos USING btree (cliente_id, fecha DESC);

CREATE INDEX inv_contratos_vendedor_idx ON public.inv_contratos USING btree (vendedor_id, fecha DESC);

CREATE INDEX inv_recepcion_detalles_recepcion_idx ON public.inv_recepcion_detalles USING btree (recepcion_id);

CREATE OR REPLACE FUNCTION public.inv_hash_solicitud_venta(p_vendedor_id uuid, p_modalidad text, p_articulos jsonb, p_descuento numeric, p_observaciones text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
    SELECT pg_catalog.encode(
        pg_catalog.sha256(
            pg_catalog.convert_to(
                pg_catalog.jsonb_build_array(
                    p_vendedor_id,
                    p_modalidad,
                    p_articulos,
                    p_descuento,
                    p_observaciones
                )::text,
                'UTF8'
            )
        ),
        'hex'
    );
$function$
;

CREATE OR REPLACE FUNCTION inv_private.consumir_autorizacion_reparacion(p_item_id uuid, p_cantidad integer, p_operacion text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_operacion_id uuid;
    v_autorizacion uuid;
BEGIN
    BEGIN
        v_operacion_id :=
            NULLIF(
                current_setting(
                    'inv_private.operacion_reparacion',
                    true
                ),
                ''
            )::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
        RETURN false;
    END;

    IF v_operacion_id IS NULL THEN
        RETURN false;
    END IF;

    DELETE FROM inv_private.reparacion_autorizaciones a
    WHERE a.id = (
        SELECT x.id
        FROM inv_private.reparacion_autorizaciones x
        WHERE x.item_id = p_item_id
          AND x.cantidad = p_cantidad
          AND x.operacion = p_operacion
          AND x.usuario = auth.uid()
          AND x.transaccion_id = txid_current()
          AND x.backend_pid = pg_backend_pid()
          AND x.operacion_id = v_operacion_id
        FOR UPDATE
    )
    RETURNING a.id INTO v_autorizacion;

    RETURN v_autorizacion IS NOT NULL;
END;
$function$
;

CREATE OR REPLACE FUNCTION inv_private.verificar_reintento_venta(p_client_op_id uuid, p_hash text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_venta_id uuid;
    v_hash_guardado text;
BEGIN
    IF p_client_op_id IS NULL
       OR p_hash IS NULL
       OR length(p_hash) <> 64 THEN
        RAISE EXCEPTION
            'Identificador o huella inválidos';
    END IF;

    SELECT id, solicitud_hash
    INTO v_venta_id, v_hash_guardado
    FROM public.inv_ventas
    WHERE client_op_id = p_client_op_id;

    IF v_venta_id IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_hash_guardado IS NULL
       OR v_hash_guardado <> p_hash THEN
        RAISE EXCEPTION
            'El identificador ya fue utilizado con datos diferentes';
    END IF;

    RETURN v_venta_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_anular_venta(p_venta_id uuid, p_motivo text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid;
    v_rol text;
    v_estado text;
    v_detalle record;
    v_movimiento_id bigint;
    v_total_detalles integer := 0;
BEGIN
    -- 1. Validar usuario
    v_usuario := auth.uid();

    SELECT m.rol
    INTO v_rol
    FROM public.inv_members m
    WHERE m.user_id = v_usuario;

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION
            'No tienes permiso para anular ventas';
    END IF;

    -- 2. Validar parámetros
    IF p_venta_id IS NULL THEN
        RAISE EXCEPTION
            'Debes indicar la venta';
    END IF;

    IF NULLIF(pg_catalog.btrim(p_motivo), '') IS NULL THEN
        RAISE EXCEPTION
            'Debes indicar el motivo de anulación';
    END IF;

    -- 3. Bloquear cabecera de venta
    SELECT v.estado
    INTO v_estado
    FROM public.inv_ventas v
    WHERE v.id = p_venta_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La venta no existe';
    END IF;

    IF v_estado <> 'registrada' THEN
        RAISE EXCEPTION
            'La venta ya fue anulada o no está registrada';
    END IF;

    -- 4. Bloquear todos los detalles ANTES
    -- de consultar devoluciones.
    -- Se conserva el orden venta -> detalles.
    PERFORM d.id
    FROM public.inv_venta_detalles d
    WHERE d.venta_id = p_venta_id
    ORDER BY d.id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La venta no tiene detalles';
    END IF;

    -- 5. Verificar devoluciones asociadas
    IF EXISTS (
        SELECT 1
        FROM public.inv_returns r
        JOIN public.inv_venta_detalles d
            ON d.id = r.venta_detalle_id
        WHERE d.venta_id = p_venta_id
    ) THEN
        RAISE EXCEPTION
            'No se puede anular una venta con devoluciones asociadas';
    END IF;

    -- 6. Verificar compensaciones previas
    IF EXISTS (
        SELECT 1
        FROM public.inv_venta_anulacion_movimientos a
        JOIN public.inv_venta_detalles d
            ON d.id = a.venta_detalle_id
        WHERE d.venta_id = p_venta_id
    ) THEN
        RAISE EXCEPTION
            'La venta ya tiene movimientos de anulación';
    END IF;

    -- 7. Procesar los detalles vendidos
    FOR v_detalle IN
        SELECT
            d.id,
            d.item_id,
            d.location_id,
            d.cantidad,
            d.movimiento_id
        FROM public.inv_venta_detalles d
        WHERE d.venta_id = p_venta_id
        ORDER BY d.id
        FOR UPDATE
    LOOP
        v_total_detalles := v_total_detalles + 1;

        -- Validar movimiento original
        IF NOT EXISTS (
            SELECT 1
            FROM public.inv_movements m
            WHERE m.id = v_detalle.movimiento_id
              AND m.item_id = v_detalle.item_id
              AND m.tipo = 'salida'
              AND m.origen = v_detalle.location_id
              AND m.destino IS NULL
              AND m.cantidad = v_detalle.cantidad
        ) THEN
            RAISE EXCEPTION
                'Movimiento original inconsistente';
        END IF;

        -- Bloquear artículo
        PERFORM 1
        FROM public.inv_items i
        WHERE i.id = v_detalle.item_id
        FOR UPDATE;

        -- Restituir inventario
        INSERT INTO public.inv_stock (
            item_id,
            location_id,
            cantidad
        )
        VALUES (
            v_detalle.item_id,
            v_detalle.location_id,
            v_detalle.cantidad
        )
        ON CONFLICT (item_id, location_id)
        DO UPDATE SET
            cantidad =
                public.inv_stock.cantidad
                + EXCLUDED.cantidad;

        -- Movimiento compensatorio
        INSERT INTO public.inv_movements (
            client_op_id,
            item_id,
            tipo,
            origen,
            destino,
            cantidad,
            fecha,
            vendedor,
            observaciones,
            usuario
        )
        VALUES (
            gen_random_uuid(),
            v_detalle.item_id,
            'entrada',
            NULL,
            v_detalle.location_id,
            v_detalle.cantidad,
            CURRENT_DATE,
            NULL,
            'ANULACION VENTA '
                || p_venta_id::text
                || ' - '
                || pg_catalog.btrim(p_motivo),
            v_usuario
        )
        RETURNING id INTO v_movimiento_id;

        -- Vincular compensación al detalle
        INSERT INTO
            public.inv_venta_anulacion_movimientos (
                venta_detalle_id,
                movimiento_id
            )
        VALUES (
            v_detalle.id,
            v_movimiento_id
        );
    END LOOP;

    IF v_total_detalles = 0 THEN
        RAISE EXCEPTION
            'La venta no tiene detalles';
    END IF;

    -- 8. Marcar venta como anulada
    UPDATE public.inv_ventas
    SET
        estado = 'anulada',
        anulada_en = now(),
        anulada_por = v_usuario,
        motivo_anulacion =
            pg_catalog.btrim(p_motivo)
    WHERE id = p_venta_id;

    RETURN p_venta_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_bloquear_entrada_proveedor()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_incremento integer;
BEGIN
    IF NEW.location_id = 4 THEN

        IF TG_OP = 'INSERT' THEN
            v_incremento := NEW.cantidad;
        ELSE
            v_incremento := NEW.cantidad - OLD.cantidad;
        END IF;

        IF v_incremento > 0 THEN
            IF NOT inv_private.consumir_autorizacion_reparacion(
                NEW.item_id,
                v_incremento,
                'envio'
            ) THEN
                RAISE EXCEPTION
                'Proveedor/Taller bloqueado: envío no autorizado';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_bloquear_ruta_general_proveedor()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.origen = 4 OR NEW.destino = 4 THEN
    RAISE EXCEPTION 'Proveedor/Taller: usa exclusivamente el módulo de reparaciones';
  END IF;
  RETURN NEW;
END; $function$
;

CREATE OR REPLACE FUNCTION public.inv_bloquear_salida_garantia()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_op uuid; v_id uuid;
BEGIN
 IF OLD.location_id = 3 AND NEW.cantidad < OLD.cantidad THEN
   BEGIN
     v_op := NULLIF(current_setting('inv_private.operacion_garantia',true),'')::uuid;
   EXCEPTION WHEN invalid_text_representation THEN v_op := NULL;
   END;
   DELETE FROM inv_private.garantia_autorizaciones a
   WHERE a.id = (
      SELECT g.id FROM inv_private.garantia_autorizaciones g
      WHERE g.item_id = OLD.item_id AND g.cantidad = OLD.cantidad-NEW.cantidad
        AND g.transaccion_id = txid_current() AND g.backend_pid = pg_backend_pid()
        AND g.usuario = auth.uid() AND g.operacion_id = v_op
        AND (g.destino IN (1,2) OR (
          g.destino = 4 AND EXISTS (
            SELECT 1 FROM inv_private.reparacion_autorizaciones r
            JOIN public.inv_reparaciones c ON c.id = r.reparacion_id
            WHERE r.operacion_id = v_op AND r.operacion = 'envio'
              AND r.item_id = OLD.item_id AND r.cantidad = OLD.cantidad-NEW.cantidad
              AND r.usuario = auth.uid() AND r.transaccion_id = txid_current()
              AND r.backend_pid = pg_backend_pid() AND c.estado = 'pendiente'
          )
        )) FOR UPDATE
   ) RETURNING a.id INTO v_id;
   IF v_id IS NULL THEN RAISE EXCEPTION 'Garantía bloqueada: autorización inválida'; END IF;
 END IF;
 RETURN NEW;
END; $function$
;

CREATE OR REPLACE FUNCTION public.inv_bloquear_salida_proveedor()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_operacion text;
BEGIN
    IF OLD.location_id = 4
       AND NEW.cantidad < OLD.cantidad THEN

        v_operacion :=
            current_setting(
                'inv_private.tipo_operacion_reparacion',
                true
            );

        IF v_operacion NOT IN ('recepcion', 'baja')
           OR v_operacion IS NULL THEN
            RAISE EXCEPTION
            'Proveedor/Taller bloqueado: operación inválida';
        END IF;

        IF NOT inv_private.consumir_autorizacion_reparacion(
            OLD.item_id,
            OLD.cantidad - NEW.cantidad,
            v_operacion
        ) THEN
            RAISE EXCEPTION
            'Proveedor/Taller bloqueado: salida no autorizada';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_buscar_clientes(p_busqueda text)
 RETURNS TABLE(id uuid, nombre text, dui_mostrado text, telefono text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_q text := pg_catalog.btrim(coalesce(p_busqueda,'')); v_digits text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF length(v_q)<3 OR length(v_q)>100 THEN RAISE EXCEPTION 'Escribe al menos 3 caracteres'; END IF;
 v_digits:=pg_catalog.regexp_replace(v_q,'[^0-9]','','g');
 RETURN QUERY SELECT c.id,c.nombre,
   CASE WHEN c.dui IS NULL THEN NULL ELSE '*****'||right(c.dui,5) END,
   c.telefono
 FROM public.inv_clientes c
 WHERE pg_catalog.strpos(lower(c.nombre),lower(v_q))>0
    OR (length(v_digits)>=4 AND pg_catalog.regexp_replace(c.dui,'[^0-9]','','g') LIKE v_digits||'%')
 ORDER BY c.nombre,c.id LIMIT 30;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_catalogo_articulos_contratos()
 RETURNS TABLE(id uuid, nombre text, categoria text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 RETURN QUERY SELECT i.id,i.nombre_original,i.categoria FROM public.inv_items i
 WHERE i.estado='activo' ORDER BY i.nombre_original LIMIT 2000;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_catalogo_vendedores()
 RETURNS TABLE(id uuid, nombre text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 RETURN QUERY SELECT v.id,v.nombre FROM public.inv_vendedores v WHERE v.activo=true ORDER BY v.nombre LIMIT 500;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_catalogo_vendedores_manual()
 RETURNS TABLE(id uuid, nombre text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.inv_members m
   WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 RETURN QUERY SELECT v.id,v.nombre FROM public.inv_vendedores_manual v
 WHERE v.activo=true ORDER BY v.nombre,v.id LIMIT 500;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_confirmar_contrato(p_contrato_id uuid, p_ubicaciones jsonb, p_client_op_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_contrato public.inv_contratos%ROWTYPE;
 v_linea jsonb;
 v_detalle public.inv_contrato_detalles%ROWTYPE;
 v_venta_lineas jsonb := '[]'::jsonb;
 v_venta_id uuid;
 v_ubicacion smallint;
 v_cantidad_lineas int;
 v_existing_venta uuid;
 v_total numeric := 0;
 v_prima numeric;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.inv_members m
  WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_contrato_id IS NULL OR p_client_op_id IS NULL THEN
  RAISE EXCEPTION 'Identificadores obligatorios'; END IF;
 -- Serializa confirmaciones concurrentes del mismo contrato.
 SELECT * INTO v_contrato FROM public.inv_contratos
 WHERE id=p_contrato_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Contrato no encontrado'; END IF;
 IF v_contrato.estado='confirmado' THEN
   IF v_contrato.venta_id IS NULL THEN RAISE EXCEPTION 'Contrato confirmado sin venta asociada'; END IF;
   -- Solo aceptar un reintento de la MISMA operación; no confundirlo con una nueva venta.
   IF NOT EXISTS(
     SELECT 1 FROM public.inv_ventas v
     WHERE v.id=v_contrato.venta_id AND v.client_op_id=p_client_op_id
   ) THEN RAISE EXCEPTION 'Contrato ya confirmado con otra operación'; END IF;
   -- No presentar una venta anulada como confirmación vigente.
   IF EXISTS(
     SELECT 1 FROM public.inv_ventas v
     WHERE v.id=v_contrato.venta_id AND v.anulada_en IS NOT NULL
   ) THEN RAISE EXCEPTION 'La venta asociada fue anulada; requiere revisión'; END IF;
   RETURN v_contrato.venta_id;
 END IF;
 IF v_contrato.estado<>'borrador' OR v_contrato.venta_id IS NOT NULL
 THEN RAISE EXCEPTION 'Contrato no disponible para confirmar'; END IF;
 -- Revalidar el vendedor al confirmar: pudo desactivarse después del borrador.
 IF NOT EXISTS(
   SELECT 1 FROM public.inv_vendedores_manual vm
   JOIN public.inv_vendedores v ON v.id=vm.id
   WHERE vm.id=v_contrato.vendedor_id AND vm.activo=true AND v.activo=true
 ) THEN RAISE EXCEPTION 'Vendedor manual inactivo o no registrado'; END IF;
 IF p_ubicaciones IS NULL OR pg_catalog.jsonb_typeof(p_ubicaciones)<>'array'
 THEN RAISE EXCEPTION 'Ubicaciones inválidas'; END IF;
 SELECT count(*) INTO v_cantidad_lineas
 FROM public.inv_contrato_detalles WHERE contrato_id=p_contrato_id;
 IF v_cantidad_lineas=0 OR v_cantidad_lineas>100 OR v_cantidad_lineas<>pg_catalog.jsonb_array_length(p_ubicaciones)
 THEN RAISE EXCEPTION 'Las ubicaciones deben coincidir con todas las líneas'; END IF;
 FOR v_linea IN SELECT value FROM pg_catalog.jsonb_array_elements(p_ubicaciones) LOOP
   IF pg_catalog.jsonb_typeof(v_linea)<>'object' THEN
     RAISE EXCEPTION 'Línea de ubicación inválida'; END IF;
   IF (v_linea->>'detalle_id') IS NULL OR (v_linea->>'location_id') IS NULL THEN
     RAISE EXCEPTION 'Faltan identificadores de línea o ubicación'; END IF;
   IF (v_linea->>'detalle_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
     RAISE EXCEPTION 'Identificador de línea inválido'; END IF;
   IF pg_catalog.jsonb_typeof(v_linea->'location_id')<>'number'
      OR (v_linea->>'location_id') !~ '^[12]$' THEN
     RAISE EXCEPTION 'Solo se permiten ubicaciones numéricas 1 y 2'; END IF;
   SELECT * INTO v_detalle FROM public.inv_contrato_detalles
   WHERE id=(v_linea->>'detalle_id')::uuid AND contrato_id=p_contrato_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Línea no pertenece al contrato'; END IF;
   IF EXISTS(
     SELECT 1 FROM pg_catalog.jsonb_array_elements(v_venta_lineas) j
     WHERE j.value->>'detalle_id'=v_detalle.id::text
   ) THEN RAISE EXCEPTION 'Línea de contrato repetida'; END IF;
   v_ubicacion:=(v_linea->>'location_id')::smallint;
   v_total:=v_total+v_detalle.cantidad*v_detalle.precio_credito_unitario;
   v_venta_lineas:=v_venta_lineas||pg_catalog.jsonb_build_array(
     pg_catalog.jsonb_build_object(
       'detalle_id',v_detalle.id,
       'item_id',v_detalle.item_id,
       'location_id',v_ubicacion,
       'cantidad',v_detalle.cantidad,
       'precio_unitario',v_detalle.precio_credito_unitario,
       'descuento',0
     )
   );
 END LOOP;
 SELECT p.monto INTO v_prima FROM public.inv_contrato_primas p
 WHERE p.contrato_id=p_contrato_id;
 IF v_prima IS NULL THEN RAISE EXCEPTION 'El contrato no tiene prima registrada'; END IF;
 IF v_total>999999999999.99 THEN RAISE EXCEPTION 'El total supera el límite permitido'; END IF;
 IF v_prima<0 OR v_prima>v_total THEN RAISE EXCEPTION 'La prima no es válida para el total del contrato'; END IF;
 IF v_contrato.saldo_inicial IS NOT NULL
   AND v_contrato.saldo_inicial<>v_total-v_prima THEN
   RAISE EXCEPTION 'El saldo inicial no coincide con total menos prima'; END IF;
 -- Serializa también operaciones con el mismo ID, incluso de contratos distintos.
 PERFORM pg_catalog.pg_advisory_xact_lock(
   pg_catalog.hashtextextended(p_client_op_id::text,0)
 );
 -- La venta debe ser nueva: no enlazar una venta anterior a este contrato.
 -- El bloqueo de contrato hace idempotente la repetición posterior.
 SELECT v.id INTO v_existing_venta FROM public.inv_ventas v
 WHERE v.client_op_id=p_client_op_id;
 IF v_existing_venta IS NOT NULL THEN
   RAISE EXCEPTION 'Identificador de operación utilizado anteriormente';
 END IF;
 -- Reutiliza la función de ventas existente, con control de existencias,
 -- movimientos y deduplicación por client_op_id.
 v_venta_id:=public.inv_registrar_venta(
   v_contrato.vendedor_id,
   v_contrato.modalidad,
   v_venta_lineas,
   0,
   'Contrato '||v_contrato.numero,
   p_client_op_id
 );
 UPDATE public.inv_contratos
 SET estado='confirmado',venta_id=v_venta_id,actualizado_en=now()
 WHERE id=p_contrato_id;
 RETURN v_venta_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_crear_cliente(p_nombre text, p_dui text DEFAULT NULL::text, p_direccion text DEFAULT NULL::text, p_ubicacion text DEFAULT NULL::text, p_telefono text DEFAULT NULL::text, p_vivienda text DEFAULT NULL::text, p_lugar_trabajo text DEFAULT NULL::text, p_telefono_trabajo text DEFAULT NULL::text, p_referencias jsonb DEFAULT '[]'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_id uuid; v_dui text; v_ref jsonb; v_n int:=0;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF length(pg_catalog.btrim(coalesce(p_nombre,''))) NOT BETWEEN 2 AND 200 THEN RAISE EXCEPTION 'Nombre inválido'; END IF;
 IF p_dui IS NOT NULL AND pg_catalog.btrim(p_dui)<>'' AND
    pg_catalog.btrim(p_dui) !~ '^[0-9]{9}$|^[0-9]{8}-[0-9]$' THEN
   RAISE EXCEPTION 'DUI inválido'; END IF;
 v_dui:=NULLIF(pg_catalog.regexp_replace(coalesce(p_dui,''),'[^0-9]','','g'),'');
 IF v_dui IS NOT NULL THEN
   IF length(v_dui)<>9 THEN RAISE EXCEPTION 'DUI inválido'; END IF;
   v_dui:=left(v_dui,8)||'-'||right(v_dui,1);
 END IF;
 IF p_vivienda IS NOT NULL AND p_vivienda NOT IN ('alquila','propia') THEN RAISE EXCEPTION 'Vivienda inválida'; END IF;
 IF p_referencias IS NULL OR pg_catalog.jsonb_typeof(p_referencias)<>'array' OR pg_catalog.jsonb_array_length(p_referencias)>2
 THEN RAISE EXCEPTION 'Se admiten hasta dos referencias'; END IF;
 INSERT INTO public.inv_clientes(nombre,dui,direccion,ubicacion,telefono,vivienda,lugar_trabajo,telefono_trabajo)
 VALUES(pg_catalog.btrim(p_nombre),v_dui,NULLIF(pg_catalog.btrim(p_direccion),''),
 NULLIF(pg_catalog.btrim(p_ubicacion),''),NULLIF(pg_catalog.btrim(p_telefono),''),
 p_vivienda,NULLIF(pg_catalog.btrim(p_lugar_trabajo),''),NULLIF(pg_catalog.btrim(p_telefono_trabajo),''))
 RETURNING id INTO v_id;
 FOR v_ref IN SELECT value FROM pg_catalog.jsonb_array_elements(p_referencias) LOOP
   v_n:=v_n+1;
   IF pg_catalog.jsonb_typeof(v_ref)<>'object'
      OR length(pg_catalog.btrim(coalesce(v_ref->>'nombre',''))) NOT BETWEEN 2 AND 200
   THEN RAISE EXCEPTION 'Referencia % inválida',v_n; END IF;
   INSERT INTO public.inv_cliente_referencias(cliente_id,orden,nombre,telefono,direccion,parentesco)
   VALUES(v_id,v_n,pg_catalog.btrim(v_ref->>'nombre'),v_ref->>'telefono',v_ref->>'direccion',v_ref->>'parentesco');
 END LOOP;
 RETURN v_id;
EXCEPTION WHEN unique_violation THEN
 RAISE EXCEPTION 'Ya existe un cliente con ese DUI';
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_crear_contrato_borrador(p_numero text, p_cliente_id uuid, p_vendedor_id uuid, p_fecha date, p_modalidad text, p_frecuencia text, p_plan text, p_cuota numeric, p_saldo_inicial numeric, p_fecha_plan date, p_ruta text, p_dia_cobro text, p_receptor_alterno text, p_comision numeric, p_prima numeric, p_prima_recibida boolean, p_detalles jsonb, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_id uuid;v_line jsonb;v_item uuid;v_cantidad int;v_precio numeric;v_comision numeric;
 v_total numeric:=0;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF length(pg_catalog.btrim(coalesce(p_numero,''))) NOT BETWEEN 1 AND 80
 OR p_cliente_id IS NULL OR p_vendedor_id IS NULL OR p_fecha IS NULL
 THEN RAISE EXCEPTION 'Datos principales incompletos'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.inv_clientes WHERE id=p_cliente_id)
 OR NOT EXISTS(SELECT 1 FROM public.inv_vendedores_manual vm
   JOIN public.inv_vendedores v ON v.id=vm.id
   WHERE vm.id=p_vendedor_id AND vm.activo=true AND v.activo=true)
 THEN RAISE EXCEPTION 'Cliente o vendedor inválido'; END IF;
 IF p_modalidad NOT IN ('credito','contado') OR p_modalidad IS NULL
 OR p_plan NOT IN ('normal','3_pagos','6_pagos') OR p_plan IS NULL
 OR (p_frecuencia IS NOT NULL AND p_frecuencia NOT IN ('semanal','quincenal','mensual'))
 THEN RAISE EXCEPTION 'Modalidad o plan inválido'; END IF;
 IF p_comision IS NULL OR p_comision<0 OR p_prima IS NULL OR p_prima<0
 OR p_comision>999999999999.99 OR p_prima>999999999999.99
 OR p_comision<>pg_catalog.round(p_comision,2) OR p_prima<>pg_catalog.round(p_prima,2)
 OR p_prima_recibida IS NULL
 THEN RAISE EXCEPTION 'Comisión o prima inválida'; END IF;
 IF (p_cuota IS NOT NULL AND (p_cuota<0 OR p_cuota>999999999999.99 OR p_cuota<>pg_catalog.round(p_cuota,2)))
 OR (p_saldo_inicial IS NOT NULL AND (p_saldo_inicial<0 OR p_saldo_inicial>999999999999.99 OR p_saldo_inicial<>pg_catalog.round(p_saldo_inicial,2)))
 THEN RAISE EXCEPTION 'Cuota o saldo inicial inválido'; END IF;
 IF p_detalles IS NULL OR pg_catalog.jsonb_typeof(p_detalles)<>'array'
 OR pg_catalog.jsonb_array_length(p_detalles) NOT BETWEEN 1 AND 100
 THEN RAISE EXCEPTION 'Agrega entre 1 y 100 líneas'; END IF;
 INSERT INTO public.inv_contratos(numero,cliente_id,vendedor_id,fecha,modalidad,frecuencia,plan,cuota,saldo_inicial,
 fecha_plan,ruta,dia_cobro,receptor_alterno,comision_total,observaciones)
 VALUES(pg_catalog.btrim(p_numero),p_cliente_id,p_vendedor_id,p_fecha,p_modalidad,p_frecuencia,p_plan,p_cuota,p_saldo_inicial,
 p_fecha_plan,p_ruta,p_dia_cobro,p_receptor_alterno,p_comision,p_observaciones) RETURNING id INTO v_id;
 FOR v_line IN SELECT value FROM pg_catalog.jsonb_array_elements(p_detalles) LOOP
   IF pg_catalog.jsonb_typeof(v_line)<>'object' THEN RAISE EXCEPTION 'Línea inválida'; END IF;
   IF pg_catalog.jsonb_typeof(v_line->'item_id')<>'string'
      OR (v_line->>'item_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
   THEN RAISE EXCEPTION 'Identificador de artículo inválido'; END IF;
   IF pg_catalog.jsonb_typeof(v_line->'cantidad')<>'number'
      OR (v_line->>'cantidad') !~ '^[1-9][0-9]*$'
      OR length(v_line->>'cantidad')>9
   THEN RAISE EXCEPTION 'Cantidad debe ser un entero positivo'; END IF;
   IF pg_catalog.jsonb_typeof(v_line->'precio_credito_unitario')<>'number'
      OR (v_line ? 'comision_linea' AND pg_catalog.jsonb_typeof(v_line->'comision_linea')<>'number')
      OR (v_line->>'precio_credito_unitario') !~ '^[0-9]+([.][0-9]+)?$'
      OR (v_line ? 'comision_linea' AND (v_line->>'comision_linea') !~ '^[0-9]+([.][0-9]+)?$')
   THEN RAISE EXCEPTION 'Importes de artículo inválidos'; END IF;
   v_item:=(v_line->>'item_id')::uuid;
   v_cantidad:=(v_line->>'cantidad')::integer;
   v_precio:=(v_line->>'precio_credito_unitario')::numeric;
   v_comision:=coalesce((v_line->>'comision_linea')::numeric,0);
   IF v_item IS NULL OR NOT EXISTS(SELECT 1 FROM public.inv_items WHERE id=v_item AND estado='activo')
   OR v_cantidad IS NULL OR v_cantidad<=0 OR v_precio IS NULL OR v_precio<0
   OR v_comision<0 OR v_precio>999999999999.99 OR v_comision>999999999999.99
   OR v_precio<>pg_catalog.round(v_precio,2) OR v_comision<>pg_catalog.round(v_comision,2)
   THEN RAISE EXCEPTION 'Artículo, cantidad o importe inválido'; END IF;
   v_total:=v_total+v_cantidad*v_precio;
   IF v_total>999999999999.99 THEN
     RAISE EXCEPTION 'El total del contrato supera el límite permitido'; END IF;
   INSERT INTO public.inv_contrato_detalles(contrato_id,item_id,cantidad,precio_credito_unitario,comision_linea)
   VALUES(v_id,v_item,v_cantidad,v_precio,v_comision);
 END LOOP;
 IF p_prima>v_total THEN RAISE EXCEPTION 'La prima supera el valor del contrato'; END IF;
 IF p_saldo_inicial IS NOT NULL AND p_saldo_inicial<>v_total-p_prima THEN
   RAISE EXCEPTION 'El saldo inicial no coincide con el total menos la prima'; END IF;
 INSERT INTO public.inv_contrato_primas(contrato_id,monto,estado,fecha_recibida,registrado_por)
 VALUES(v_id,p_prima,CASE WHEN p_prima_recibida THEN 'recibida' ELSE 'pendiente' END,
 CASE WHEN p_prima_recibida THEN now() ELSE NULL END,auth.uid());
 INSERT INTO public.inv_prima_eventos(prima_id,estado_anterior,estado_nuevo,usuario,observaciones)
 SELECT id,NULL,estado,auth.uid(),'Registro inicial de prima'
 FROM public.inv_contrato_primas WHERE contrato_id=v_id;
 RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_crear_recepcion(p_proveedor text, p_referencia text, p_fecha date, p_observaciones text, p_detalles jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_id uuid; v_line jsonb; v_item uuid; v_loc smallint; v_qty integer; v_count integer:=0;
begin
 if v_uid is null or not exists(select 1 from public.inv_members where user_id=v_uid and rol in ('admin','secretaria')) then raise exception 'Usuario sin autorización'; end if;
 if length(pg_catalog.btrim(coalesce(p_proveedor,''))) not between 2 and 200 or length(pg_catalog.btrim(coalesce(p_referencia,''))) not between 1 and 120 then raise exception 'Proveedor o referencia inválidos'; end if;
 if p_fecha is null or p_detalles is null or jsonb_typeof(p_detalles)<>'array' or jsonb_array_length(p_detalles) not between 1 and 100 then raise exception 'La recepción requiere entre 1 y 100 artículos'; end if;
 if length(coalesce(p_observaciones,''))>1000 then raise exception 'Observaciones demasiado largas'; end if;
 insert into public.inv_recepciones(proveedor,referencia,fecha_recepcion,observaciones,solicitado_por)
 values(pg_catalog.btrim(p_proveedor),pg_catalog.btrim(p_referencia),p_fecha,nullif(pg_catalog.btrim(p_observaciones),''),v_uid) returning id into v_id;
 for v_line in select value from jsonb_array_elements(p_detalles) loop
  if jsonb_typeof(v_line)<>'object' or not(v_line ? 'item_id' and v_line ? 'location_id' and v_line ? 'cantidad') then raise exception 'Línea inválida'; end if;
  v_item:=(v_line->>'item_id')::uuid;v_loc:=(v_line->>'location_id')::smallint;v_qty:=(v_line->>'cantidad')::integer;
  if v_qty is null or v_qty<1 or v_loc not in (1,2) or not exists(select 1 from public.inv_items where id=v_item and estado='activo') then raise exception 'Artículo, cantidad o destino inválido'; end if;
  insert into public.inv_recepcion_detalles(recepcion_id,item_id,location_id,cantidad) values(v_id,v_item,v_loc,v_qty);
  v_count:=v_count+1;
 end loop;
 return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.inv_crear_reparacion(p_item_id uuid, p_cantidad integer, p_destino_tipo text, p_destino_nombre text, p_motivo text, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid := auth.uid();
    v_rol text;
    v_reparacion_id uuid;
BEGIN
    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'Cantidad inválida';
    END IF;

    IF p_destino_tipo IS NULL
       OR p_destino_tipo NOT IN ('proveedor', 'taller') THEN
        RAISE EXCEPTION 'Tipo de destino inválido';
    END IF;

    IF NULLIF(btrim(p_destino_nombre), '') IS NULL THEN
        RAISE EXCEPTION 'Indica el proveedor o taller';
    END IF;

    IF NULLIF(btrim(p_motivo), '') IS NULL THEN
        RAISE EXCEPTION 'Indica el motivo de la reparación';
    END IF;

    PERFORM 1
    FROM public.inv_items
    WHERE id = p_item_id
      AND estado = 'activo';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Artículo no disponible';
    END IF;

    INSERT INTO public.inv_reparaciones (
        item_id,
        cantidad,
        destino_tipo,
        destino_nombre,
        estado,
        motivo,
        observaciones,
        registrado_por
    )
    VALUES (
        p_item_id,
        p_cantidad,
        p_destino_tipo,
        btrim(p_destino_nombre),
        'pendiente',
        btrim(p_motivo),
        NULLIF(btrim(p_observaciones), ''),
        v_usuario
    )
    RETURNING id INTO v_reparacion_id;

    RETURN v_reparacion_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_crear_vendedor(p_nombre text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_rol text;
    v_nombre text;
    v_id uuid;
BEGIN
    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = auth.uid();

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION
            'No tienes permiso para crear vendedores';
    END IF;

    v_nombre := btrim(p_nombre);

    IF v_nombre IS NULL
       OR length(v_nombre) = 0 THEN
        RAISE EXCEPTION
            'Debes indicar el nombre del vendedor';
    END IF;

    IF length(v_nombre) > 150 THEN
        RAISE EXCEPTION
            'El nombre no puede superar 150 caracteres';
    END IF;

    INSERT INTO public.inv_vendedores (
        nombre
    )
    VALUES (
        v_nombre
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_crear_vendedor_manual(p_nombre text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_id uuid := pg_catalog.gen_random_uuid();
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.inv_members m
   WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_nombre IS NULL OR length(pg_catalog.btrim(p_nombre)) NOT BETWEEN 2 AND 200
 THEN RAISE EXCEPTION 'Nombre de vendedor inválido'; END IF;
 -- Inserción dual ATÓMICA: la misma identidad satisface el FK de contratos y ventas.
 -- No se copian ni modifican vendedores históricos ni artículos del inventario.
 INSERT INTO public.inv_vendedores(id,nombre,activo)
 VALUES(v_id,pg_catalog.btrim(p_nombre),true);
 INSERT INTO public.inv_vendedores_manual(id,nombre,creado_por)
 VALUES(v_id,pg_catalog.btrim(p_nombre),auth.uid());
 RETURN v_id;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_detalle_contrato(p_contrato_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_result jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members m WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 SELECT pg_catalog.jsonb_build_object(
 'id',c.id,'numero',c.numero,'fecha',c.fecha,'estado',c.estado,
 'cliente_id',c.cliente_id,'vendedor_id',c.vendedor_id,'venta_id',c.venta_id,
 'modalidad',c.modalidad,'frecuencia',c.frecuencia,'plan',c.plan,
 'cuota',c.cuota,'saldo_inicial',c.saldo_inicial,'fecha_plan',c.fecha_plan,
 'ruta',c.ruta,'dia_cobro',c.dia_cobro,'receptor_alterno',c.receptor_alterno,
 'comision_total',c.comision_total,'comision_estado',c.comision_estado,
 'observaciones',c.observaciones,
 'articulos',COALESCE((
 SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
 'detalle_id',d.id,'item_id',d.item_id,'nombre',i.nombre_original,'cantidad',d.cantidad,
 'precio_credito_unitario',d.precio_credito_unitario,'comision_linea',d.comision_linea
 ) ORDER BY d.id)
 FROM public.inv_contrato_detalles d
 JOIN public.inv_items i ON i.id=d.item_id WHERE d.contrato_id=c.id
 ),'[]'::jsonb),
 'prima',(
 SELECT pg_catalog.jsonb_build_object('monto',p.monto,'estado',p.estado,
 'fecha_recibida',p.fecha_recibida,'registrado_por',p.registrado_por)
 FROM public.inv_contrato_primas p WHERE p.contrato_id=c.id
 )
 ) INTO v_result FROM public.inv_contratos c WHERE c.id=p_contrato_id;
 IF v_result IS NULL THEN RAISE EXCEPTION 'Contrato no encontrado'; END IF;
 RETURN v_result;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_enviar_reparacion(p_reparacion_id uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 c public.inv_reparaciones%ROWTYPE;
 v_user uuid := auth.uid();
 v_stock int;
 v_op uuid := gen_random_uuid();
 v_mov bigint;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.inv_members WHERE user_id=v_user AND rol IN ('admin','secretaria'))
 THEN RAISE EXCEPTION 'No autorizado'; END IF;
 SELECT * INTO c FROM public.inv_reparaciones WHERE id=p_reparacion_id FOR UPDATE;
 IF NOT FOUND OR c.estado <> 'pendiente' THEN RAISE EXCEPTION 'Reparación no pendiente'; END IF;
 PERFORM 1 FROM public.inv_items WHERE id=c.item_id AND estado='activo' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Artículo no disponible'; END IF;
 SELECT cantidad INTO v_stock FROM public.inv_stock WHERE item_id=c.item_id AND location_id=3 FOR UPDATE;
 IF COALESCE(v_stock,0)<c.cantidad THEN RAISE EXCEPTION 'Existencias insuficientes en Garantía'; END IF;
 INSERT INTO inv_private.reparacion_autorizaciones
 (reparacion_id,item_id,cantidad,operacion,usuario,transaccion_id,backend_pid,operacion_id)
 VALUES(c.id,c.item_id,c.cantidad,'envio',v_user,txid_current(),pg_backend_pid(),v_op);
 INSERT INTO inv_private.garantia_autorizaciones
 (item_id,cantidad,destino,usuario,transaccion_id,backend_pid,operacion_id)
 VALUES(c.item_id,c.cantidad,4,v_user,txid_current(),pg_backend_pid(),v_op);
 INSERT INTO inv_private.reparacion_movimientos_autorizados
 (operacion_id,reparacion_id,item_id,cantidad,origen,destino,usuario,transaccion_id,backend_pid)
 VALUES(v_op,c.id,c.item_id,c.cantidad,3,4,v_user,txid_current(),pg_backend_pid());
 PERFORM set_config('inv_private.operacion_garantia',v_op::text,true);
 PERFORM set_config('inv_private.operacion_reparacion',v_op::text,true);
 UPDATE public.inv_stock SET cantidad=cantidad-c.cantidad WHERE item_id=c.item_id AND location_id=3;
 -- UPDATE existing provider stock directly; ON CONFLICT upsert fired both INSERT and UPDATE triggers.
 UPDATE public.inv_stock SET cantidad=cantidad+c.cantidad
 WHERE item_id=c.item_id AND location_id=4;
 IF NOT FOUND THEN
   INSERT INTO public.inv_stock(item_id,location_id,cantidad) VALUES(c.item_id,4,c.cantidad);
 END IF;
 INSERT INTO public.inv_movements(client_op_id,item_id,tipo,origen,destino,cantidad,fecha,observaciones,usuario)
 VALUES(v_op,c.item_id,'traslado',3,4,c.cantidad,CURRENT_DATE,
        'ENVÍO REPARACIÓN '||c.id::text||' - '||c.destino_nombre,v_user) RETURNING id INTO v_mov;
 UPDATE public.inv_reparaciones SET estado='enviado',fecha_envio=now(),
 fecha_actualizacion=now(),actualizado_por=v_user WHERE id=c.id;
 PERFORM set_config('inv_private.operacion_garantia','',true);
 PERFORM set_config('inv_private.operacion_reparacion','',true);
 RETURN v_mov;
END; $function$
;

CREATE OR REPLACE FUNCTION public.inv_ficha_cliente(p_cliente_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_ficha jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 SELECT pg_catalog.jsonb_build_object(
 'id',c.id,'nombre',c.nombre,'dui',c.dui,'direccion',c.direccion,
 'ubicacion',c.ubicacion,'telefono',c.telefono,'vivienda',c.vivienda,
 'lugar_trabajo',c.lugar_trabajo,'telefono_trabajo',c.telefono_trabajo,
 'referencias',COALESCE((
  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'orden',r.orden,'nombre',r.nombre,'telefono',r.telefono,
    'direccion',r.direccion,'parentesco',r.parentesco
  ) ORDER BY r.orden)
  FROM public.inv_cliente_referencias r WHERE r.cliente_id=c.id
 ),'[]'::jsonb)
 ) INTO v_ficha
 FROM public.inv_clientes c WHERE c.id=p_cliente_id;
 IF v_ficha IS NULL THEN RAISE EXCEPTION 'Cliente no encontrado'; END IF;
 RETURN v_ficha;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_historial_cliente(p_cliente_id uuid)
 RETURNS TABLE(contrato_id uuid, numero text, fecha date, estado text, modalidad text, vendedor_nombre text, total_articulos numeric, prima numeric, prima_estado text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members m WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_cliente_id IS NULL OR NOT EXISTS(SELECT 1 FROM public.inv_clientes c WHERE c.id=p_cliente_id)
 THEN RAISE EXCEPTION 'Cliente no encontrado'; END IF;
 RETURN QUERY
 SELECT c.id,c.numero,c.fecha,c.estado,c.modalidad,v.nombre,
 COALESCE((SELECT sum(d.cantidad*d.precio_credito_unitario)
 FROM public.inv_contrato_detalles d WHERE d.contrato_id=c.id),0)::numeric,
 COALESCE(p.monto,0)::numeric,COALESCE(p.estado,'pendiente')
 FROM public.inv_contratos c
 JOIN public.inv_vendedores v ON v.id=c.vendedor_id
 LEFT JOIN public.inv_contrato_primas p ON p.contrato_id=c.id
 WHERE c.cliente_id=p_cliente_id ORDER BY c.fecha DESC,c.id DESC LIMIT 500;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_historial_vendedor(p_vendedor_id uuid, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date)
 RETURNS TABLE(contrato_id uuid, numero text, fecha date, cliente_nombre text, estado text, modalidad text, total_articulos numeric, comision numeric, comision_estado text, prima numeric, prima_estado text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.inv_members m
  WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_vendedor_id IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.inv_vendedores_manual v WHERE v.id=p_vendedor_id
 ) THEN RAISE EXCEPTION 'Vendedor inexistente'; END IF;
 IF p_desde IS NOT NULL AND p_hasta IS NOT NULL AND p_desde>p_hasta
 THEN RAISE EXCEPTION 'Rango de fechas inválido'; END IF;

 RETURN QUERY
 SELECT c.id,c.numero,c.fecha,cl.nombre,c.estado,c.modalidad,
   COALESCE((SELECT sum(d.cantidad*d.precio_credito_unitario)
             FROM public.inv_contrato_detalles d WHERE d.contrato_id=c.id),0)::numeric,
   c.comision_total,c.comision_estado,
   COALESCE(pr.monto,0)::numeric,
   COALESCE(pr.estado,'pendiente')
 FROM public.inv_contratos c
 JOIN public.inv_clientes cl ON cl.id=c.cliente_id
 LEFT JOIN public.inv_contrato_primas pr ON pr.contrato_id=c.id
 WHERE c.vendedor_id=p_vendedor_id
 AND (p_desde IS NULL OR c.fecha>=p_desde)
 AND (p_hasta IS NULL OR c.fecha<=p_hasta)
 ORDER BY c.fecha DESC,c.id DESC
 LIMIT 500;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_inmutabilidad_movimientos()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 RAISE EXCEPTION 'Los movimientos registrados no pueden editarse';
END; $function$
;

CREATE OR REPLACE FUNCTION public.inv_liberar_garantia(p_item_id uuid, p_destino smallint, p_cantidad integer, p_observaciones text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid := auth.uid();
    v_rol text;
    v_existencia integer;
    v_movimiento_id bigint;
    v_operacion_id uuid := gen_random_uuid();
    v_destino_final smallint;
    v_cantidad_final integer;
BEGIN
    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION 'No autorizado';
    END IF;

    IF p_destino IS NULL OR p_destino NOT IN (1, 2) THEN
        RAISE EXCEPTION 'Destino inválido';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'Cantidad inválida';
    END IF;

    IF NULLIF(btrim(p_observaciones), '') IS NULL THEN
        RAISE EXCEPTION 'Indica el resultado de la revisión';
    END IF;

    PERFORM 1
    FROM public.inv_items
    WHERE id = p_item_id
      AND estado = 'activo'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Artículo no disponible';
    END IF;

    SELECT cantidad INTO v_existencia
    FROM public.inv_stock
    WHERE item_id = p_item_id
      AND location_id = 3
    FOR UPDATE;

    IF COALESCE(v_existencia, 0) < p_cantidad THEN
        RAISE EXCEPTION 'Existencias insuficientes en Garantía';
    END IF;

    INSERT INTO inv_private.garantia_autorizaciones (
        item_id,
        cantidad,
        destino,
        usuario,
        transaccion_id,
        backend_pid,
        operacion_id
    )
    VALUES (
        p_item_id,
        p_cantidad,
        p_destino,
        v_usuario,
        txid_current(),
        pg_backend_pid(),
        v_operacion_id
    );

    PERFORM set_config(
        'inv_private.operacion_garantia',
        v_operacion_id::text,
        true
    );

    UPDATE public.inv_stock
    SET cantidad = cantidad - p_cantidad
    WHERE item_id = p_item_id
      AND location_id = 3;

    INSERT INTO public.inv_stock (
        item_id, location_id, cantidad
    )
    VALUES (
        p_item_id, p_destino, p_cantidad
    )
    ON CONFLICT (item_id, location_id)
    DO UPDATE SET
        cantidad = public.inv_stock.cantidad
                 + EXCLUDED.cantidad;

    INSERT INTO public.inv_movements (
        client_op_id,
        item_id,
        tipo,
        origen,
        destino,
        cantidad,
        fecha,
        observaciones,
        usuario
    )
    VALUES (
        v_operacion_id,
        p_item_id,
        'traslado',
        3,
        p_destino,
        p_cantidad,
        CURRENT_DATE,
        'LIBERACIÓN DE GARANTÍA: ' || btrim(p_observaciones),
        v_usuario
    )
    RETURNING id INTO v_movimiento_id;

    SELECT destino, cantidad
    INTO v_destino_final, v_cantidad_final
    FROM public.inv_movements
    WHERE id = v_movimiento_id
      AND client_op_id = v_operacion_id
      AND item_id = p_item_id
      AND tipo = 'traslado'
      AND origen = 3
      AND usuario = v_usuario;

    IF v_destino_final IS DISTINCT FROM p_destino
       OR v_cantidad_final IS DISTINCT FROM p_cantidad THEN
        RAISE EXCEPTION
            'La liberación no coincide con la autorización';
    END IF;

    PERFORM set_config(
        'inv_private.operacion_garantia',
        '',
        true
    );

    RETURN v_movimiento_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_marcar_prima_recibida(p_contrato_id uuid, p_observaciones text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_prima uuid;v_estado text;v_contrato_estado text;v_venta_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF NULLIF(pg_catalog.btrim(coalesce(p_observaciones,'')),'') IS NULL THEN RAISE EXCEPTION 'Indica cómo se entregó la prima'; END IF;
 -- Mismo orden de bloqueo que inv_confirmar_contrato: contrato antes de prima.
 -- Impide marcar una prima después de anular el contrato y evita carreras.
 SELECT estado,venta_id INTO v_contrato_estado,v_venta_id FROM public.inv_contratos
 WHERE id=p_contrato_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Contrato no encontrado'; END IF;
 IF v_contrato_estado='anulado' THEN
   RAISE EXCEPTION 'No se puede recibir prima de un contrato anulado'; END IF;
 IF v_venta_id IS NOT NULL AND EXISTS (
   SELECT 1 FROM public.inv_ventas v
   WHERE v.id=v_venta_id AND v.anulada_en IS NOT NULL
 ) THEN RAISE EXCEPTION 'La venta asociada fue anulada; revisar prima'; END IF;
 SELECT id,estado INTO v_prima,v_estado FROM public.inv_contrato_primas
 WHERE contrato_id=p_contrato_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Prima no encontrada'; END IF;
 IF v_estado='recibida' THEN RAISE EXCEPTION 'La prima ya fue registrada como recibida'; END IF;
 UPDATE public.inv_contrato_primas SET estado='recibida',fecha_recibida=now(),actualizado_en=now() WHERE id=v_prima;
 INSERT INTO public.inv_prima_eventos(prima_id,estado_anterior,estado_nuevo,usuario,observaciones)
 VALUES(v_prima,'pendiente','recibida',auth.uid(),pg_catalog.btrim(p_observaciones));
 RETURN true;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_rechazar_movimiento_normal_proveedor()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
    IF NEW.origen = 4 OR NEW.destino = 4 THEN
        IF NOT EXISTS (
            SELECT 1
            FROM inv_private.reparacion_movimientos_autorizados a
            WHERE a.item_id = NEW.item_id
              AND a.cantidad = NEW.cantidad
              AND a.origen IS NOT DISTINCT FROM NEW.origen
              AND a.destino IS NOT DISTINCT FROM NEW.destino
              AND a.usuario = auth.uid()
              AND a.transaccion_id = txid_current()
              AND a.backend_pid = pg_backend_pid()
        ) THEN
            RAISE EXCEPTION
                'Proveedor/Taller: movimiento no autorizado';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_registrar_movimiento(p_item_id uuid, p_tipo text, p_origen smallint, p_destino smallint, p_cantidad integer, p_vendedor text DEFAULT NULL::text, p_observaciones text DEFAULT NULL::text, p_client_op_id uuid DEFAULT NULL::uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid;
    v_rol text;
    v_estado text;
    v_existencia integer;
    v_movimiento_id bigint;
    v_op_id uuid;
BEGIN
    IF p_origen = 4 OR p_destino = 4 THEN
      RAISE EXCEPTION 'Proveedor/Taller reservado para reparaciones';
    END IF;

    v_usuario := auth.uid();

    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION 'No tienes permiso para registrar movimientos';
    END IF;

    IF p_tipo IS NULL OR p_tipo NOT IN ('salida', 'traslado') THEN
        RAISE EXCEPTION 'Tipo de movimiento no permitido';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor que cero';
    END IF;

    IF p_origen IS NULL THEN
        RAISE EXCEPTION 'Debes indicar la ubicación de origen';
    END IF;

    IF p_tipo = 'salida' AND p_destino IS NOT NULL THEN
        RAISE EXCEPTION 'Una salida no debe tener destino interno';
    END IF;

    IF p_tipo = 'traslado'
       AND (p_destino IS NULL OR p_destino = p_origen) THEN
        RAISE EXCEPTION 'Selecciona un destino diferente al origen';
    END IF;

    SELECT estado INTO v_estado
    FROM public.inv_items
    WHERE id = p_item_id;

    IF v_estado IS DISTINCT FROM 'activo' THEN
        RAISE EXCEPTION 'El artículo no existe o no está activo';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.inv_locations
        WHERE id = p_origen
    ) THEN
        RAISE EXCEPTION 'Ubicación de origen inválida';
    END IF;

    IF p_tipo = 'traslado' AND NOT EXISTS (
        SELECT 1 FROM public.inv_locations
        WHERE id = p_destino
    ) THEN
        RAISE EXCEPTION 'Ubicación de destino inválida';
    END IF;

    -- Serializar operaciones sobre el mismo artículo.
    PERFORM 1
    FROM public.inv_items
    WHERE id = p_item_id
    FOR UPDATE;

    -- Identificador para evitar operaciones duplicadas.
    v_op_id := COALESCE(p_client_op_id, gen_random_uuid());

    IF EXISTS (
        SELECT 1 FROM public.inv_movements
        WHERE client_op_id = v_op_id
    ) THEN
        RAISE EXCEPTION 'Esta operación ya fue registrada';
    END IF;

    SELECT cantidad INTO v_existencia
    FROM public.inv_stock
    WHERE item_id = p_item_id
      AND location_id = p_origen
    FOR UPDATE;

    IF COALESCE(v_existencia, 0) < p_cantidad THEN
        RAISE EXCEPTION
            'Existencias insuficientes. Disponibles: %, solicitadas: %',
            COALESCE(v_existencia, 0), p_cantidad;
    END IF;

    UPDATE public.inv_stock
    SET cantidad = cantidad - p_cantidad
    WHERE item_id = p_item_id
      AND location_id = p_origen;

    IF p_tipo = 'traslado' THEN
        INSERT INTO public.inv_stock (
            item_id, location_id, cantidad
        )
        VALUES (p_item_id, p_destino, p_cantidad)
        ON CONFLICT (item_id, location_id)
        DO UPDATE SET
            cantidad = public.inv_stock.cantidad + EXCLUDED.cantidad;
    END IF;

    INSERT INTO public.inv_movements (
        client_op_id,
        item_id,
        tipo,
        origen,
        destino,
        cantidad,
        fecha,
        vendedor,
        observaciones,
        usuario
    )
    VALUES (
        v_op_id,
        p_item_id,
        p_tipo,
        p_origen,
        p_destino,
        p_cantidad,
        CURRENT_DATE,
        p_vendedor,
        p_observaciones,
        v_usuario
    )
    RETURNING id INTO v_movimiento_id;

    RETURN v_movimiento_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_registrar_venta(p_vendedor_id uuid, p_modalidad text, p_articulos jsonb, p_descuento numeric, p_observaciones text, p_client_op_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid;
    v_rol text;
    v_vendedor text;
    v_venta_id uuid;
    v_hash text;

    v_linea jsonb;
    v_item_id uuid;
    v_location smallint;
    v_cantidad integer;

    v_precio numeric;
    v_descuento_linea numeric;
    v_descuento_general numeric;

    v_subtotal numeric := 0;
    v_descuentos_lineas numeric := 0;
    v_total numeric;

    v_movimiento_id bigint;
    v_num_linea integer := 0;

    -- Límite del tipo numeric(14,2)
    v_maximo constant numeric := 999999999999.99;
BEGIN
    -- 1. AUTORIZACIÓN
    v_usuario := auth.uid();

    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION
            'No tienes permiso para registrar ventas';
    END IF;

    -- 2. IDENTIFICADOR OBLIGATORIO
    IF p_client_op_id IS NULL THEN
        RAISE EXCEPTION
            'La operación necesita un identificador único';
    END IF;

    -- 3. BLOQUEAR REINTENTOS CON EL MISMO ID
    -- El bloqueo dura hasta finalizar la transacción.
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(
            p_client_op_id::text, 0
        )
    );

    -- 4. CALCULAR HUELLA DE LA SOLICITUD
    v_hash := public.inv_hash_solicitud_venta(
        p_vendedor_id,
        p_modalidad,
        p_articulos,
        p_descuento,
        p_observaciones
    );

    -- 5. COMPROBAR REINTENTO
    v_venta_id :=
        inv_private.verificar_reintento_venta(
            p_client_op_id,
            v_hash
        );

    IF v_venta_id IS NOT NULL THEN
        RETURN v_venta_id;
    END IF;

    -- 6. VALIDAR VENDEDOR
    SELECT nombre INTO v_vendedor
    FROM public.inv_vendedores
    WHERE id = p_vendedor_id
      AND activo = true;

    IF v_vendedor IS NULL THEN
        RAISE EXCEPTION
            'El vendedor no existe o está inactivo';
    END IF;

    -- 7. VALIDAR MODALIDAD
    IF p_modalidad IS NULL
       OR p_modalidad NOT IN ('contado', 'credito') THEN
        RAISE EXCEPTION
            'Modalidad de venta inválida';
    END IF;

    -- 8. VALIDAR LISTA DE ARTÍCULOS
    IF p_articulos IS NULL
       OR pg_catalog.jsonb_typeof(p_articulos) <> 'array'
       OR pg_catalog.jsonb_array_length(p_articulos) = 0 THEN
        RAISE EXCEPTION
            'Debes incluir al menos un artículo';
    END IF;

    IF pg_catalog.jsonb_array_length(p_articulos) > 100 THEN
        RAISE EXCEPTION
            'Una venta no puede superar 100 líneas';
    END IF;

    -- 9. VALIDAR DESCUENTO GENERAL
    IF p_descuento IS NULL
       OR p_descuento < 0
       OR p_descuento > v_maximo
       OR p_descuento <> pg_catalog.round(p_descuento, 2) THEN
        RAISE EXCEPTION
            'Descuento general inválido';
    END IF;

    v_descuento_general := p_descuento;

    -- 10. VALIDAR Y CALCULAR CADA LÍNEA
    FOR v_linea IN
        SELECT value
        FROM pg_catalog.jsonb_array_elements(p_articulos)
    LOOP
        v_num_linea := v_num_linea + 1;

        IF pg_catalog.jsonb_typeof(v_linea) <> 'object' THEN
            RAISE EXCEPTION
                'Línea de venta inválida: %', v_num_linea;
        END IF;

        v_item_id := (v_linea->>'item_id')::uuid;
        v_location := (v_linea->>'location_id')::smallint;
        v_cantidad := (v_linea->>'cantidad')::integer;

        -- Usar numeric sin redondear inicialmente
        v_precio := (v_linea->>'precio_unitario')::numeric;

        v_descuento_linea :=
            COALESCE(
                (v_linea->>'descuento')::numeric,
                0
            );

        IF v_item_id IS NULL
           OR v_location IS NULL
           OR v_location NOT IN (1, 2)
           OR v_cantidad IS NULL
           OR v_cantidad <= 0
           OR v_precio IS NULL
           OR v_precio < 0
           OR v_precio > v_maximo
           OR v_precio <> pg_catalog.round(v_precio, 2)
           OR v_descuento_linea < 0
           OR v_descuento_linea > v_maximo
           OR v_descuento_linea <>
              pg_catalog.round(v_descuento_linea, 2)
        THEN
            RAISE EXCEPTION
                'Datos inválidos en línea %', v_num_linea;
        END IF;

        IF v_cantidad * v_precio > v_maximo THEN
            RAISE EXCEPTION
                'Importe demasiado grande en línea %',
                v_num_linea;
        END IF;

        IF v_descuento_linea >
           v_cantidad * v_precio THEN
            RAISE EXCEPTION
                'Descuento excesivo en línea %',
                v_num_linea;
        END IF;

        v_subtotal :=
            v_subtotal + v_cantidad * v_precio;

        v_descuentos_lineas :=
            v_descuentos_lineas + v_descuento_linea;

        IF v_subtotal > v_maximo
           OR v_descuentos_lineas > v_maximo THEN
            RAISE EXCEPTION
                'El importe de la venta supera el límite';
        END IF;
    END LOOP;

    -- 11. CALCULAR TOTAL
    IF v_descuento_general >
       v_subtotal - v_descuentos_lineas THEN
        RAISE EXCEPTION
            'El descuento supera el importe de la venta';
    END IF;

    v_total :=
        v_subtotal
        - v_descuentos_lineas
        - v_descuento_general;

    -- 12. CREAR ENCABEZADO
    INSERT INTO public.inv_ventas (
        vendedor_id,
        modalidad,
        subtotal,
        descuento,
        total,
        observaciones,
        registrado_por,
        client_op_id,
        solicitud_hash
    )
    VALUES (
        p_vendedor_id,
        p_modalidad,
        v_subtotal,
        v_descuentos_lineas + v_descuento_general,
        v_total,
        p_observaciones,
        v_usuario,
        p_client_op_id,
        v_hash
    )
    RETURNING id INTO v_venta_id;

    -- 13. REGISTRAR CADA ARTÍCULO
    FOR v_linea IN
        SELECT value
        FROM pg_catalog.jsonb_array_elements(p_articulos)
    LOOP
        v_item_id := (v_linea->>'item_id')::uuid;
        v_location := (v_linea->>'location_id')::smallint;
        v_cantidad := (v_linea->>'cantidad')::integer;
        v_precio := (v_linea->>'precio_unitario')::numeric;

        v_descuento_linea :=
            COALESCE(
                (v_linea->>'descuento')::numeric,
                0
            );

        -- Reutilizar la RPC original de inventario
        v_movimiento_id :=
            public.inv_registrar_movimiento(
                v_item_id,
                'salida',
                v_location,
                NULL::smallint,
                v_cantidad,
                v_vendedor,
                'Venta ' || v_venta_id::text,
                gen_random_uuid()
            );

        INSERT INTO public.inv_venta_detalles (
            venta_id,
            item_id,
            location_id,
            cantidad,
            precio_unitario,
            descuento,
            movimiento_id
        )
        VALUES (
            v_venta_id,
            v_item_id,
            v_location,
            v_cantidad,
            v_precio,
            v_descuento_linea,
            v_movimiento_id
        );
    END LOOP;

    RETURN v_venta_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_resolver_reparacion(p_reparacion_id uuid, p_operacion text, p_cantidad integer, p_observaciones text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE c public.inv_reparaciones%ROWTYPE; v_user uuid:=auth.uid(); v_stock int;
        v_op uuid:=gen_random_uuid(); v_mov bigint; v_pendiente int;
        v_recibida int; v_baja int; v_estado text;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM public.inv_members WHERE user_id=v_user AND rol IN ('admin','secretaria'))
 THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_operacion IS NULL OR p_operacion NOT IN ('recepcion','baja')
 THEN RAISE EXCEPTION 'Operación inválida'; END IF;
 IF p_cantidad IS NULL OR p_cantidad<=0 THEN RAISE EXCEPTION 'Cantidad inválida'; END IF;
 IF NULLIF(btrim(p_observaciones),'') IS NULL THEN RAISE EXCEPTION 'Indica el resultado'; END IF;
 SELECT * INTO c FROM public.inv_reparaciones WHERE id=p_reparacion_id FOR UPDATE;
 IF NOT FOUND OR c.estado <> 'enviado' THEN RAISE EXCEPTION 'Reparación no enviada o ya cerrada'; END IF;
 v_pendiente:=c.cantidad-c.cantidad_recibida-c.cantidad_baja;
 IF p_cantidad>v_pendiente THEN RAISE EXCEPTION 'Cantidad superior a las unidades pendientes (%)',v_pendiente; END IF;
 PERFORM 1 FROM public.inv_items WHERE id=c.item_id FOR UPDATE;
 SELECT cantidad INTO v_stock FROM public.inv_stock WHERE item_id=c.item_id AND location_id=4 FOR UPDATE;
 IF COALESCE(v_stock,0)<p_cantidad THEN RAISE EXCEPTION 'Existencias insuficientes en Proveedor/Taller'; END IF;
 INSERT INTO inv_private.reparacion_autorizaciones
 (reparacion_id,item_id,cantidad,operacion,usuario,transaccion_id,backend_pid,operacion_id)
 VALUES(c.id,c.item_id,p_cantidad,p_operacion,v_user,txid_current(),pg_backend_pid(),v_op);
 INSERT INTO inv_private.reparacion_movimientos_autorizados
 (operacion_id,reparacion_id,item_id,cantidad,origen,destino,usuario,transaccion_id,backend_pid)
 VALUES(v_op,c.id,c.item_id,p_cantidad,4,
        CASE WHEN p_operacion='recepcion' THEN 3::smallint ELSE NULL::smallint END,
        v_user,txid_current(),pg_backend_pid());
 PERFORM set_config('inv_private.operacion_reparacion',v_op::text,true);
 PERFORM set_config('inv_private.tipo_operacion_reparacion',p_operacion,true);
 UPDATE public.inv_stock SET cantidad=cantidad-p_cantidad WHERE item_id=c.item_id AND location_id=4;
 IF p_operacion='recepcion' THEN
   INSERT INTO public.inv_stock(item_id,location_id,cantidad) VALUES(c.item_id,3,p_cantidad)
   ON CONFLICT(item_id,location_id) DO UPDATE SET cantidad=public.inv_stock.cantidad+EXCLUDED.cantidad;
 END IF;
 INSERT INTO public.inv_movements(client_op_id,item_id,tipo,origen,destino,cantidad,fecha,observaciones,usuario)
 VALUES(v_op,c.item_id,CASE WHEN p_operacion='recepcion' THEN 'traslado' ELSE 'salida' END,
 4,CASE WHEN p_operacion='recepcion' THEN 3::smallint ELSE NULL::smallint END,
 p_cantidad,CURRENT_DATE,upper(p_operacion)||' REPARACIÓN '||c.id::text||': '||btrim(p_observaciones),v_user)
 RETURNING id INTO v_mov;
 v_recibida:=c.cantidad_recibida+CASE WHEN p_operacion='recepcion' THEN p_cantidad ELSE 0 END;
 v_baja:=c.cantidad_baja+CASE WHEN p_operacion='baja' THEN p_cantidad ELSE 0 END;
 v_estado:=CASE WHEN v_recibida+v_baja<c.cantidad THEN 'enviado'
   WHEN v_recibida>0 THEN 'recibido' ELSE 'baja' END;
 UPDATE public.inv_reparaciones SET cantidad_recibida=v_recibida,cantidad_baja=v_baja,
 estado=v_estado,fecha_retorno=CASE WHEN v_estado<>'enviado' THEN now() ELSE fecha_retorno END,
 fecha_actualizacion=now(),actualizado_por=v_user WHERE id=c.id;
 PERFORM set_config('inv_private.operacion_reparacion','',true);
 PERFORM set_config('inv_private.tipo_operacion_reparacion','',true);
 RETURN v_mov;
END; $function$
;

CREATE OR REPLACE FUNCTION public.inv_resumen_vendedor(p_vendedor_id uuid, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date)
 RETURNS TABLE(contratos bigint, contratos_confirmados bigint, ventas_brutas numeric, comisiones_generadas numeric, comisiones_pendientes numeric, primas_recibidas numeric, primas_pendientes numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.inv_members m
  WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_vendedor_id IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.inv_vendedores_manual v WHERE v.id=p_vendedor_id
 ) THEN RAISE EXCEPTION 'Vendedor inexistente'; END IF;
 IF p_desde IS NOT NULL AND p_hasta IS NOT NULL AND p_desde>p_hasta
 THEN RAISE EXCEPTION 'Rango de fechas inválido'; END IF;

 RETURN QUERY
 WITH contratos_filtrados AS (
  SELECT c.id,c.estado,c.comision_total,c.comision_estado
  FROM public.inv_contratos c
  WHERE c.vendedor_id=p_vendedor_id
    AND (p_desde IS NULL OR c.fecha>=p_desde)
    AND (p_hasta IS NULL OR c.fecha<=p_hasta)
 ), importes AS (
  SELECT cf.id,cf.estado,cf.comision_total,cf.comision_estado,
   COALESCE((SELECT sum(d.cantidad*d.precio_credito_unitario)
             FROM public.inv_contrato_detalles d WHERE d.contrato_id=cf.id),0) AS venta,
   COALESCE(pr.monto,0) AS prima,
   pr.estado AS prima_estado
  FROM contratos_filtrados cf
  LEFT JOIN public.inv_contrato_primas pr ON pr.contrato_id=cf.id
 )
 SELECT count(*)::bigint,
   count(*) FILTER(WHERE i.estado='confirmado')::bigint,
   COALESCE(sum(i.venta) FILTER(WHERE i.estado='confirmado'),0)::numeric,
   COALESCE(sum(i.comision_total) FILTER(WHERE i.estado='confirmado'),0)::numeric,
   COALESCE(sum(i.comision_total) FILTER(WHERE i.estado='confirmado' AND i.comision_estado='pendiente'),0)::numeric,
   COALESCE(sum(i.prima) FILTER(WHERE i.estado='confirmado' AND i.prima_estado='recibida'),0)::numeric,
   COALESCE(sum(i.prima) FILTER(WHERE i.estado='confirmado' AND i.prima_estado='pendiente'),0)::numeric
 FROM importes i;
END $function$
;

CREATE OR REPLACE FUNCTION public.inv_revisar_devolucion(p_solicitud_id uuid, p_aprobar boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid := auth.uid();
    v_rol text;
    v_solicitud public.inv_returns%ROWTYPE;
BEGIN
    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION 'No tienes permiso para revisar devoluciones';
    END IF;

    IF p_aprobar IS NULL THEN
        RAISE EXCEPTION 'Debes indicar si apruebas o rechazas';
    END IF;

    SELECT *
    INTO v_solicitud
    FROM public.inv_returns
    WHERE id = p_solicitud_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La devolución no existe';
    END IF;

    IF v_solicitud.estado <> 'pendiente' THEN
        RAISE EXCEPTION 'Esta devolución ya fue revisada';
    END IF;

    IF v_solicitud.location_id <> 3 THEN
        RAISE EXCEPTION 'Las devoluciones deben ingresar a Garantía';
    END IF;

    IF p_aprobar THEN

        -- Bloqueamos el artículo para coordinar
        -- sus operaciones de inventario.
        PERFORM 1
        FROM public.inv_items
        WHERE id = v_solicitud.item_id
          AND estado = 'activo'
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El artículo ya no está activo';
        END IF;

        -- Aumentamos las existencias de Garantía.
        INSERT INTO public.inv_stock (
            item_id,
            location_id,
            cantidad
        )
        VALUES (
            v_solicitud.item_id,
            3,
            v_solicitud.cantidad
        )
        ON CONFLICT (item_id, location_id)
        DO UPDATE SET
            cantidad = public.inv_stock.cantidad
                     + EXCLUDED.cantidad;

        -- Registramos el movimiento.
        INSERT INTO public.inv_movements (
            client_op_id,
            item_id,
            tipo,
            origen,
            destino,
            cantidad,
            fecha,
            observaciones,
            usuario
        )
        VALUES (
            v_solicitud.id,
            v_solicitud.item_id,
            'devolucion',
            NULL,
            3,
            v_solicitud.cantidad,
            CURRENT_DATE,
            'Devolución aprobada: ' || v_solicitud.motivo,
            v_usuario
        );

    END IF;

    UPDATE public.inv_returns
    SET estado = CASE
            WHEN p_aprobar THEN 'aprobada'
            ELSE 'rechazada'
        END,
        revisado_por = v_usuario,
        revisado_en = now()
    WHERE id = p_solicitud_id;

    RETURN CASE
        WHEN p_aprobar THEN 'Devolución aprobada correctamente'
        ELSE 'Devolución rechazada correctamente'
    END;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_revisar_entrada(p_solicitud_id uuid, p_aprobar boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario UUID;
    v_rol TEXT;
    v_solicitud public.inv_entry_requests%ROWTYPE;
BEGIN
    v_usuario := auth.uid();

    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión';
    END IF;

    -- Solo secretaria y administrador
    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION 'No tienes permiso para autorizar entradas';
    END IF;

    IF p_solicitud_id IS NULL OR p_aprobar IS NULL THEN
        RAISE EXCEPTION 'Debes indicar la solicitud y la decisión';
    END IF;

    -- Bloquear solicitud durante la revisión
    SELECT *
    INTO v_solicitud
    FROM public.inv_entry_requests
    WHERE id = p_solicitud_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solicitud no encontrada';
    END IF;

    IF v_solicitud.estado <> 'pendiente' THEN
        RAISE EXCEPTION 'Esta solicitud ya fue revisada';
    END IF;

    IF p_aprobar THEN

        -- Comprobar que el artículo sigue activo
        IF NOT EXISTS (
            SELECT 1
            FROM public.inv_items
            WHERE id = v_solicitud.item_id
              AND estado = 'activo'
        ) THEN
            RAISE EXCEPTION 'El artículo ya no está activo';
        END IF;

        -- Aumentar existencias
        INSERT INTO public.inv_stock (
            item_id,
            location_id,
            cantidad
        )
        VALUES (
            v_solicitud.item_id,
            v_solicitud.location_id,
            v_solicitud.cantidad
        )
        ON CONFLICT (item_id, location_id)
        DO UPDATE SET
            cantidad = public.inv_stock.cantidad
                     + EXCLUDED.cantidad;

        -- Registrar movimiento aprobado
        INSERT INTO public.inv_movements (
            client_op_id,
            item_id,
            tipo,
            origen,
            destino,
            cantidad,
            fecha,
            observaciones,
            usuario
        )
        VALUES (
            v_solicitud.id,
            v_solicitud.item_id,
            'entrada',
            NULL,
            v_solicitud.location_id,
            v_solicitud.cantidad,
            CURRENT_DATE,
            'Entrada aprobada. Solicitud: '
                || v_solicitud.id::TEXT,
            v_usuario
        );

    END IF;

    -- Guardar decisión
    UPDATE public.inv_entry_requests
    SET
        estado = CASE
            WHEN p_aprobar THEN 'aprobada'
            ELSE 'rechazada'
        END,
        revisado_por = v_usuario,
        revisado_en = now()
    WHERE id = p_solicitud_id;

    RETURN CASE
        WHEN p_aprobar THEN 'Entrada aprobada correctamente'
        ELSE 'Entrada rechazada correctamente'
    END;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_revisar_recepcion(p_recepcion_id uuid, p_aprobar boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=auth.uid(); v_rec public.inv_recepciones%rowtype; v_line record;
begin
 if v_uid is null or not exists(select 1 from public.inv_members where user_id=v_uid and rol in ('admin','secretaria')) then raise exception 'No tienes permiso para revisar recepciones'; end if;
 if p_aprobar is null or p_recepcion_id is null then raise exception 'Decisión inválida'; end if;
 select * into v_rec from public.inv_recepciones where id=p_recepcion_id for update;
 if not found then raise exception 'Recepción inexistente'; end if;
 if v_rec.estado<>'pendiente' then raise exception 'Esta recepción ya fue revisada'; end if;
 if p_aprobar then
  for v_line in select d.* from public.inv_recepcion_detalles d where d.recepcion_id=p_recepcion_id order by d.item_id,d.location_id loop
   if not exists(select 1 from public.inv_items where id=v_line.item_id and estado='activo') then raise exception 'Hay un artículo inactivo'; end if;
   insert into public.inv_stock(item_id,location_id,cantidad)
   values(v_line.item_id,v_line.location_id,v_line.cantidad)
   on conflict(item_id,location_id) do update
   set cantidad=public.inv_stock.cantidad+excluded.cantidad;
   insert into public.inv_movements(client_op_id,item_id,tipo,origen,destino,cantidad,fecha,observaciones,usuario)
   values(v_line.id,v_line.item_id,'entrada',null,v_line.location_id,v_line.cantidad,current_date,
    'Recepción de proveedor: '||v_rec.proveedor||' | Referencia: '||v_rec.referencia||' | Recepción: '||v_rec.id::text,v_uid);
  end loop;
 end if;
 update public.inv_recepciones set estado=case when p_aprobar then 'aprobada' else 'rechazada' end,revisado_por=v_uid,revisado_en=now() where id=p_recepcion_id;
 return case when p_aprobar then 'Recepción aprobada' else 'Recepción rechazada' end;
end $function$
;

CREATE OR REPLACE FUNCTION public.inv_solicitar_devolucion(p_item_id uuid, p_cantidad integer, p_motivo text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid := auth.uid();
    v_rol text;
    v_estado text;
    v_solicitud uuid;
BEGIN
    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION 'No tienes permiso para registrar devoluciones';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor que cero';
    END IF;

    IF NULLIF(btrim(p_motivo), '') IS NULL THEN
        RAISE EXCEPTION 'Debes indicar el motivo de la devolución';
    END IF;

    SELECT estado INTO v_estado
    FROM public.inv_items
    WHERE id = p_item_id;

    IF v_estado IS DISTINCT FROM 'activo' THEN
        RAISE EXCEPTION 'El artículo no existe o no está activo';
    END IF;

    INSERT INTO public.inv_returns (
        item_id,
        location_id,
        cantidad,
        estado,
        motivo,
        registrado_por
    )
    VALUES (
        p_item_id,
        3,
        p_cantidad,
        'pendiente',
        btrim(p_motivo),
        v_usuario
    )
    RETURNING id INTO v_solicitud;

    RETURN v_solicitud;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_solicitar_devolucion_venta(p_venta_detalle_id uuid, p_cantidad integer, p_motivo text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario uuid;
    v_rol text;
    v_venta_id uuid;
    v_detalle public.inv_venta_detalles%ROWTYPE;
    v_estado_venta text;
    v_estado_articulo text;
    v_ya_solicitado bigint;
    v_disponible bigint;
    v_solicitud_id uuid;
BEGIN
    -- 1. Verificar usuario y permisos
    v_usuario := auth.uid();

    SELECT rol INTO v_rol
    FROM public.inv_members
    WHERE user_id = v_usuario;

    IF v_rol IS NULL
       OR v_rol NOT IN ('admin', 'secretaria') THEN
        RAISE EXCEPTION
            'No tienes permiso para registrar devoluciones';
    END IF;

    -- 2. Validar parámetros
    IF p_venta_detalle_id IS NULL THEN
        RAISE EXCEPTION
            'Debes seleccionar un artículo de una venta';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION
            'La cantidad debe ser mayor que cero';
    END IF;

    IF NULLIF(pg_catalog.btrim(p_motivo), '') IS NULL THEN
        RAISE EXCEPTION
            'Debes indicar el motivo de la devolución';
    END IF;

    -- 3. Identificar la venta correspondiente
    SELECT d.venta_id
    INTO v_venta_id
    FROM public.inv_venta_detalles d
    WHERE d.id = p_venta_detalle_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El detalle de venta no existe';
    END IF;

    -- 4. Bloquear primero la cabecera de venta
    -- Coordina devoluciones con anulaciones.
    SELECT v.estado
    INTO v_estado_venta
    FROM public.inv_ventas v
    WHERE v.id = v_venta_id
    FOR UPDATE;

    IF v_estado_venta IS DISTINCT FROM 'registrada' THEN
        RAISE EXCEPTION
            'La venta original no está registrada';
    END IF;

    -- 5. Bloquear después el detalle
    SELECT *
    INTO v_detalle
    FROM public.inv_venta_detalles
    WHERE id = p_venta_detalle_id
      AND venta_id = v_venta_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El detalle de venta no existe';
    END IF;

    -- 6. Verificar estado del artículo
    SELECT estado
    INTO v_estado_articulo
    FROM public.inv_items
    WHERE id = v_detalle.item_id;

    IF v_estado_articulo IS DISTINCT FROM 'activo' THEN
        RAISE EXCEPTION
            'El artículo no existe o está inactivo';
    END IF;

    -- 7. Contar devoluciones pendientes
    -- y aprobadas del detalle.
    SELECT COALESCE(SUM(cantidad), 0)
    INTO v_ya_solicitado
    FROM public.inv_returns
    WHERE venta_detalle_id = p_venta_detalle_id
      AND estado IN ('pendiente', 'aprobada');

    v_disponible :=
        v_detalle.cantidad - v_ya_solicitado;

    -- 8. Impedir cantidades excesivas
    IF p_cantidad > v_disponible THEN
        RAISE EXCEPTION
            'Cantidad excesiva: solo quedan % unidades para devolver',
            v_disponible;
    END IF;

    -- 9. Registrar devolución pendiente
    -- No aumentar inventario.
    INSERT INTO public.inv_returns (
        item_id,
        location_id,
        cantidad,
        estado,
        motivo,
        registrado_por,
        venta_detalle_id
    )
    VALUES (
        v_detalle.item_id,
        3,
        p_cantidad,
        'pendiente',
        pg_catalog.btrim(p_motivo),
        v_usuario,
        p_venta_detalle_id
    )
    RETURNING id INTO v_solicitud_id;

    RETURN v_solicitud_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_solicitar_entrada(p_item_id uuid, p_location_id smallint, p_cantidad integer, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario UUID;
    v_solicitud UUID;
BEGIN
    v_usuario := auth.uid();

    -- Verificar identidad
    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión';
    END IF;

    -- Verificar membresía autorizada
    IF NOT EXISTS (
        SELECT 1
        FROM public.inv_members
        WHERE user_id = v_usuario
          AND rol IN (
              'admin',
              'secretaria',
              'empleado'
          )
    ) THEN
        RAISE EXCEPTION 'Usuario sin autorización';
    END IF;

    -- Validar cantidad
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor que cero';
    END IF;

    -- Verificar artículo activo
    IF NOT EXISTS (
        SELECT 1
        FROM public.inv_items
        WHERE id = p_item_id
          AND estado = 'activo'
    ) THEN
        RAISE EXCEPTION 'Artículo inexistente o inactivo';
    END IF;

    -- Verificar ubicación
    IF NOT EXISTS (
        SELECT 1
        FROM public.inv_locations
        WHERE id = p_location_id
    ) THEN
        RAISE EXCEPTION 'Ubicación no válida';
    END IF;

    -- Crear solicitud pendiente
    INSERT INTO public.inv_entry_requests (
        item_id,
        location_id,
        cantidad,
        observaciones,
        solicitado_por
    )
    VALUES (
        p_item_id,
        p_location_id,
        p_cantidad,
        NULLIF(
            pg_catalog.btrim(p_observaciones),
            ''
        ),
        v_usuario
    )
    RETURNING id INTO v_solicitud;

    RETURN v_solicitud;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.inv_validar_ruta_reparacion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_op uuid; v_id uuid;
BEGIN
 IF NEW.origen = 4 OR NEW.destino = 4 THEN
   BEGIN
     v_op := NULLIF(current_setting('inv_private.operacion_reparacion',true),'')::uuid;
   EXCEPTION WHEN invalid_text_representation THEN v_op := NULL;
   END;
   DELETE FROM inv_private.reparacion_movimientos_autorizados a
   WHERE a.id = (
      SELECT x.id FROM inv_private.reparacion_movimientos_autorizados x
      WHERE x.operacion_id = v_op AND x.item_id = NEW.item_id
        AND x.cantidad = NEW.cantidad AND x.origen IS NOT DISTINCT FROM NEW.origen
        AND x.destino IS NOT DISTINCT FROM NEW.destino
        AND x.usuario = auth.uid() AND x.transaccion_id = txid_current()
        AND x.backend_pid = pg_backend_pid()
        AND ((NEW.tipo='traslado' AND NEW.origen=3 AND NEW.destino=4)
          OR (NEW.tipo='traslado' AND NEW.origen=4 AND NEW.destino=3)
          OR (NEW.tipo='salida' AND NEW.origen=4 AND NEW.destino IS NULL))
      FOR UPDATE
   ) RETURNING a.id INTO v_id;
   IF v_id IS NULL THEN RAISE EXCEPTION 'Movimiento de reparación no autorizado'; END IF;
 END IF;
 RETURN NEW;
END; $function$
;

CREATE OR REPLACE VIEW "public"."inv_reporte_articulos_vendidos" WITH (security_invoker = true) AS  SELECT v.fecha,
    v.vendedor_id,
    vd.nombre AS vendedor,
    d.item_id,
    i.nombre_original AS articulo,
    d.location_id AS ubicacion,
    sum(d.cantidad) AS unidades_vendidas,
    sum(d.subtotal) AS subtotal,
    sum(d.descuento) AS descuentos_linea,
    sum(d.subtotal - d.descuento) AS total_antes_descuento_general
   FROM inv_venta_detalles d
     JOIN inv_ventas v ON v.id = d.venta_id
     JOIN inv_vendedores vd ON vd.id = v.vendedor_id
     JOIN inv_items i ON i.id = d.item_id
  WHERE v.estado = 'registrada'::text
  GROUP BY v.fecha, v.vendedor_id, vd.nombre, d.item_id, i.nombre_original, d.location_id;

CREATE OR REPLACE VIEW "public"."inv_reporte_vendedores" WITH (security_invoker = true) AS  SELECT vd.id AS vendedor_id,
    vd.nombre AS vendedor,
    vd.activo,
    count(v.id) FILTER (WHERE v.estado = 'registrada'::text) AS cantidad_ventas,
    COALESCE(sum(v.total) FILTER (WHERE v.estado = 'registrada'::text), 0::numeric) AS total_vendido,
    COALESCE(sum(v.total) FILTER (WHERE v.estado = 'registrada'::text AND v.modalidad = 'contado'::text), 0::numeric) AS total_contado,
    COALESCE(sum(v.total) FILTER (WHERE v.estado = 'registrada'::text AND v.modalidad = 'credito'::text), 0::numeric) AS total_credito
   FROM inv_vendedores vd
     LEFT JOIN inv_ventas v ON v.vendedor_id = vd.id
  GROUP BY vd.id, vd.nombre, vd.activo;

CREATE OR REPLACE VIEW "public"."inv_reporte_ventas_diarias" WITH (security_invoker = true) AS  SELECT fecha,
    count(*) AS cantidad_ventas,
    COALESCE(sum(subtotal), 0::numeric) AS subtotal,
    COALESCE(sum(descuento), 0::numeric) AS descuentos,
    COALESCE(sum(total), 0::numeric) AS total_vendido,
    COALESCE(sum(total) FILTER (WHERE modalidad = 'contado'::text), 0::numeric) AS total_contado,
    COALESCE(sum(total) FILTER (WHERE modalidad = 'credito'::text), 0::numeric) AS total_credito
   FROM inv_ventas v
  WHERE estado = 'registrada'::text
  GROUP BY fecha;

CREATE TRIGGER trg_inv_movimientos_inmutables BEFORE DELETE OR UPDATE ON inv_movements FOR EACH ROW EXECUTE FUNCTION inv_inmutabilidad_movimientos();

CREATE TRIGGER trg_rechazar_movimiento_normal_proveedor BEFORE INSERT OR UPDATE ON inv_movements FOR EACH ROW EXECUTE FUNCTION inv_rechazar_movimiento_normal_proveedor();

CREATE TRIGGER trg_validar_ruta_reparacion BEFORE INSERT OR UPDATE ON inv_movements FOR EACH ROW EXECUTE FUNCTION inv_validar_ruta_reparacion();

CREATE TRIGGER trg_bloquear_entrada_proveedor BEFORE INSERT OR UPDATE ON inv_stock FOR EACH ROW EXECUTE FUNCTION inv_bloquear_entrada_proveedor();

CREATE TRIGGER trg_bloquear_salida_garantia BEFORE UPDATE ON inv_stock FOR EACH ROW EXECUTE FUNCTION inv_bloquear_salida_garantia();

CREATE TRIGGER trg_bloquear_salida_proveedor BEFORE UPDATE ON inv_stock FOR EACH ROW EXECUTE FUNCTION inv_bloquear_salida_proveedor();

ALTER TABLE "inv_private"."garantia_autorizaciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "inv_private"."reparacion_autorizaciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "inv_private"."reparacion_movimientos_autorizados" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_cliente_referencias" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_clientes" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_contrato_detalles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_contrato_primas" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_contratos" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_entry_requests" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_items" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_locations" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_members" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_movements" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_prima_eventos" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_recepcion_detalles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_recepciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_reparaciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_returns" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_stock" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_vendedores" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_vendedores_manual" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_venta_anulacion_movimientos" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_venta_detalles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."inv_ventas" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inv_entry_requests_select" ON "public"."inv_entry_requests" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members
  WHERE (inv_members.user_id = ( SELECT auth.uid() AS uid)))));

CREATE POLICY "inv_items_select" ON "public"."inv_items" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members
  WHERE (inv_members.user_id = ( SELECT auth.uid() AS uid)))));

CREATE POLICY "inv_locations_select" ON "public"."inv_locations" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members
  WHERE (inv_members.user_id = ( SELECT auth.uid() AS uid)))));

CREATE POLICY "Consultar mi membresia" ON "public"."inv_members" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((user_id = ( SELECT auth.uid() AS uid)));

CREATE POLICY "inv_movements_select" ON "public"."inv_movements" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members
  WHERE (inv_members.user_id = ( SELECT auth.uid() AS uid)))));

CREATE POLICY "inv_recepcion_detalles_select" ON "public"."inv_recepcion_detalles" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members m
  WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.rol = ANY (ARRAY['admin'::text, 'secretaria'::text]))))));

CREATE POLICY "inv_recepciones_select" ON "public"."inv_recepciones" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members m
  WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.rol = ANY (ARRAY['admin'::text, 'secretaria'::text]))))));

CREATE POLICY "Consultar reparaciones autorizadas" ON "public"."inv_reparaciones" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members m
  WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.rol = ANY (ARRAY['admin'::text, 'secretaria'::text]))))));

CREATE POLICY "inv_returns_select" ON "public"."inv_returns" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members
  WHERE (inv_members.user_id = ( SELECT auth.uid() AS uid)))));

CREATE POLICY "inv_stock_select" ON "public"."inv_stock" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members
  WHERE (inv_members.user_id = ( SELECT auth.uid() AS uid)))));

CREATE POLICY "inv_vendedores_select_miembros" ON "public"."inv_vendedores" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members m
  WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.rol = ANY (ARRAY['admin'::text, 'secretaria'::text]))))));

CREATE POLICY "inv_venta_detalles_select_miembros" ON "public"."inv_venta_detalles" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members m
  WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.rol = ANY (ARRAY['admin'::text, 'secretaria'::text]))))));

CREATE POLICY "inv_ventas_select_miembros" ON "public"."inv_ventas" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM inv_members m
  WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.rol = ANY (ARRAY['admin'::text, 'secretaria'::text]))))));

REVOKE ALL ON TABLE "inv_private"."garantia_autorizaciones" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "inv_private"."reparacion_autorizaciones" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "inv_private"."reparacion_movimientos_autorizados" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "public"."inv_cliente_referencias" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "public"."inv_clientes" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "public"."inv_contrato_detalles" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "public"."inv_contrato_primas" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "public"."inv_contratos" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "public"."inv_entry_requests" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_entry_requests" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_items" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_items" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_locations" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_locations" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_members" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_members" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_movements" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_movements" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_prima_eventos" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "public"."inv_recepcion_detalles" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_recepcion_detalles" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_recepciones" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_recepciones" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_reparaciones" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_reparaciones" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_returns" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_returns" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_stock" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_stock" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_vendedores" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_vendedores" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_vendedores_manual" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "public"."inv_venta_anulacion_movimientos" FROM PUBLIC, anon, authenticated;

REVOKE ALL ON TABLE "public"."inv_venta_detalles" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_venta_detalles" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_ventas" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_ventas" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_reporte_articulos_vendidos" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_reporte_articulos_vendidos" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_reporte_vendedores" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_reporte_vendedores" TO authenticated;

REVOKE ALL ON TABLE "public"."inv_reporte_ventas_diarias" FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE "public"."inv_reporte_ventas_diarias" TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_hash_solicitud_venta"(p_vendedor_id uuid, p_modalidad text, p_articulos jsonb, p_descuento numeric, p_observaciones text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "inv_private"."consumir_autorizacion_reparacion"(p_item_id uuid, p_cantidad integer, p_operacion text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "inv_private"."verificar_reintento_venta"(p_client_op_id uuid, p_hash text) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "public"."inv_anular_venta"(p_venta_id uuid, p_motivo text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_anular_venta"(p_venta_id uuid, p_motivo text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_bloquear_entrada_proveedor"() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "public"."inv_bloquear_ruta_general_proveedor"() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "public"."inv_bloquear_salida_garantia"() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "public"."inv_bloquear_salida_proveedor"() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "public"."inv_buscar_clientes"(p_busqueda text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_buscar_clientes"(p_busqueda text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_catalogo_articulos_contratos"() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_catalogo_articulos_contratos"() TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_catalogo_vendedores"() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_catalogo_vendedores"() TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_catalogo_vendedores_manual"() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_catalogo_vendedores_manual"() TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_confirmar_contrato"(p_contrato_id uuid, p_ubicaciones jsonb, p_client_op_id uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_confirmar_contrato"(p_contrato_id uuid, p_ubicaciones jsonb, p_client_op_id uuid) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_crear_cliente"(p_nombre text, p_dui text, p_direccion text, p_ubicacion text, p_telefono text, p_vivienda text, p_lugar_trabajo text, p_telefono_trabajo text, p_referencias jsonb) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_crear_cliente"(p_nombre text, p_dui text, p_direccion text, p_ubicacion text, p_telefono text, p_vivienda text, p_lugar_trabajo text, p_telefono_trabajo text, p_referencias jsonb) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_crear_contrato_borrador"(p_numero text, p_cliente_id uuid, p_vendedor_id uuid, p_fecha date, p_modalidad text, p_frecuencia text, p_plan text, p_cuota numeric, p_saldo_inicial numeric, p_fecha_plan date, p_ruta text, p_dia_cobro text, p_receptor_alterno text, p_comision numeric, p_prima numeric, p_prima_recibida boolean, p_detalles jsonb, p_observaciones text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_crear_contrato_borrador"(p_numero text, p_cliente_id uuid, p_vendedor_id uuid, p_fecha date, p_modalidad text, p_frecuencia text, p_plan text, p_cuota numeric, p_saldo_inicial numeric, p_fecha_plan date, p_ruta text, p_dia_cobro text, p_receptor_alterno text, p_comision numeric, p_prima numeric, p_prima_recibida boolean, p_detalles jsonb, p_observaciones text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_crear_recepcion"(p_proveedor text, p_referencia text, p_fecha date, p_observaciones text, p_detalles jsonb) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_crear_recepcion"(p_proveedor text, p_referencia text, p_fecha date, p_observaciones text, p_detalles jsonb) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_crear_reparacion"(p_item_id uuid, p_cantidad integer, p_destino_tipo text, p_destino_nombre text, p_motivo text, p_observaciones text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_crear_reparacion"(p_item_id uuid, p_cantidad integer, p_destino_tipo text, p_destino_nombre text, p_motivo text, p_observaciones text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_crear_vendedor"(p_nombre text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_crear_vendedor"(p_nombre text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_crear_vendedor_manual"(p_nombre text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_crear_vendedor_manual"(p_nombre text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_detalle_contrato"(p_contrato_id uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_detalle_contrato"(p_contrato_id uuid) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_enviar_reparacion"(p_reparacion_id uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_enviar_reparacion"(p_reparacion_id uuid) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_ficha_cliente"(p_cliente_id uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_ficha_cliente"(p_cliente_id uuid) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_historial_cliente"(p_cliente_id uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_historial_cliente"(p_cliente_id uuid) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_historial_vendedor"(p_vendedor_id uuid, p_desde date, p_hasta date) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_historial_vendedor"(p_vendedor_id uuid, p_desde date, p_hasta date) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_inmutabilidad_movimientos"() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "public"."inv_liberar_garantia"(p_item_id uuid, p_destino smallint, p_cantidad integer, p_observaciones text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_liberar_garantia"(p_item_id uuid, p_destino smallint, p_cantidad integer, p_observaciones text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_marcar_prima_recibida"(p_contrato_id uuid, p_observaciones text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_marcar_prima_recibida"(p_contrato_id uuid, p_observaciones text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_rechazar_movimiento_normal_proveedor"() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION "public"."inv_registrar_movimiento"(p_item_id uuid, p_tipo text, p_origen smallint, p_destino smallint, p_cantidad integer, p_vendedor text, p_observaciones text, p_client_op_id uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_registrar_movimiento"(p_item_id uuid, p_tipo text, p_origen smallint, p_destino smallint, p_cantidad integer, p_vendedor text, p_observaciones text, p_client_op_id uuid) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_registrar_venta"(p_vendedor_id uuid, p_modalidad text, p_articulos jsonb, p_descuento numeric, p_observaciones text, p_client_op_id uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_registrar_venta"(p_vendedor_id uuid, p_modalidad text, p_articulos jsonb, p_descuento numeric, p_observaciones text, p_client_op_id uuid) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_resolver_reparacion"(p_reparacion_id uuid, p_operacion text, p_cantidad integer, p_observaciones text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_resolver_reparacion"(p_reparacion_id uuid, p_operacion text, p_cantidad integer, p_observaciones text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_resumen_vendedor"(p_vendedor_id uuid, p_desde date, p_hasta date) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_resumen_vendedor"(p_vendedor_id uuid, p_desde date, p_hasta date) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_revisar_devolucion"(p_solicitud_id uuid, p_aprobar boolean) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_revisar_devolucion"(p_solicitud_id uuid, p_aprobar boolean) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_revisar_entrada"(p_solicitud_id uuid, p_aprobar boolean) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_revisar_entrada"(p_solicitud_id uuid, p_aprobar boolean) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_revisar_recepcion"(p_recepcion_id uuid, p_aprobar boolean) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_revisar_recepcion"(p_recepcion_id uuid, p_aprobar boolean) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_solicitar_devolucion"(p_item_id uuid, p_cantidad integer, p_motivo text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_solicitar_devolucion"(p_item_id uuid, p_cantidad integer, p_motivo text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_solicitar_devolucion_venta"(p_venta_detalle_id uuid, p_cantidad integer, p_motivo text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_solicitar_devolucion_venta"(p_venta_detalle_id uuid, p_cantidad integer, p_motivo text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_solicitar_entrada"(p_item_id uuid, p_location_id smallint, p_cantidad integer, p_observaciones text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION "public"."inv_solicitar_entrada"(p_item_id uuid, p_location_id smallint, p_cantidad integer, p_observaciones text) TO authenticated;

REVOKE ALL ON FUNCTION "public"."inv_validar_ruta_reparacion"() FROM PUBLIC, anon, authenticated;

COMMIT;

-- No user/customer/item data, inventory initial locations or role memberships included.
