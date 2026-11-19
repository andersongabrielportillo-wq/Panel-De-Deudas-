-- Fase 15Z: preflight de solo lectura en staging ANTES de instalar contratos.
-- La confirmación de contratos depende de estas firmas EXACTAS.
WITH requeridas(nombre,firma) AS (
 VALUES
 ('inv_registrar_venta','p_vendedor_id uuid, p_modalidad text, p_articulos jsonb, p_descuento numeric, p_observaciones text, p_client_op_id uuid'),
 ('inv_registrar_movimiento','p_item_id uuid, p_tipo text, p_origen smallint, p_destino smallint, p_cantidad integer, p_vendedor text, p_observaciones text, p_client_op_id uuid'),
 ('inv_anular_venta','p_venta_id uuid, p_motivo text')
)
SELECT r.nombre,r.firma,
       (p.oid IS NOT NULL AND p.prosecdef) AS compatible
FROM requeridas r
LEFT JOIN pg_catalog.pg_namespace n ON n.nspname='public'
LEFT JOIN pg_catalog.pg_proc p
  ON p.pronamespace=n.oid AND p.proname=r.nombre
 AND pg_catalog.pg_get_function_identity_arguments(p.oid)=r.firma
ORDER BY r.nombre;
