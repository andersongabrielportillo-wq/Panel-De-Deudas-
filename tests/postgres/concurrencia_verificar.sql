\set ON_ERROR_STOP on
DO $$
DECLARE n int; v_venta uuid; v_item uuid;
BEGIN
 SELECT item_id INTO v_item FROM public.ci_concurrencia_ids;
 SELECT count(*) INTO n FROM public.inv_ventas v JOIN public.inv_contratos c ON c.venta_id=v.id
 WHERE c.numero='CI-CONCURRENCIA';
 IF n<>1 THEN RAISE EXCEPTION 'Concurrencia creo % ventas (esperada 1)',n; END IF;
 SELECT venta_id INTO v_venta FROM public.inv_contratos WHERE numero='CI-CONCURRENCIA';
 IF (SELECT cantidad FROM public.inv_stock WHERE item_id=v_item AND location_id=1)<>3
 THEN RAISE EXCEPTION 'Concurrencia desconto dos veces'; END IF;
 IF (SELECT count(*) FROM public.inv_movements WHERE observaciones='Venta '||v_venta::text)<>1
 THEN RAISE EXCEPTION 'Concurrencia genero movimientos duplicados'; END IF;
 IF (SELECT count(*) FROM public.inv_venta_detalles WHERE venta_id=v_venta)<>1
 THEN RAISE EXCEPTION 'Concurrencia genero detalles duplicados'; END IF;
END $$;
\echo 'Concurrencia: una venta, un movimiento, stock correcto'
