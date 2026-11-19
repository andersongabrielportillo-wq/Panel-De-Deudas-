-- Preflight SOLO LECTURA: contrato 15Q -> inv_registrar_venta existente.
-- Inspección estática del cuerpo SQL, NO sustituye una venta transaccional en staging.
WITH f AS (
 SELECT pg_catalog.pg_get_functiondef(p.oid) AS body,
        pg_catalog.pg_get_function_identity_arguments(p.oid) AS args,
        pg_catalog.pg_get_function_result(p.oid) AS result
 FROM pg_catalog.pg_proc p
 JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='inv_registrar_venta'
 LIMIT 1
), checks AS (
 SELECT 'signature' AS check_name, EXISTS(SELECT 1 FROM f WHERE result='uuid' AND args LIKE '%p_articulos jsonb%') AS ok
 UNION ALL SELECT 'item_id', EXISTS(SELECT 1 FROM f WHERE body LIKE '%->>''item_id''%')
 UNION ALL SELECT 'location_id', EXISTS(SELECT 1 FROM f WHERE body LIKE '%->>''location_id''%')
 UNION ALL SELECT 'cantidad', EXISTS(SELECT 1 FROM f WHERE body LIKE '%->>''cantidad''%')
 UNION ALL SELECT 'precio_unitario', EXISTS(SELECT 1 FROM f WHERE body LIKE '%->>''precio_unitario''%')
 UNION ALL SELECT 'descuento', EXISTS(SELECT 1 FROM f WHERE body LIKE '%->>''descuento''%')
 UNION ALL SELECT 'stock via inv_registrar_movimiento', EXISTS(SELECT 1 FROM f WHERE body LIKE '%public.inv_registrar_movimiento(%')
 UNION ALL SELECT 'dedup via verificar_reintento_venta', EXISTS(SELECT 1 FROM f WHERE body LIKE '%inv_private.verificar_reintento_venta(%')
)
SELECT check_name,ok FROM checks ORDER BY check_name;
