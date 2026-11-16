-- Preflight solo lectura: dependencias de 15Q en inventario existente.
-- Ejecutar antes de instalar migraciones. No crea ventas ni cambia existencias.
WITH funciones AS (
 SELECT p.proname, p.prosecdef, pg_get_function_identity_arguments(p.oid) AS firma
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname IN ('inv_registrar_venta','inv_registrar_movimiento')
), columnas AS (
 SELECT table_name,column_name FROM information_schema.columns
 WHERE table_schema='public' AND table_name IN ('inv_ventas','inv_venta_detalles','inv_items')
), verificaciones AS (
 SELECT 'RPC inv_registrar_venta SECURITY DEFINER' AS comprobacion,
 EXISTS(SELECT 1 FROM funciones WHERE proname='inv_registrar_venta' AND prosecdef) AS correcto
 UNION ALL SELECT 'RPC inv_registrar_movimiento SECURITY DEFINER',
 EXISTS(SELECT 1 FROM funciones WHERE proname='inv_registrar_movimiento' AND prosecdef)
 UNION ALL SELECT 'inv_ventas.client_op_id',
 EXISTS(SELECT 1 FROM columnas WHERE table_name='inv_ventas' AND column_name='client_op_id')
 UNION ALL SELECT 'inv_ventas.anulada_en',
 EXISTS(SELECT 1 FROM columnas WHERE table_name='inv_ventas' AND column_name='anulada_en')
 UNION ALL SELECT 'inv_venta_detalles.location_id',
 EXISTS(SELECT 1 FROM columnas WHERE table_name='inv_venta_detalles' AND column_name='location_id')
 UNION ALL SELECT 'inv_venta_detalles.movimiento_id',
 EXISTS(SELECT 1 FROM columnas WHERE table_name='inv_venta_detalles' AND column_name='movimiento_id')
 UNION ALL SELECT 'inv_items.estado',
 EXISTS(SELECT 1 FROM columnas WHERE table_name='inv_items' AND column_name='estado')
)
SELECT comprobacion,correcto FROM verificaciones ORDER BY comprobacion;
