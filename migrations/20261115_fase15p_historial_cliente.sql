-- FASE 15P: historial de contratos por cliente y detalle seguro.
-- Requiere 15I. Solo staging. No altera inventario ni confirma ventas.
BEGIN;
CREATE OR REPLACE FUNCTION public.inv_historial_cliente(p_cliente_id uuid)
RETURNS TABLE(
 contrato_id uuid,numero text,fecha date,estado text,modalidad text,
 vendedor_nombre text,total_articulos numeric,prima numeric,prima_estado text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
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
END $$;

CREATE OR REPLACE FUNCTION public.inv_detalle_contrato(p_contrato_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
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
END $$;
REVOKE ALL ON FUNCTION public.inv_historial_cliente(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_detalle_contrato(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inv_historial_cliente(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_detalle_contrato(uuid) TO authenticated;
COMMIT;
