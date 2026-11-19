-- FASE 15U — Verificación de dependencias (solo lectura).
-- No instala migraciones, no modifica datos y no requiere credenciales de clientes.
WITH requisitos(tipo,nombre) AS (
 VALUES
 ('tabla','inv_members'),('tabla','inv_items'),('tabla','inv_vendedores'),
 ('tabla','inv_ventas'),('tabla','inv_movements'),
 ('columna','inv_items.nombre_original'),('columna','inv_items.estado'),
 ('columna','inv_vendedores.activo'),('columna','inv_ventas.client_op_id'),
 ('columna','inv_members.rol'),
 ('funcion','inv_registrar_venta'),('funcion','inv_registrar_movimiento')
)
SELECT tipo,nombre,
 CASE
 WHEN tipo='tabla' THEN EXISTS (
   SELECT 1 FROM information_schema.tables t
   WHERE t.table_schema='public' AND t.table_name=r.nombre)
 WHEN tipo='columna' THEN EXISTS (
   SELECT 1 FROM information_schema.columns c
   WHERE c.table_schema='public'
     AND c.table_name=split_part(r.nombre,'.',1)
     AND c.column_name=split_part(r.nombre,'.',2))
 WHEN tipo='funcion' THEN EXISTS (
   SELECT 1 FROM pg_catalog.pg_proc p
   JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname=r.nombre)
 ELSE false END AS disponible
FROM requisitos r ORDER BY tipo,nombre;
