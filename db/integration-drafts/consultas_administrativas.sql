-- Draft: live projections from the authoritative sales and contracts.
-- Apply planillas_y_abonos.sql first. No historical or personal data is included here. Do not deploy before isolated tests.
BEGIN;
CREATE SCHEMA IF NOT EXISTS cln_admin_internal;
REVOKE ALL ON SCHEMA cln_admin_internal FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA cln_admin_internal TO authenticated;

CREATE OR REPLACE FUNCTION cln_admin_internal.consultar(
 p_tipo text, p_desde date, p_hasta date, p_pagina integer
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_rows jsonb; v_offset integer;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
 SELECT 1 FROM public.inv_members m WHERE m.user_id=auth.uid()
 AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_tipo NOT IN ('libro','rutas','planillas') OR p_tipo IS NULL
 OR p_desde IS NULL OR p_hasta IS NULL OR p_desde>p_hasta
 OR p_hasta-p_desde>366 OR p_pagina IS NULL OR p_pagina NOT BETWEEN 0 AND 10000
 THEN RAISE EXCEPTION 'Consulta inválida'; END IF;
 -- Payroll is restricted to admin pending an explicit payroll access policy.
 IF p_tipo='planillas' AND NOT EXISTS (
 SELECT 1 FROM public.inv_members m WHERE m.user_id=auth.uid() AND m.rol='admin'
 ) THEN RAISE EXCEPTION 'Planillas: acceso reservado al administrador'; END IF;
 v_offset:=p_pagina*100;
 IF p_tipo='libro' THEN
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (
 SELECT coalesce(c.fecha,v.fecha) AS fecha,v.numero AS venta,c.numero AS contrato,
 cl.nombre AS cliente,s.nombre AS vendedor,v.modalidad,v.total,
 CASE WHEN v.estado='anulada' OR c.estado='anulado' THEN 'anulada' ELSE v.estado END AS estado
 FROM public.inv_ventas v
 JOIN public.inv_vendedores s ON s.id=v.vendedor_id
 LEFT JOIN public.inv_contratos c ON c.venta_id=v.id
 LEFT JOIN public.inv_clientes cl ON cl.id=c.cliente_id
 WHERE coalesce(c.fecha,v.fecha) BETWEEN p_desde AND p_hasta
 ORDER BY coalesce(c.fecha,v.fecha) DESC,v.id
 LIMIT 101 OFFSET v_offset
 ) x;
 ELSIF p_tipo='rutas' THEN
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (
 SELECT c.id AS contrato_id,c.fecha,c.numero AS contrato,cl.nombre AS cliente,
 nullif(trim(c.ruta),'') AS ruta,c.frecuencia,c.dia_cobro,c.plan,c.fecha_plan,
 c.cuota,v.total,
 CASE WHEN p.estado='recibida' THEN p.monto ELSE 0 END AS prima_recibida,
 coalesce(a.pagado,0) AS abonos,
 greatest(0,v.total-CASE WHEN p.estado='recibida' THEN p.monto ELSE 0 END-coalesce(a.pagado,0)) AS saldo_pendiente
 FROM public.inv_contratos c
 JOIN public.inv_ventas v ON v.id=c.venta_id
 JOIN public.inv_clientes cl ON cl.id=c.cliente_id
 LEFT JOIN public.inv_contrato_primas p ON p.contrato_id=c.id
 LEFT JOIN LATERAL (SELECT sum(monto) AS pagado FROM public.cln_route_payments a WHERE a.contrato_id=c.id) a ON true
 WHERE c.estado='confirmado' AND v.estado='registrada' AND v.anulada_en IS NULL
 AND c.modalidad='credito' AND c.fecha BETWEEN p_desde AND p_hasta
 ORDER BY c.ruta NULLS LAST,cl.nombre,c.id
 LIMIT 101 OFFSET v_offset
 ) x;
 ELSE
 -- This is only the sales contribution, not a complete payroll calculation.
 -- Historical Excel imports must go to separate legacy tables and not into these aggregates.
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) INTO v_rows FROM (
 SELECT pp.id AS persona_id,pp.nombre AS vendedor,x.contratos,x.ventas_confirmadas,x.comision_registrada
 FROM public.cln_payroll_people pp
 LEFT JOIN LATERAL (SELECT nullif(count(*),0) AS contratos,sum(v.total) AS ventas_confirmadas,
 sum(c.comision_total) AS comision_registrada
 FROM public.inv_contratos c JOIN public.inv_ventas v ON v.id=c.venta_id
 WHERE c.vendedor_id=pp.vendedor_id AND c.estado='confirmado' AND v.estado='registrada' AND v.anulada_en IS NULL
 AND c.fecha BETWEEN p_desde AND p_hasta) x ON true
 ORDER BY pp.nombre,pp.id
 LIMIT 101 OFFSET v_offset
 ) x;
 END IF;
 RETURN jsonb_build_object('filas',CASE WHEN jsonb_array_length(v_rows)>100 THEN v_rows-100 ELSE v_rows END,
 'hay_mas',jsonb_array_length(v_rows)>100);
END;
$$;
REVOKE ALL ON FUNCTION cln_admin_internal.consultar(text,date,date,integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION cln_admin_internal.consultar(text,date,date,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.cln_consultar_integracion(
 p_tipo text,p_desde date,p_hasta date,p_pagina integer DEFAULT 0
) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $$ SELECT cln_admin_internal.consultar(p_tipo,p_desde,p_hasta,p_pagina) $$;
REVOKE ALL ON FUNCTION public.cln_consultar_integracion(text,date,date,integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cln_consultar_integracion(text,date,date,integer) TO authenticated;
COMMIT;
