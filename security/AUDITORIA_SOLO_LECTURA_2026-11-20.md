# Auditoría de solo lectura — 2026-11-20

**Estado: INCOMPLETA / NO APROBADA.** No se realizaron mutaciones, despliegues ni contrataciones.

## Proyectos observados
- Comercial Lopez Pruebas (dozcnytevqhoymzqlxah): INACTIVE. No reactivado.
- Panel de Deudas (josdmjjbnrugiwlwgjky): ACTIVE_HEALTHY.
- CL Nexus Recuperacion Auth Vault TEMPORAL (mwtvmmbmudlswblwcnyj): ACTIVE_HEALTHY. No certificado como sandbox exclusivo.

## Consultas SQL de solo lectura ejecutadas en los dos proyectos activos
```sql
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer, p.proconfig, pg_get_userbyid(p.proowner) AS owner, has_function_privilege('anon',p.oid,'EXECUTE') AS anon_exec, has_function_privilege('authenticated',p.oid,'EXECUTE') AS auth_exec, md5(pg_get_functiondef(p.oid)) AS definition_md5 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND (p.proname LIKE 'inv_%' OR p.proname LIKE 'cl2_%') ORDER BY p.proname, args;
SELECT count(*) total, count(*) FILTER (WHERE p.prosecdef) definer, count(*) FILTER (WHERE has_function_privilege('anon',p.oid,'EXECUTE')) anon, count(*) FILTER (WHERE has_function_privilege('authenticated',p.oid,'EXECUTE')) authenticated FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname LIKE 'inv_%';
```

## Resultados
- Panel de Deudas: 39 funciones inv_ (38 SECURITY DEFINER), 0 ejecutables por anon, 31 por authenticated.
- Temporal: 37 funciones inv_ (36 SECURITY DEFINER), 0 ejecutables por anon, 29 por authenticated.
- Las funciones inv_ compartidas por ambos proyectos presentan los mismos hashes MD5 de definición en la consulta de hoy. Dos funciones presentes solo en Panel de Deudas: inv_catalogo_articulos_admin e inv_corregir_nombre_articulo.
- En ambas instancias, las funciones inv_ observadas pertenecen a postgres y tienen proconfig search_path vacío.
- Firma de inv_liberar_garantia: (p_item_id uuid, p_destino smallint, p_cantidad integer, p_observaciones text); no incluye p_client_op_id. Sigue pendiente corregir/verificar idempotencia.
- Estas verificaciones son de privilegios SQL por rol, NO de autorización efectiva mediante JWT de Administrador y Secretaria.

## Bloqueos y próximos pasos
1. Certificar aislamiento real y datos exclusivamente ficticios antes de toda escritura de prueba; el proyecto de pruebas está inactivo y no se reactivó.
2. Ejecutar con sesiones JWT reales de Administrador, Secretaria y rol no autorizado, sin tocar producción.
3. Completar matriz de entrada, salida, traslado, devolución, garantía, reparación, venta, anulación, stock insuficiente, duplicados, reintentos y concurrencia sobre entorno aislado.
4. Comparar funciones privilegiadas con la política de permisos esperada, especialmente anular ventas y crear vendedores.

**No hay evidencia para declarar pruebas exhaustivas superadas.**
