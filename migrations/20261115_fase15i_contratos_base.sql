-- FASE 15I: esquema inicial de contratos digitales (MIGRACION PREPARADA, NO APLICADA)
-- Aplicar solo en entorno de integración aislado tras backup y revisión.
BEGIN;

CREATE TABLE IF NOT EXISTS public.inv_clientes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 nombre text NOT NULL CHECK (length(btrim(nombre)) BETWEEN 2 AND 200),
 dui text,
 direccion text,
 ubicacion text,
 telefono text,
 vivienda text CHECK (vivienda IN ('alquila','propia') OR vivienda IS NULL),
 lugar_trabajo text,
 telefono_trabajo text,
 creado_en timestamptz NOT NULL DEFAULT now(),
 actualizado_en timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT inv_clientes_dui_formato CHECK (dui IS NULL OR dui ~ '^[0-9]{8}-[0-9]$')
);
CREATE UNIQUE INDEX IF NOT EXISTS inv_clientes_dui_unico ON public.inv_clientes(dui) WHERE dui IS NOT NULL;
CREATE INDEX IF NOT EXISTS inv_clientes_nombre_busqueda ON public.inv_clientes(lower(nombre));

CREATE TABLE IF NOT EXISTS public.inv_cliente_referencias (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 cliente_id uuid NOT NULL REFERENCES public.inv_clientes(id) ON DELETE RESTRICT,
 orden smallint NOT NULL CHECK (orden IN (1,2)),
 nombre text NOT NULL,
 telefono text,
 direccion text,
 parentesco text,
 UNIQUE(cliente_id,orden)
);

CREATE TABLE IF NOT EXISTS public.inv_contratos (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 numero text NOT NULL UNIQUE,
 cliente_id uuid NOT NULL REFERENCES public.inv_clientes(id),
 vendedor_id uuid NOT NULL REFERENCES public.inv_vendedores(id),
 venta_id uuid UNIQUE REFERENCES public.inv_ventas(id),
 fecha date NOT NULL DEFAULT CURRENT_DATE,
 modalidad text NOT NULL DEFAULT 'credito' CHECK (modalidad IN ('credito','contado')),
 frecuencia text CHECK (frecuencia IN ('semanal','quincenal','mensual') OR frecuencia IS NULL),
 plan text NOT NULL DEFAULT 'normal' CHECK (plan IN ('normal','3_pagos','6_pagos')),
 cuota numeric(14,2) CHECK (cuota IS NULL OR cuota >= 0),
 saldo_inicial numeric(14,2) CHECK (saldo_inicial IS NULL OR saldo_inicial >= 0),
 fecha_plan date,
 ruta text,
 dia_cobro text,
 receptor_alterno text,
 comision_total numeric(14,2) NOT NULL DEFAULT 0 CHECK (comision_total >= 0),
 comision_estado text NOT NULL DEFAULT 'pendiente' CHECK (comision_estado IN ('pendiente','pagada')),
 observaciones text,
 estado text NOT NULL DEFAULT 'borrador' CHECK (estado IN ('borrador','confirmado','anulado')),
 creado_en timestamptz NOT NULL DEFAULT now(),
 actualizado_en timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS inv_contratos_cliente_idx ON public.inv_contratos(cliente_id,fecha DESC);
CREATE INDEX IF NOT EXISTS inv_contratos_vendedor_idx ON public.inv_contratos(vendedor_id,fecha DESC);

CREATE TABLE IF NOT EXISTS public.inv_contrato_detalles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 contrato_id uuid NOT NULL REFERENCES public.inv_contratos(id) ON DELETE RESTRICT,
 item_id uuid NOT NULL REFERENCES public.inv_items(id),
 cantidad integer NOT NULL CHECK (cantidad > 0),
 precio_credito_unitario numeric(14,2) NOT NULL CHECK (precio_credito_unitario >= 0),
 comision_linea numeric(14,2) NOT NULL DEFAULT 0 CHECK (comision_linea >= 0)
);
CREATE INDEX IF NOT EXISTS inv_contrato_detalles_contrato_idx ON public.inv_contrato_detalles(contrato_id);

CREATE TABLE IF NOT EXISTS public.inv_contrato_primas (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 contrato_id uuid NOT NULL UNIQUE REFERENCES public.inv_contratos(id) ON DELETE RESTRICT,
 monto numeric(14,2) NOT NULL CHECK (monto >= 0),
 estado text NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','recibida')),
 fecha_recibida timestamptz,
 registrado_por uuid,
 actualizado_en timestamptz NOT NULL DEFAULT now(),
 CHECK ((estado='pendiente' AND fecha_recibida IS NULL) OR (estado='recibida' AND fecha_recibida IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.inv_prima_eventos (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 prima_id uuid NOT NULL REFERENCES public.inv_contrato_primas(id) ON DELETE RESTRICT,
 estado_anterior text,
 estado_nuevo text NOT NULL,
 usuario uuid NOT NULL,
 fecha timestamptz NOT NULL DEFAULT now(),
 observaciones text
);

-- Por defecto, negar acceso directo a datos sensibles hasta crear RPCs y políticas verificadas.
ALTER TABLE public.inv_clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inv_cliente_referencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inv_contratos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inv_contrato_detalles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inv_contrato_primas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inv_prima_eventos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inv_clientes,public.inv_cliente_referencias,public.inv_contratos,public.inv_contrato_detalles,public.inv_contrato_primas,public.inv_prima_eventos FROM anon,authenticated;
REVOKE ALL ON SEQUENCE public.inv_prima_eventos_id_seq FROM anon,authenticated;
COMMIT;
