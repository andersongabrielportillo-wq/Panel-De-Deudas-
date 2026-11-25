-- Integration draft. Review and test on an isolated database before deployment.
-- No customer or employee data belongs in this repository.
BEGIN;
CREATE OR REPLACE FUNCTION public.inv_registrar_contrato_integrado(
 p_contrato jsonb, p_ubicaciones jsonb, p_client_op_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $$
DECLARE
 v_id uuid; v_venta uuid; v_detail jsonb; v_alloc jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_client_op_id IS NULL OR jsonb_typeof(p_contrato) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_ubicaciones) IS DISTINCT FROM 'object'
 THEN RAISE EXCEPTION 'Datos de operación inválidos'; END IF;
 -- Existing authorized RPCs perform member/role checks and all stock validation.
 v_id:=public.inv_crear_contrato_borrador(
 p_contrato->>'p_numero',(p_contrato->>'p_cliente_id')::uuid,
 (p_contrato->>'p_vendedor_id')::uuid,(p_contrato->>'p_fecha')::date,
 p_contrato->>'p_modalidad',p_contrato->>'p_frecuencia',p_contrato->>'p_plan',
 (p_contrato->>'p_cuota')::numeric,(p_contrato->>'p_saldo_inicial')::numeric,
 (p_contrato->>'p_fecha_plan')::date,p_contrato->>'p_ruta',p_contrato->>'p_dia_cobro',
 p_contrato->>'p_receptor_alterno',(p_contrato->>'p_comision')::numeric,
 (p_contrato->>'p_prima')::numeric,(p_contrato->>'p_prima_recibida')::boolean,
 p_contrato->'p_detalles',p_contrato->>'p_observaciones');
 v_detail:=public.inv_detalle_contrato(v_id);
 SELECT jsonb_agg(jsonb_build_object('detalle_id',d->>'detalle_id',
 'location_id',p_ubicaciones->(d->>'item_id'))) INTO v_alloc
 FROM jsonb_array_elements(v_detail->'articulos') AS x(d);
 -- Confirmation failure rolls back the draft and all stock/sale changes.
 v_venta:=public.inv_confirmar_contrato(v_id,v_alloc,p_client_op_id);
 RETURN jsonb_build_object('contrato_id',v_id,'venta_id',v_venta);
END;
$$;
REVOKE ALL ON FUNCTION public.inv_registrar_contrato_integrado(jsonb,jsonb,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv_registrar_contrato_integrado(jsonb,jsonb,uuid) TO authenticated;
COMMIT;
