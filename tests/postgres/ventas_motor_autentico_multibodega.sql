\set ON_ERROR_STOP on
-- Casos E2E adicionales sobre las funciones autenticas y datos sinteticos.
DO $$
DECLARE
 v_admin uuid:='11111111-1111-4111-8111-111111111111';
 v_secretaria uuid:='22222222-2222-4222-8222-222222222222';
 v_vendedor uuid;
 v_cliente uuid;
 v_item uuid;
 v_contrato uuid;
 v_contrato_inactivo uuid;
 v_detalle1 uuid;
 v_detalle2 uuid;
 v_venta uuid;
 v_n integer;
BEGIN
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',v_admin::text,true);
 SELECT id INTO v_vendedor FROM public.inv_vendedores_manual LIMIT 1;
 SELECT id INTO v_cliente FROM public.inv_clientes LIMIT 1;
 INSERT INTO public.inv_items(nombre_original,categoria)
 VALUES ('Ventilador ficticio multibodega','Ficticio') RETURNING id INTO v_item;
 INSERT INTO public.inv_stock(item_id,location_id,cantidad)
 VALUES (v_item,1,7),(v_item,2,5);
 v_contrato:=public.inv_crear_contrato_borrador(
 'CI-VENTA-DOS-UBICACIONES',v_cliente,v_vendedor,current_date,
 'credito','semanal','normal',10,50,NULL,NULL,NULL,NULL,0,10,false,
 pg_catalog.jsonb_build_array(
 pg_catalog.jsonb_build_object('item_id',v_item,'cantidad',2,'precio_credito_unitario',15),
 pg_catalog.jsonb_build_object('item_id',v_item,'cantidad',2,'precio_credito_unitario',15)),NULL);
 SELECT id INTO v_detalle1 FROM public.inv_contrato_detalles
 WHERE contrato_id=v_contrato ORDER BY id LIMIT 1;
 SELECT id INTO v_detalle2 FROM public.inv_contrato_detalles
 WHERE contrato_id=v_contrato ORDER BY id OFFSET 1 LIMIT 1;
 IF v_detalle1=v_detalle2 OR v_detalle2 IS NULL THEN
  RAISE EXCEPTION 'Faltan dos detalles independientes'; END IF;
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',v_secretaria::text,true);
 v_venta:=public.inv_confirmar_contrato(v_contrato,
 pg_catalog.jsonb_build_array(
 pg_catalog.jsonb_build_object('detalle_id',v_detalle1,'location_id',1),
 pg_catalog.jsonb_build_object('detalle_id',v_detalle2,'location_id',2)),
 pg_catalog.gen_random_uuid());
 IF (SELECT cantidad FROM public.inv_stock WHERE item_id=v_item AND location_id=1)<>5
 OR (SELECT cantidad FROM public.inv_stock WHERE item_id=v_item AND location_id=2)<>3
 THEN RAISE EXCEPTION 'Descuento incorrecto entre dos ubicaciones'; END IF;
 IF (SELECT count(*) FROM public.inv_venta_detalles WHERE venta_id=v_venta)<>2
 THEN RAISE EXCEPTION 'Faltan detalles de venta'; END IF;
 IF (SELECT count(*) FROM public.inv_movements WHERE observaciones='Venta '||v_venta::text)<>2
 THEN RAISE EXCEPTION 'Faltan movimientos de salida'; END IF;
 IF (SELECT total FROM public.inv_ventas WHERE id=v_venta)<>60
 THEN RAISE EXCEPTION 'Total de venta incorrecto'; END IF;
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',v_admin::text,true);
 v_contrato_inactivo:=public.inv_crear_contrato_borrador(
 'CI-VENTA-VENDEDOR-INACTIVO',v_cliente,v_vendedor,current_date,
 'credito','semanal','normal',10,20,NULL,NULL,NULL,NULL,0,10,false,
 pg_catalog.jsonb_build_array(
 pg_catalog.jsonb_build_object('item_id',v_item,'cantidad',2,'precio_credito_unitario',15)),NULL);
 SELECT id INTO v_detalle1 FROM public.inv_contrato_detalles
 WHERE contrato_id=v_contrato_inactivo LIMIT 1;
 UPDATE public.inv_vendedores_manual SET activo=false WHERE id=v_vendedor;
 BEGIN
  PERFORM public.inv_confirmar_contrato(v_contrato_inactivo,
   pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
    'detalle_id',v_detalle1,'location_id',1)),pg_catalog.gen_random_uuid());
  RAISE EXCEPTION 'Se permitio vendedor inactivo';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'Vendedor manual inactivo o no registrado' THEN RAISE; END IF;
 END;
 IF (SELECT cantidad FROM public.inv_stock WHERE item_id=v_item AND location_id=1)<>5
 THEN RAISE EXCEPTION 'Vendedor inactivo desconto existencias'; END IF;
 IF EXISTS(SELECT 1 FROM public.inv_contratos WHERE id=v_contrato_inactivo AND estado<>'borrador')
 THEN RAISE EXCEPTION 'Vendedor inactivo confirmo contrato'; END IF;
 SELECT count(*) INTO v_n FROM public.inv_ventas;
 IF v_n<>2 THEN RAISE EXCEPTION 'Venta rechazada creo registro'; END IF;
END $$;
\echo 'Dos ubicaciones, secretaria, total y vendedor inactivo: OK'
