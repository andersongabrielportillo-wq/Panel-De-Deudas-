-- SOLO LECTURA. Inventario de roles y privilegios de funciones existentes.
-- No devuelve usuarios, correos, nombres ni identificadores personales.
-- Si empleado=0, las pruebas de JWT empleado deben usar un fixture AISLADO.
WITH roles(rol) AS (VALUES ('admin'),('secretaria'),('empleado')),
conteos AS (
 SELECT rol,count(*)::integer AS cantidad FROM public.inv_members GROUP BY rol
), funciones AS (
 SELECT p.proname,p.oid,p.prosecdef
 FROM pg_catalog.pg_proc p
 JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public'
 AND p.proname IN ('inv_registrar_venta','inv_anular_venta','inv_registrar_movimiento')
)
SELECT 'rol' AS tipo,r.rol AS nombre,
       COALESCE(c.cantidad,0)::text AS resultado
FROM roles r LEFT JOIN conteos c ON c.rol=r.rol
UNION ALL
SELECT 'rpc',f.proname,
       'authenticated='||pg_catalog.has_function_privilege('authenticated',f.oid,'EXECUTE')::text
       ||',anon='||pg_catalog.has_function_privilege('anon',f.oid,'EXECUTE')::text
       ||',definer='||f.prosecdef::text
FROM funciones f
ORDER BY tipo,nombre;
