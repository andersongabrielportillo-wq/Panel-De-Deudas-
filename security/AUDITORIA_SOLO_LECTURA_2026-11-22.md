# Auditoría de solo lectura — 2026-11-22

Estado: INCOMPLETA / NO APROBADA. No se realizaron escrituras SQL, pruebas con sesiones JWT, movimientos ni despliegues.

## Estado de proyectos (Supabase list_projects)
- Comercial Lopez Pruebas (dozcnytevqhoymzqlxah): INACTIVE. No se reactivó.
- Panel de Deudas (josdmjjbnrugiwlwgjky): ACTIVE_HEALTHY. Consultas solo lectura.
- CL Nexus Recuperacion Auth Vault TEMPORAL (mwtvmmbmudlswblwcnyj): ACTIVE_HEALTHY. Consultas solo lectura; NO certificado como aislado.

## Conteos de funciones public.inv_% (pg_proc)
- Panel de Deudas: 41 funciones, 40 SECURITY DEFINER, 0 ejecutables por anon, 33 ejecutables por authenticated.
- Proyecto temporal: 37 funciones, 36 SECURITY DEFINER, 0 ejecutables por anon, 29 ejecutables por authenticated.
- El predicado específico de auditoría `proconfig @> ARRAY['search_path=']::text[]` devolvió cero en ambos; NO permite concluir por sí solo que el search_path sea inseguro ni seguro. Requiere inspección de proconfig.

## Huellas MD5 de pg_get_functiondef
| Función | Panel | Temporal |
|---|---|---|
| inv_anular_venta | c3566e118b8116dcf24b31a1ac2b679a | igual |
| inv_crear_vendedor | 0361f8379dda51425e74da83bdfc3242 | igual |
| inv_liberar_garantia | 2605a6d55f0563f4e59f67e59916996c | igual |
| inv_catalogo_articulos_admin | e85bfc157154628fe4ce9da3e8d0f5d0 | no hallada |
| inv_corregir_nombre_articulo | 368533e3fa4156d66a51de2fb5d90f8b | no hallada |

Las cinco funciones en Panel tienen SECURITY DEFINER y EXECUTE para authenticated. inv_liberar_garantia recibe (p_item_id uuid, p_destino smallint, p_cantidad integer, p_observaciones text); la firma no recibe clave de idempotencia. Esto no demuestra por sí solo ausencia de protección interna.

## Consulta reproducible (solo lectura)
```sql
SELECT count(*) total,
 count(*) FILTER (WHERE p.prosecdef) definer,
 count(*) FILTER (WHERE has_function_privilege('anon',p.oid,'EXECUTE')) anon_exec,
 count(*) FILTER (WHERE has_function_privilege('authenticated',p.oid,'EXECUTE')) auth_exec
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname LIKE 'inv_%';
```

## Bloqueos
- Falta verificar permisos efectivos de Administrador y Secretaria con JWT auténticos en entorno autorizado, sin tocar registros reales.
- Falta certificar un proyecto completamente aislado, activo, con datos exclusivamente ficticios y sin dependencias comerciales.
- Faltan pruebas exhaustivas de entradas, salidas, traslados, devoluciones, ventas, anulaciones, garantías, reparaciones, idempotencia y concurrencia.
- No se reactivaron proyectos ni se contrataron recursos; no se publicaron cambios en producción.
