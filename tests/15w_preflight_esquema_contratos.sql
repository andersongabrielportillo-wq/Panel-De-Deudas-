-- Fase 15W: SOLO LECTURA. Ejecutar antes de instalar contratos en staging.
-- Verifica las columnas que requieren 15I/15J/15K/15N/15P/15Q.
WITH requisitos(tabla,columna,tipo) AS (
 VALUES
 ('inv_members','user_id','uuid'),('inv_members','rol','text'),
 ('inv_items','id','uuid'),('inv_items','nombre_original','text'),
 ('inv_items','estado','text'),
 ('inv_vendedores','id','uuid'),('inv_vendedores','nombre','text'),
 ('inv_vendedores','activo','boolean'),
 ('inv_ventas','id','uuid'),('inv_ventas','client_op_id','uuid'),
 ('inv_ventas','vendedor_id','uuid'),('inv_ventas','modalidad','text'),
 ('inv_ventas','estado','text'),
 ('inv_venta_detalles','venta_id','uuid'),
 ('inv_venta_detalles','item_id','uuid'),
 ('inv_venta_detalles','location_id','smallint'),
 ('inv_venta_detalles','cantidad','integer'),
 ('inv_venta_detalles','precio_unitario','numeric')
)
SELECT r.tabla,r.columna,r.tipo,
       (c.column_name IS NOT NULL AND c.data_type=r.tipo) AS compatible
FROM requisitos r
LEFT JOIN information_schema.columns c
  ON c.table_schema='public'
 AND c.table_name=r.tabla AND c.column_name=r.columna
ORDER BY r.tabla,r.columna;
