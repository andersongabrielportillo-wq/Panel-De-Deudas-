# Auditoría de solo lectura — 2026-11-15

## Límites
Consultas SELECT de catálogo en proyecto Supabase `dozcnytevqhoymzqlxah`; ninguna operación DML/DDL ni RPC modificadora, ningún despliegue, ninguna infraestructura nueva. Esta evidencia no representa pruebas JWT efectivas ni un entorno independiente.

## Entorno
`list_branches` devolvió `{"branches":[]}`. No existe una rama de base de datos independiente disponible mediante este conector. El sandbox dentro del mismo proyecto no cumple el requisito de aislamiento real.

## Inventario de privilegios
Consulta sobre `pg_proc` y `has_function_privilege` para funciones `public.inv_%` y `public.cl2_%`: 30 funciones encontradas (23 inv_ y 7 cl2_). Las 22 funciones operativas (15 inv_ y 7 cl2_) permiten EXECUTE a `authenticated` y no a `anon`. Ocho funciones internas no permiten EXECUTE a ninguno de los dos roles. 29 de 30 están marcadas SECURITY DEFINER; `inv_hash_solicitud_venta` no lo está. Las 30 tienen `search_path=""` configurado. IMPORTANTE: los privilegios SQL del rol `authenticated` no prueban la autorización de Administrador ni Secretaria dentro del cuerpo de las funciones.

## Huellas y comprobaciones de código
| Función | MD5 de definición | auth.uid() | genera UUID | clave cliente |
|---|---|---|---|---|
| inv_anular_venta | c3566e118b8116dcf24b31a1ac2b679a | sí | sí | no |
| inv_crear_vendedor | 0361f8379dda51425e74da83bdfc3242 | sí | no | no |
| inv_liberar_garantia | 2605a6d55f0563f4e59f67e59916996c | sí | sí | no |
| inv_registrar_movimiento | f0233c01f056f0c8f90cdcd24b65d730 | sí | sí | sí |
| inv_registrar_venta | 08b0b5cf946f2dcdb5c1d19d64348cc8 | sí | sí | sí |
| inv_revisar_devolucion | 304550c623fb4b3328b401d462428330 | sí | no | no |
| inv_revisar_entrada | 9b448c7c93104106d6d7e3c6d7fc15bc | sí | no | no |

Las huellas identifican la versión observada, no prueban seguridad. `inv_liberar_garantia` sigue sin parámetro de idempotencia aportado por el cliente: riesgo de reintento duplicado pendiente de resolver en una futura migración aprobada.

## No completado
- Pruebas efectivas con JWT reales de Administrador y Secretaria.
- Matriz exhaustiva de entradas, salidas, traslados, ajustes, devoluciones, ventas, anulaciones, reparaciones y garantías.
- Ensayos de concurrencia, pérdida de respuesta, recuperación, autorización y rollback en instancia realmente aislada.
- Verificación de coste cero de una instancia independiente.

## Decisión
NO APROBADO / INCOMPLETO. No modificar producción ni usar datos reales para cerrar la matriz. No publicar.
