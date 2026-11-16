-- FASE 15T: diagnóstico de solo lectura, antes de instalar contratos.
-- Ejecutar en proyecto de pruebas; no modifica tablas, datos ni permisos.
SELECT 'tablas_contratos_ausentes' AS prueba,
       count(*)::text AS resultado
FROM (VALUES ('inv_clientes'),('inv_cliente_referencias'),('inv_contratos'),
 ('inv_contrato_detalles'),('inv_contrato_primas'),('inv_prima_eventos')) AS esperadas(nombre)
WHERE NOT EXISTS(
 SELECT 1 FROM information_schema.tables t
 WHERE t.table_schema='public' AND t.table_name=esperadas.nombre
)
UNION ALL
SELECT 'rpc_ventas_existente', EXISTS(
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='inv_registrar_venta'
)::text
UNION ALL
SELECT 'rpc_movimientos_existente', EXISTS(
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='inv_registrar_movimiento'
)::text
UNION ALL
SELECT 'vendedores_existentes', count(*)::text FROM public.inv_vendedores
UNION ALL
SELECT 'articulos_activos', count(*)::text FROM public.inv_items WHERE estado='activo';
-- Orden de instalación tras revisión y respaldo:
-- 15I (tablas), 15J (RPC clientes/contratos), 15K (vendedores),
-- 15N (catálogos/ficha), 15P (historial), 15Q (confirmación).
-- No aplicar sobre producción.
