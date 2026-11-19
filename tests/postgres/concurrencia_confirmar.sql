\set ON_ERROR_STOP on
BEGIN;
SET LOCAL request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
-- Ambos procesos confirman exactamente el mismo contrato y la misma operacion.
SELECT public.inv_confirmar_contrato(contrato_id,
 pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('detalle_id',detalle_id,'location_id',1)),op_id)
FROM public.ci_concurrencia_ids;
COMMIT;
