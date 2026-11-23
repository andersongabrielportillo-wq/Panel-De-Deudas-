# Auditoría de solo lectura — 2026-11-23

**Estado: INCOMPLETA / NO APROBADA.** Evidencia recogida mediante conectores Supabase y GitHub. Ninguna operación SQL de escritura ni despliegue.

## Proyectos (list_projects)
- Comercial Lopez Pruebas `dozcnytevqhoymzqlxah`: INACTIVE; no reactivado.
- Panel de Deudas `josdmjjbnrugiwlwgjky`: ACTIVE_HEALTHY; solo consultas de lectura.
- CL Nexus Recuperacion Auth Vault TEMPORAL `mwtvmmbmudlswblwcnyj`: ACTIVE_HEALTHY; no certificado como aislado ni como exclusivamente ficticio.

## Auditoría de funciones public.inv_%
| Proyecto | Total | SECURITY DEFINER | EXECUTE anon | EXECUTE authenticated | Sin search_path explícito |
|---|---:|---:|---:|---:|---:|
| Panel de Deudas | 41 | 40 | 0 | 33 | 0 |
| Temporal | 37 | 36 | 0 | 29 | 0 |

Estos permisos SQL de roles globales NO prueban autorizaciones efectivas individuales de Administrador y Secretaria.

## Huellas MD5 de definiciones críticas
| Función | Panel de Deudas | Temporal |
|---|---|---|
| inv_anular_venta | c3566e118b8116dcf24b31a1ac2b679a | igual |
| inv_crear_vendedor | 0361f8379dda51425e74da83bdfc3242 | igual |
| inv_liberar_garantia | 2605a6d55f0563f4e59f67e59916996c | igual |
| inv_catalogo_articulos_admin | e85bfc157154628fe4ce9da3e8d0f5d0 | ausente |
| inv_corregir_nombre_articulo | 368533e3fa4156d66a51de2fb5d90f8b | ausente |

Las cinco funciones son SECURITY DEFINER y sus definiciones mencionan auth.uid(). La firma de inv_liberar_garantia acepta p_item_id, p_destino, p_cantidad, p_observaciones; no acepta clave de idempotencia externa. Su cuerpo menciona client_op_id, lo cual por sí solo no garantiza deduplicación de reintentos.

## SQL reproducible (lectura)
```sql
SELECT count(*) AS total,
 count(*) FILTER (WHERE p.prosecdef) AS security_definer,
 count(*) FILTER (WHERE has_function_privilege('anon',p.oid,'EXECUTE')) AS anon_execute,
 count(*) FILTER (WHERE has_function_privilege('authenticated',p.oid,'EXECUTE')) AS authenticated_execute,
 count(*) FILTER (WHERE p.proconfig IS NULL OR NOT EXISTS (SELECT 1 FROM unnest(p.proconfig) x WHERE x LIKE 'search_path=%')) AS without_explicit_search_path
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname LIKE 'inv\_%' ESCAPE '\';
```

## Pendientes / bloqueos
1. JWT auténticos de Administrador y Secretaria para pruebas efectivas; no obtenidos ni simulados.
2. Certificar entorno independiente, sin usuarios, datos ni dependencias comerciales reales. Proyecto de pruebas inactivo.
3. Ejecutar movimientos ficticios, permisos negativos, reversión, concurrencia, idempotencia y comparar saldos. **No ejecutados**.
4. Verificar idempotencia real de inv_liberar_garantia y corregir solo en rama de desarrollo después de pruebas aisladas.

No se alteraron registros reales, no se activaron proyectos, no se publicó producción ni se contrataron recursos.
