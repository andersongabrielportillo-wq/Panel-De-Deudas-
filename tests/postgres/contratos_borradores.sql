\set ON_ERROR_STOP on
-- Operaciones reales de contratos sobre PostgreSQL 16 EFIMERO con venta simulada.
DO $$
DECLARE
 admin_id uuid:='11111111-1111-4111-8111-111111111111';
 empleado_id uuid:='33333333-3333-4333-8333-333333333333';
 vendedor_id uuid;
 cliente_id uuid;
 v_item_id uuid;
 v_contrato_id uuid;
 n int;
BEGIN
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',admin_id::text,true);
 SELECT id INTO vendedor_id FROM public.inv_vendedores_manual LIMIT 1;
 IF vendedor_id IS NULL THEN RAISE EXCEPTION 'Falta vendedor ficticio'; END IF;
 INSERT INTO public.inv_items(nombre_original,categoria) VALUES('Cafetera ficticia','Electrodomesticos') RETURNING id INTO v_item_id;
 cliente_id:=public.inv_crear_cliente('Cliente Ficticio','123456789',NULL,NULL,NULL,NULL,NULL,NULL,'[]'::jsonb);
 IF NOT EXISTS(SELECT 1 FROM public.inv_clientes WHERE id=cliente_id AND dui='12345678-9')
 THEN RAISE EXCEPTION 'Cliente o DUI no persistido'; END IF;
 v_contrato_id:=public.inv_crear_contrato_borrador(
 'CI-FICTICIO-001',cliente_id,vendedor_id,current_date,'credito','semanal','normal',
 25,75,NULL,'Ruta ficticia','lunes',NULL,0,25,false,
 pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
 'item_id',v_item_id,'cantidad',2,'precio_credito_unitario',50,'comision_linea',0)),
 'Solo pruebas');
 IF NOT EXISTS(SELECT 1 FROM public.inv_contratos WHERE id=v_contrato_id AND estado='borrador' AND venta_id IS NULL)
 THEN RAISE EXCEPTION 'Contrato borrador no valido'; END IF;
 SELECT count(*) INTO n FROM public.inv_ventas;
 IF n<>0 THEN RAISE EXCEPTION 'El borrador genero una venta'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.inv_contrato_detalles d WHERE d.contrato_id=v_contrato_id AND d.item_id=v_item_id AND d.cantidad=2)
 THEN RAISE EXCEPTION 'Detalle de contrato incorrecto'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.inv_contrato_primas p WHERE p.contrato_id=v_contrato_id AND p.monto=25 AND estado='pendiente')
 THEN RAISE EXCEPTION 'Prima incorrecta'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.inv_prima_eventos e JOIN public.inv_contrato_primas p ON p.id=e.prima_id WHERE p.contrato_id=v_contrato_id)
 THEN RAISE EXCEPTION 'Falta evento de auditoria de prima'; END IF;
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',empleado_id::text,true);
 BEGIN
  PERFORM public.inv_crear_cliente('Cliente no permitido',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'[]'::jsonb);
  RAISE EXCEPTION 'Empleado creo cliente';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'No autorizado' THEN RAISE; END IF;
 END;
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',admin_id::text,true);
 BEGIN
  PERFORM public.inv_crear_contrato_borrador(
 'CI-FICTICIO-002',cliente_id,vendedor_id,current_date,'credito','semanal','normal',
 25,75,NULL,NULL,NULL,NULL,0,25,false,
 pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
 'item_id',v_item_id,'cantidad',0,'precio_credito_unitario',50)),
 NULL);
  RAISE EXCEPTION 'Se acepto cantidad cero';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM NOT LIKE 'Cantidad debe%' THEN RAISE; END IF;
 END;
 SELECT count(*) INTO n FROM public.inv_contratos;
 IF n<>1 THEN RAISE EXCEPTION 'El contrato invalido dejo escrituras parciales'; END IF;
END $$;
\echo 'Cliente, contrato borrador, detalle, prima, auditoria y rechazo: OK'
