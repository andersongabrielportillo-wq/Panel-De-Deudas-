-- FASE 15Q: confirmación atómica de contrato y venta.
-- Requiere 15I, 15J y RPC inv_registrar_venta existente.
-- SOLO para staging después de backup. No ejecutar en producción.
-- El contrato borrador no descuenta inventario.
-- El cliente envía ubicación por línea; el servidor valida todos los detalles.
BEGIN;
CREATE OR REPLACE FUNCTION public.inv_confirmar_contrato(
 p_contrato_id uuid,
 p_ubicaciones jsonb,
 p_client_op_id uuid
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE
 v_contrato public.inv_contratos%ROWTYPE;
 v_linea jsonb;
 v_detalle public.inv_contrato_detalles%ROWTYPE;
 v_venta_lineas jsonb := '[]'::jsonb;
 v_venta_id uuid;
 v_ubicacion smallint;
 v_cantidad_lineas int;
 v_existing_venta uuid;
 v_total numeric := 0;
 v_prima numeric;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.inv_members m
  WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_contrato_id IS NULL OR p_client_op_id IS NULL THEN
  RAISE EXCEPTION 'Identificadores obligatorios'; END IF;
 -- Serializa confirmaciones concurrentes del mismo contrato.
 SELECT * INTO v_contrato FROM public.inv_contratos
 WHERE id=p_contrato_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Contrato no encontrado'; END IF;
 IF v_contrato.estado='confirmado' THEN
   IF v_contrato.venta_id IS NULL THEN RAISE EXCEPTION 'Contrato confirmado sin venta asociada'; END IF;
   -- Solo aceptar un reintento de la MISMA operación; no confundirlo con una nueva venta.
   IF NOT EXISTS(
     SELECT 1 FROM public.inv_ventas v
     WHERE v.id=v_contrato.venta_id AND v.client_op_id=p_client_op_id
   ) THEN RAISE EXCEPTION 'Contrato ya confirmado con otra operación'; END IF;
   RETURN v_contrato.venta_id;
 END IF;
 IF v_contrato.estado<>'borrador' OR v_contrato.venta_id IS NOT NULL
 THEN RAISE EXCEPTION 'Contrato no disponible para confirmar'; END IF;
 IF p_ubicaciones IS NULL OR pg_catalog.jsonb_typeof(p_ubicaciones)<>'array'
 THEN RAISE EXCEPTION 'Ubicaciones inválidas'; END IF;
 SELECT count(*) INTO v_cantidad_lineas
 FROM public.inv_contrato_detalles WHERE contrato_id=p_contrato_id;
 IF v_cantidad_lineas=0 OR v_cantidad_lineas<>pg_catalog.jsonb_array_length(p_ubicaciones)
 THEN RAISE EXCEPTION 'Las ubicaciones deben coincidir con todas las líneas'; END IF;
 FOR v_linea IN SELECT value FROM pg_catalog.jsonb_array_elements(p_ubicaciones) LOOP
   IF pg_catalog.jsonb_typeof(v_linea)<>'object' THEN
     RAISE EXCEPTION 'Línea de ubicación inválida'; END IF;
   IF (v_linea->>'detalle_id') IS NULL OR (v_linea->>'location_id') IS NULL THEN
     RAISE EXCEPTION 'Faltan identificadores de línea o ubicación'; END IF;
   SELECT * INTO v_detalle FROM public.inv_contrato_detalles
   WHERE id=(v_linea->>'detalle_id')::uuid AND contrato_id=p_contrato_id;
   IF NOT FOUND THEN RAISE EXCEPTION 'Línea no pertenece al contrato'; END IF;
   IF EXISTS(
     SELECT 1 FROM pg_catalog.jsonb_array_elements(v_venta_lineas) j
     WHERE j.value->>'detalle_id'=v_detalle.id::text
   ) THEN RAISE EXCEPTION 'Línea de contrato repetida'; END IF;
   IF (v_linea->>'location_id') !~ '^[12]$' THEN
     RAISE EXCEPTION 'Solo se permiten ubicaciones 1 y 2'; END IF;
   v_ubicacion:=(v_linea->>'location_id')::smallint;
   v_total:=v_total+v_detalle.cantidad*v_detalle.precio_credito_unitario;
   v_venta_lineas:=v_venta_lineas||pg_catalog.jsonb_build_array(
     pg_catalog.jsonb_build_object(
       'detalle_id',v_detalle.id,
       'item_id',v_detalle.item_id,
       'location_id',v_ubicacion,
       'cantidad',v_detalle.cantidad,
       'precio_unitario',v_detalle.precio_credito_unitario,
       'descuento',0
     )
   );
 END LOOP;
 SELECT p.monto INTO v_prima FROM public.inv_contrato_primas p
 WHERE p.contrato_id=p_contrato_id;
 IF v_prima IS NULL THEN RAISE EXCEPTION 'El contrato no tiene prima registrada'; END IF;
 IF v_prima>v_total THEN RAISE EXCEPTION 'La prima supera el total del contrato'; END IF;
 IF v_contrato.saldo_inicial IS NOT NULL
   AND v_contrato.saldo_inicial<>v_total-v_prima THEN
   RAISE EXCEPTION 'El saldo inicial no coincide con total menos prima'; END IF;
 -- Serializa también operaciones con el mismo ID, incluso de contratos distintos.
 PERFORM pg_catalog.pg_advisory_xact_lock(
   pg_catalog.hashtextextended(p_client_op_id::text,0)
 );
 -- La venta debe ser nueva: no enlazar una venta anterior a este contrato.
 -- El bloqueo de contrato hace idempotente la repetición posterior.
 SELECT v.id INTO v_existing_venta FROM public.inv_ventas v
 WHERE v.client_op_id=p_client_op_id;
 IF v_existing_venta IS NOT NULL THEN
   RAISE EXCEPTION 'Identificador de operación utilizado anteriormente';
 END IF;
 -- Reutiliza la función de ventas existente, con control de existencias,
 -- movimientos y deduplicación por client_op_id.
 v_venta_id:=public.inv_registrar_venta(
   v_contrato.vendedor_id,
   v_contrato.modalidad,
   v_venta_lineas,
   0,
   'Contrato '||v_contrato.numero,
   p_client_op_id
 );
 UPDATE public.inv_contratos
 SET estado='confirmado',venta_id=v_venta_id,actualizado_en=now()
 WHERE id=p_contrato_id;
 RETURN v_venta_id;
END $$;
REVOKE ALL ON FUNCTION public.inv_confirmar_contrato(uuid,jsonb,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inv_confirmar_contrato(uuid,jsonb,uuid) TO authenticated;
COMMIT;
