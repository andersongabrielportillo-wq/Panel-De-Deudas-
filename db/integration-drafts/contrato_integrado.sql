-- Integration draft. Review and test on an isolated database before deployment.
-- No customer or employee data belongs in this repository.
BEGIN;
CREATE SCHEMA IF NOT EXISTS cln_admin_internal;
REVOKE ALL ON SCHEMA cln_admin_internal FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA cln_admin_internal TO authenticated;
CREATE TABLE IF NOT EXISTS cln_admin_internal.contract_operations (
 op_id uuid PRIMARY KEY, actor uuid NOT NULL, fingerprint text NOT NULL, result jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE cln_admin_internal.contract_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON cln_admin_internal.contract_operations FROM PUBLIC, anon, authenticated;
CREATE OR REPLACE FUNCTION cln_admin_internal.registrar_contrato_integrado(
 p_contrato jsonb, p_ubicaciones jsonb, p_client_op_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
 v_id uuid; v_venta uuid; v_detail jsonb; v_alloc jsonb;
 v_actor uuid:=auth.uid(); v_fingerprint text; v_result jsonb; v_previous cln_admin_internal.contract_operations%ROWTYPE;
BEGIN
 IF v_actor IS NULL OR NOT EXISTS(SELECT 1 FROM public.inv_members m WHERE m.user_id=v_actor AND m.rol IN ('admin','secretaria')) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_client_op_id IS NULL OR jsonb_typeof(p_contrato) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_ubicaciones) IS DISTINCT FROM 'object'
 THEN RAISE EXCEPTION 'Datos de operación inválidos'; END IF;
 v_fingerprint:=pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(jsonb_build_array(p_contrato,p_ubicaciones)::text,'UTF8')),'hex');
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_client_op_id::text,3));
 SELECT * INTO v_previous FROM cln_admin_internal.contract_operations WHERE op_id=p_client_op_id;
 IF FOUND THEN
  IF v_previous.actor IS DISTINCT FROM v_actor OR v_previous.fingerprint IS DISTINCT FROM v_fingerprint THEN RAISE EXCEPTION 'Operación utilizada con otros datos'; END IF;
  RETURN v_previous.result;
 END IF;
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
 v_result:=jsonb_build_object('contrato_id',v_id,'venta_id',v_venta);
 INSERT INTO cln_admin_internal.contract_operations(op_id,actor,fingerprint,result) VALUES(p_client_op_id,v_actor,v_fingerprint,v_result);
 RETURN v_result;
END;
$$;
REVOKE ALL ON FUNCTION cln_admin_internal.registrar_contrato_integrado(jsonb,jsonb,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION cln_admin_internal.registrar_contrato_integrado(jsonb,jsonb,uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.inv_registrar_contrato_integrado(p_contrato jsonb,p_ubicaciones jsonb,p_client_op_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $ SELECT cln_admin_internal.registrar_contrato_integrado(p_contrato,p_ubicaciones,p_client_op_id) $;
REVOKE ALL ON FUNCTION public.inv_registrar_contrato_integrado(jsonb,jsonb,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv_registrar_contrato_integrado(jsonb,jsonb,uuid) TO authenticated;
COMMIT;
