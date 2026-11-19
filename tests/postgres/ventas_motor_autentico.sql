\set ON_ERROR_STOP on
-- PRUEBA REAL EN POSTGRESQL con FUNCIONES AUTENTICAS copiadas de staging sobre datos sinteticos.
DO $$
DECLARE
 v_admin uuid:='11111111-1111-4111-8111-111111111111';
 v_vendedor uuid;
 v_cliente uuid;
 v_item uuid;
 v_item2 uuid;
 v_contrato uuid;
 v_contrato_fallo uuid;
 v_detalle uuid;
 v_detalle2 uuid;
 v_venta uuid;
 v_reintento uuid;
 v_op uuid:=pg_catalog.gen_random_uuid();
 v_n int;
BEGIN
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',v_admin::text,true);
 SELECT id INTO v_vendedor FROM public.inv_vendedores_manual LIMIT 1;
 SELECT id INTO v_cliente FROM public.inv_clientes LIMIT 1;
 INSERT INTO public.inv_items(nombre_original,categoria) VALUES ('Licuadora prueba CI','Ficticio') RETURNING id INTO v_item;
 INSERT INTO public.inv_stock(item_id,location_id,cantidad) VALUES (v_item,1,8);
 v_contrato:=public.inv_crear_contrato_borrador(
 'CI-VENTA-OK',v_cliente,v_vendedor,current_date,'credito','semanal','normal',
 10,50,NULL,NULL,NULL,NULL,0,10,false,
 pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
 'item_id',v_item,'cantidad',2,'precio_credito_unitario',30)),NULL);
 SELECT d.id INTO v_detalle FROM public.inv_contrato_detalles d WHERE d.contrato_id=v_contrato;
 IF (SELECT cantidad FROM public.inv_stock WHERE item_id=v_item AND location_id=1)<>8
 THEN RAISE EXCEPTION 'Borrador desconto stock'; END IF;
 v_venta:=public.inv_confirmar_contrato(v_contrato,pg_catalog.jsonb_build_array(
 pg_catalog.jsonb_build_object('detalle_id',v_detalle,'location_id',1)),v_op);
 IF (SELECT cantidad FROM public.inv_stock WHERE item_id=v_item AND location_id=1)<>6
 THEN RAISE EXCEPTION 'Venta no desconto exactamente 2'; END IF;
 IF (SELECT count(*) FROM public.inv_movements WHERE observaciones='Venta '||v_venta::text)<>1
 THEN RAISE EXCEPTION 'Movimientos inesperados'; END IF;
 v_reintento:=public.inv_confirmar_contrato(v_contrato,pg_catalog.jsonb_build_array(
 pg_catalog.jsonb_build_object('detalle_id',v_detalle,'location_id',1)),v_op);
 IF v_reintento<>v_venta OR (SELECT cantidad FROM public.inv_stock WHERE item_id=v_item AND location_id=1)<>6
 THEN RAISE EXCEPTION 'Reintento duplico descuento'; END IF;
 BEGIN
  PERFORM public.inv_confirmar_contrato(v_contrato,pg_catalog.jsonb_build_array(
  pg_catalog.jsonb_build_object('detalle_id',v_detalle,'location_id',1)),pg_catalog.gen_random_uuid());
  RAISE EXCEPTION 'Permitio segunda operacion';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'Contrato ya confirmado con otra operación' THEN RAISE; END IF;
 END;
 INSERT INTO public.inv_items(nombre_original,categoria) VALUES ('Horno ficticio sin stock','Ficticio') RETURNING id INTO v_item2;
 INSERT INTO public.inv_stock(item_id,location_id,cantidad) VALUES (v_item2,1,0);
 v_contrato_fallo:=public.inv_crear_contrato_borrador(
 'CI-VENTA-ROLLBACK',v_cliente,v_vendedor,current_date,'credito','semanal','normal',
 10,50,NULL,NULL,NULL,NULL,0,10,false,
 pg_catalog.jsonb_build_array(
 pg_catalog.jsonb_build_object('item_id',v_item,'cantidad',1,'precio_credito_unitario',30),
 pg_catalog.jsonb_build_object('item_id',v_item2,'cantidad',1,'precio_credito_unitario',30)),NULL);
 SELECT d.id INTO v_detalle FROM public.inv_contrato_detalles d WHERE d.contrato_id=v_contrato_fallo AND d.item_id=v_item;
 SELECT d.id INTO v_detalle2 FROM public.inv_contrato_detalles d WHERE d.contrato_id=v_contrato_fallo AND d.item_id=v_item2;
 BEGIN
  PERFORM public.inv_confirmar_contrato(v_contrato_fallo,pg_catalog.jsonb_build_array(
  pg_catalog.jsonb_build_object('detalle_id',v_detalle,'location_id',1),
  pg_catalog.jsonb_build_object('detalle_id',v_detalle2,'location_id',1)),pg_catalog.gen_random_uuid());
  RAISE EXCEPTION 'Permitio venta sin stock';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM NOT LIKE 'Existencias insuficientes.%' THEN RAISE; END IF;
 END;
 IF (SELECT cantidad FROM public.inv_stock WHERE item_id=v_item AND location_id=1)<>6
 THEN RAISE EXCEPTION 'Rollback dejo descuento parcial'; END IF;
 IF EXISTS(SELECT 1 FROM public.inv_contratos WHERE id=v_contrato_fallo AND (estado<>'borrador' OR venta_id IS NOT NULL))
 THEN RAISE EXCEPTION 'Rollback dejo contrato confirmado'; END IF;
 SELECT count(*) INTO v_n FROM public.inv_ventas;
 IF v_n<>1 THEN RAISE EXCEPTION 'Rollback dejo venta huerfana'; END IF;
 SELECT count(*) INTO v_n FROM public.inv_movements;
 IF v_n<>1 THEN RAISE EXCEPTION 'Rollback dejo movimiento parcial'; END IF;
END $$;
\echo 'Venta, descuento, idempotencia y rollback: OK (funciones autenticas)'
