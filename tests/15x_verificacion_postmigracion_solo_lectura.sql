-- Fase 15X. SOLO LECTURA, para staging DESPUES de migraciones 15I/J/K/N/P/Q.
-- Debe devolver 6 tablas protegidas y 12 funciones autorizadas.
WITH tablas(nombre) AS (
 VALUES ('inv_clientes'),('inv_cliente_referencias'),('inv_contratos'),
 ('inv_contrato_detalles'),('inv_contrato_primas'),('inv_prima_eventos')
)
SELECT 'tabla_rls' AS tipo,t.nombre AS objeto,
       (c.oid IS NOT NULL AND c.relrowsecurity) AS correcto
FROM tablas t LEFT JOIN pg_catalog.pg_class c
 ON c.oid=pg_catalog.to_regclass('public.'||t.nombre)
UNION ALL
SELECT 'tabla_sin_acceso_directo',t.nombre,
       (c.oid IS NOT NULL
        AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'SELECT')
        AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'INSERT')
        AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'UPDATE')
        AND NOT pg_catalog.has_table_privilege('authenticated',c.oid,'DELETE'))
FROM tablas t LEFT JOIN pg_catalog.pg_class c
 ON c.oid=pg_catalog.to_regclass('public.'||t.nombre)
UNION ALL
SELECT 'funcion',p.proname,
       (pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
        AND NOT pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE')
        AND p.prosecdef)
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
AND p.proname IN (
 'inv_buscar_clientes','inv_crear_cliente','inv_crear_contrato_borrador',
 'inv_marcar_prima_recibida','inv_historial_vendedor','inv_resumen_vendedor',
 'inv_catalogo_vendedores','inv_catalogo_articulos_contratos','inv_ficha_cliente',
 'inv_historial_cliente','inv_detalle_contrato','inv_confirmar_contrato'
)
ORDER BY tipo,objeto;
