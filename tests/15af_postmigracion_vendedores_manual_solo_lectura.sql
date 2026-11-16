-- 15AF: certificación del catálogo manual en PostgreSQL AISLADO.
-- SOLO LECTURA. Ejecutar después de aplicar 15AE con datos ficticios,
-- ANTES de crear vendedores ficticios. Nunca en bases pobladas actuales.
SELECT 'tabla_manual_instalada' AS control,
       to_regclass('public.inv_vendedores_manual') IS NOT NULL AS ok
UNION ALL SELECT 'rpc_catalogo_manual_instalada',
       to_regprocedure('public.inv_catalogo_vendedores_manual()') IS NOT NULL
UNION ALL SELECT 'rpc_alta_manual_instalada',
       to_regprocedure('public.inv_crear_vendedor_manual(text)') IS NOT NULL
UNION ALL SELECT 'rls_manual_activo',
       EXISTS(SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n
              ON n.oid=c.relnamespace WHERE n.nspname='public'
              AND c.relname='inv_vendedores_manual' AND c.relrowsecurity)
UNION ALL SELECT 'sin_lectura_directa_authenticated',
       NOT COALESCE(has_table_privilege('authenticated',
           to_regclass('public.inv_vendedores_manual'),'SELECT'),false)
UNION ALL SELECT 'sin_lectura_directa_anon',
       NOT COALESCE(has_table_privilege('anon',
           to_regclass('public.inv_vendedores_manual'),'SELECT'),false)
UNION ALL SELECT 'sin_ejecucion_anon_catalogo',
       NOT COALESCE(has_function_privilege('anon',
           to_regprocedure('public.inv_catalogo_vendedores_manual()'),'EXECUTE'),false)
UNION ALL SELECT 'sin_ejecucion_anon_alta',
       NOT COALESCE(has_function_privilege('anon',
           to_regprocedure('public.inv_crear_vendedor_manual(text)'),'EXECUTE'),false);
-- Verificar catálogo inicialmente vacío por RPC con JWT real de admin:
-- SELECT * FROM public.inv_catalogo_vendedores_manual();
-- No usar una consulta de servicio privilegiado para sustituir prueba JWT.
