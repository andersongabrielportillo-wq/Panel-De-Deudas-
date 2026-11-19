-- FASE 15AD — auditoría solo lectura de separación inventario/vendedores.
-- No expone nombres, teléfonos, DUI ni registros individuales.
-- Esta auditoría NO borra vendedores existentes ni valida que el catálogo nuevo esté vacío.
WITH comprobaciones AS (
 SELECT 'tabla_articulos' AS control,
   to_regclass('public.inv_items') IS NOT NULL AS ok
 UNION ALL SELECT 'tabla_vendedores',to_regclass('public.inv_vendedores') IS NOT NULL
 UNION ALL SELECT 'tablas_distintas',
   to_regclass('public.inv_items') IS NOT NULL
   AND to_regclass('public.inv_vendedores') IS NOT NULL
   AND to_regclass('public.inv_items')<>to_regclass('public.inv_vendedores')
 UNION ALL SELECT 'rpc_ventas_existente',
   to_regprocedure('public.inv_registrar_venta(uuid,text,jsonb,numeric,text,uuid)') IS NOT NULL
)
SELECT control,ok FROM comprobaciones ORDER BY control;

-- Las RPC nuevas no están instaladas hasta aplicar las migraciones 15N y 15AE.
-- No deben contar como fallos de dependencias existentes en un preflight.
SELECT 'rpc_catalogo_vendedores_15n' AS control,
       CASE WHEN to_regprocedure('public.inv_catalogo_vendedores()') IS NULL
            THEN 'pendiente_migracion' ELSE 'instalada' END AS estado
UNION ALL
SELECT 'rpc_catalogo_vendedores_manual_15ae',
       CASE WHEN to_regprocedure('public.inv_catalogo_vendedores_manual()') IS NULL
            THEN 'pendiente_migracion' ELSE 'instalada' END;

-- IMPORTANTE: la presencia de inv_vendedores NO autoriza precargar el módulo
-- Vendedores desde el archivo de inventario. La nueva lista debe empezar vacía.
