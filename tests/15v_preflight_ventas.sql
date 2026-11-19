-- Fase 15V: comprobaciones SOLO LECTURA de dependencias para confirmar contratos.
-- No instala migraciones, no crea ventas y no cambia existencias.
SELECT x.nombre, x.existe FROM (VALUES
 ('inv_venta_detalles',to_regclass('public.inv_venta_detalles') IS NOT NULL),
 ('inv_hash_solicitud_venta',to_regprocedure('public.inv_hash_solicitud_venta(uuid,text,jsonb,numeric,text)') IS NOT NULL),
 ('inv_registrar_venta',to_regprocedure('public.inv_registrar_venta(uuid,text,jsonb,numeric,text,uuid)') IS NOT NULL),
 ('inv_registrar_movimiento',EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='inv_registrar_movimiento')),
 ('verificar_reintento_venta',EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='inv_private' AND p.proname='verificar_reintento_venta')),
 ('inv_ventas.client_op_id_unique',EXISTS(
   SELECT 1 FROM pg_index i
   JOIN pg_class t ON t.oid=i.indrelid
   JOIN pg_namespace n ON n.oid=t.relnamespace
   JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=ANY(i.indkey)
   WHERE n.nspname='public' AND t.relname='inv_ventas'
     AND i.indisunique AND a.attname='client_op_id'
 ))
) x(nombre,existe);
