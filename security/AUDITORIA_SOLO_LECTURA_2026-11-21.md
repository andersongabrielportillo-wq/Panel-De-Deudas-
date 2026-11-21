# Auditoría de solo lectura — 2026-11-21

Estado: INCOMPLETA / NO APROBADA. Sin cambios en producción ni datos reales.

## Proyectos
- Comercial Lopez Pruebas (dozcnytevqhoymzqlxah): INACTIVE. No reactivado.
- Panel de Deudas (josdmjjbnrugiwlwgjky): ACTIVE_HEALTHY; únicamente metadatos consultados.
- CL Nexus Recuperacion Auth Vault TEMPORAL (mwtvmmbmudlswblwcnyj): ACTIVE_HEALTHY; únicamente metadatos consultados; NO certificado para movimientos.

## Consulta SQL ejecutada en ambos proyectos activos
```sql
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef, p.proconfig, has_function_privilege('anon',p.oid,'EXECUTE') anon_exec, has_function_privilege('authenticated',p.oid,'EXECUTE') auth_exec, md5(pg_get_functiondef(p.oid)) hash FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND (p.proname LIKE 'inv_%' OR p.proname LIKE 'sandbox_%') ORDER BY p.proname;
```

## Resultados
Panel de Deudas: 41 funciones inv_ enumeradas; 40 SECURITY DEFINER; 0 ejecutables por anon; 33 ejecutables por authenticated; search_path vacío en todas. Temporal: 39 funciones inv_; 38 SECURITY DEFINER; 0 ejecutables por anon; 31 ejecutables por authenticated; search_path vacío en todas. Las funciones compartidas consultadas presentan hashes coincidentes. Panel incluye inv_ajustar_existencia, inv_catalogo_articulos_admin, inv_corregir_nombre_articulo e inv_solicitudes_entrada_pendientes, ausentes en el temporal. Verificar recuentos contra salida SQL si se usa como dato de cumplimiento.

Huellas críticas coincidentes: inv_liberar_garantia 2605a6d55f0563f4e59f67e59916996c; inv_registrar_movimiento f0233c01f056f0c8f90cdcd24b65d730; inv_registrar_venta 08b0b5cf946f2dcdb5c1d19d64348cc8; inv_anular_venta c3566e118b8116dcf24b31a1ac2b679a; inv_revisar_entrada 9b448c7c93104106d6d7e3c6d7fc15bc.

La firma inv_liberar_garantia(p_item_id,p_destino,p_cantidad,p_observaciones) no acepta p_client_op_id; riesgo de reintento pendiente de prueba/corrección. Los permisos SQL para authenticated no prueban autorización por usuario JWT.

## Bloqueos
No hay certificación de entorno de datos ficticios sin dependencias comerciales; proyecto independiente de pruebas INACTIVE. No se probaron JWT reales de Administrador/Secretaria ni movimientos, idempotencia o concurrencia. Ninguna prueba modificadora ejecutada. No se crearon recursos ni costos; no se publicaron cambios.
