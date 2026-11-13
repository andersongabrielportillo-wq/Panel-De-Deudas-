# Revisión de compatibilidad: garantías e idempotencia

Fecha: 2026-11-12. Estado: análisis de solo lectura, sin cambios en producción.

## Esquema observado en Supabase
`public.inv_movements`: `id bigint`, `client_op_id uuid`, `item_id uuid`, `tipo text`, `origen smallint`, `destino smallint`, `cantidad integer`, `fecha date`, `vendedor text`, `observaciones text`, `usuario uuid`, `creado_en timestamptz`.

`inv_private.garantia_autorizaciones`: `id uuid`, `item_id uuid`, `cantidad integer`, `destino smallint`, `usuario uuid`, `creado_en timestamptz`, `transaccion_id bigint`, `backend_pid integer`, `operacion_id uuid`.

## Riesgo identificado
La función de sandbox retorna un `movement_id uuid` porque su tabla ficticia usa UUID. El movimiento comercial usa `id bigint`. **No copiar la implementación ficticia directamente a producción** ni cambiar el tipo del ID comercial. El UUID de solicitud del cliente debe asociarse de forma única al movimiento numérico existente.

La función productiva `public.inv_liberar_garantia` genera un UUID internamente en cada llamada; para reintentos idempotentes hace falta un contrato nuevo o un envoltorio seguro que acepte el identificador del cliente y respete los triggers y el contexto transaccional de garantía.

## Requisitos antes de una migración
1. Revisar definiciones actuales de `inv_liberar_garantia`, triggers y restricciones únicas de `inv_movements.client_op_id`.
2. Verificar permisos `EXECUTE` y políticas de autorización admin/secretaria.
3. Preservar la relación entre `inv_private.garantia_autorizaciones.operacion_id`, `inv_movements.client_op_id` y `inv_movements.id bigint`.
4. Rechazar una clave reutilizada por otro actor o con contenido distinto.
5. Bloquear filas de stock, garantizar atomicidad y no alterar movimientos inmutables.
6. Mantener compatibilidad con clientes PWA que aún llaman al RPC antiguo.
7. Probar errores, llamadas concurrentes, reintentos, recarga y cambio de sesión en navegador.
8. Obtener aprobación expresa antes de aplicar migraciones o desplegar.

## Límite
Este documento no es una migración ejecutable ni confirma seguridad de producción. No se modificaron existencias ni funciones comerciales.
