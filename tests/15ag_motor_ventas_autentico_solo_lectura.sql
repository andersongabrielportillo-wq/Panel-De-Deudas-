-- FASE 15: compatibilidad con el motor AUTENTICO de inventario.
-- Solo lectura: no crea contratos, ventas ni movimientos.
WITH controles AS (
 SELECT 'rpc_venta_original' AS control,
  to_regprocedure('public.inv_registrar_venta(uuid,text,jsonb,numeric,text,uuid)') IS NOT NULL AS ok
 UNION ALL SELECT 'rpc_movimiento_original',
  to_regprocedure('public.inv_registrar_movimiento(uuid,text,smallint,smallint,integer,text,text,uuid)') IS NOT NULL
 UNION ALL SELECT 'huella_de_solicitud',
  to_regprocedure('public.inv_hash_solicitud_venta(uuid,text,jsonb,numeric,text)') IS NOT NULL
 UNION ALL SELECT 'reintento_privado',
  to_regprocedure('inv_private.verificar_reintento_venta(uuid,text)') IS NOT NULL
 UNION ALL SELECT 'tabla_stock',to_regclass('public.inv_stock') IS NOT NULL
 UNION ALL SELECT 'tabla_movimientos',to_regclass('public.inv_movements') IS NOT NULL
 UNION ALL SELECT 'tabla_detalles_venta',to_regclass('public.inv_venta_detalles') IS NOT NULL
 UNION ALL SELECT 'tabla_ubicaciones',to_regclass('public.inv_locations') IS NOT NULL
 UNION ALL SELECT 'tabla_vendedores',to_regclass('public.inv_vendedores') IS NOT NULL
 UNION ALL SELECT 'venta_utiliza_movimiento_original',
  EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='inv_registrar_venta'
  AND pg_get_functiondef(p.oid) LIKE '%public.inv_registrar_movimiento(%')
 UNION ALL SELECT 'movimiento_descontara_stock',
  EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='inv_registrar_movimiento'
  AND pg_get_functiondef(p.oid) LIKE '%UPDATE public.inv_stock%')
 UNION ALL SELECT 'venta_con_bloqueo_idempotente',
  EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='inv_registrar_venta'
  AND pg_get_functiondef(p.oid) LIKE '%pg_advisory_xact_lock%')
)
SELECT control,ok FROM controles ORDER BY control;
-- Esta auditoria no prueba una venta real ni certifica concurrencia.
