-- FASE 15K — Historial de vendedores y detalle de contratos
-- Depende de migraciones 15I y 15J. Solo aplicar en ambiente aislado y probar JWT.
BEGIN;

CREATE OR REPLACE FUNCTION public.inv_historial_vendedor(
 p_vendedor_id uuid,
 p_desde date DEFAULT NULL,
 p_hasta date DEFAULT NULL
)
RETURNS TABLE (
 contrato_id uuid,
 numero text,
 fecha date,
 cliente_nombre text,
 estado text,
 modalidad text,
 total_articulos numeric,
 comision numeric,
 comision_estado text,
 prima numeric,
 prima_estado text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.inv_members m
  WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_vendedor_id IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.inv_vendedores v WHERE v.id=p_vendedor_id
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
END $$;

CREATE OR REPLACE FUNCTION public.inv_resumen_vendedor(
 p_vendedor_id uuid,
 p_desde date DEFAULT NULL,
 p_hasta date DEFAULT NULL
)
RETURNS TABLE(
 contratos bigint,
 contratos_confirmados bigint,
 ventas_brutas numeric,
 comisiones_generadas numeric,
 comisiones_pendientes numeric,
 primas_recibidas numeric,
 primas_pendientes numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.inv_members m
  WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_vendedor_id IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.inv_vendedores v WHERE v.id=p_vendedor_id
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
END $$;

REVOKE ALL ON FUNCTION public.inv_historial_vendedor(uuid,date,date) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_resumen_vendedor(uuid,date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inv_historial_vendedor(uuid,date,date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_resumen_vendedor(uuid,date,date) TO authenticated;
COMMIT;
