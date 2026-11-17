# Garantías: integración idempotente — borrador NO desplegado

Estado: propuesta para revisión. No aplicar sobre producción sin autorización.

## Hallazgo del frontend
En `index.html`, el envío de `inventoryReleaseForm` llama a `inventoryRepairAction("inv_liberar_garantia", ...)`. Ese RPC recibe solo artículo, destino, cantidad y observaciones; la operación genera un UUID nuevo en el servidor en cada llamada. Reintentar después de una respuesta perdida puede liberar dos veces si existe stock suficiente.

## Contrato propuesto (no instalado)
Crear un RPC nuevo, por ejemplo `inv_liberar_garantia_idempotente(p_item_id uuid,p_destino smallint,p_cantidad integer,p_observaciones text,p_client_op_id uuid)`. Conservar `inv_liberar_garantia` sin reemplazar hasta migrar clientes.

- Autenticación: `auth.uid()` y rol explícito admin/secretaria, incluyendo rechazo de rol NULL.
- Validar UUID, destino 1/2, cantidad positiva, observaciones no vacías y artículo activo.
- Bloquear la clave de operación con `pg_advisory_xact_lock` y consultar el movimiento previo por `client_op_id` antes de descontar stock.
- Ante repetición, comparar artículo, origen=3, destino, cantidad y observaciones normalizadas; devolver el ID previo solo si coinciden. **No confiar únicamente en `inv_movements` para comprobar el texto** si el prefijo se altera.
- Conservar autorización `inv_private.garantia_autorizaciones`, su `operacion_id` y `set_config('inv_private.operacion_garantia',...)` para no romper los triggers existentes.
- Bloquear artículo y stock de garantía con `FOR UPDATE`, mantener la transacción atómica, las restricciones y el control de stock.
- Asegurar que la clave idempotente queda registrada con `UNIQUE` y los parámetros canónicos; evitar que una segunda cuenta se apropie de una clave de otra.
- Retornar el mismo `bigint` de movimiento que el RPC actual, o adaptar la UI de manera explícita.

## Cambios propuestos en interfaz (no instalados)
- Crear `crypto.randomUUID()` una sola vez por intento de usuario, antes de invocar RPC.
- Deshabilitar el botón de liberación mientras la solicitud esté en curso.
- Mantener `p_client_op_id` y los valores originales ante un error de red o respuesta ambigua; nunca generar otra clave automáticamente para ese reintento.
- Confirmar resultado consultando por la clave, y limpiar el intento pendiente únicamente tras confirmación.
- Si se cierra la página, almacenar temporalmente la operación pendiente de forma segura y por usuario, sin almacenar contraseñas. Evaluar el riesgo de usar localStorage y preferir un mecanismo de recuperación autenticado.
- Evitar enviar al RPC antiguo desde clientes actualizados; planear compatibilidad de clientes antiguos antes de activar cambios.

## Pruebas requeridas
1. Doble clic y dos llamadas simultáneas: un movimiento y un descuento.
2. Respuesta perdida y reintento desde otro dispositivo: mismo ID.
3. Misma clave con diferente destino, cantidad, artículo u observación: rechazo.
4. Usuario sin membresía: rechazo incluso con clave existente.
5. Stock insuficiente, artículo inactivo y destino inválido: rechazo sin cambios.
6. Pruebas de triggers de Garantía/Proveedor, reparaciones, permisos y auditoría.
7. Migración controlada, rollback y comprobación de versión PWA/service worker.

## Evidencia sandbox
En `cl2_sandbox`, `cl2_sandbox_warranty_release_safe` registró 1 movimiento y 2 unidades ante dos solicitudes simultáneas de admin/secretaria con la misma clave. Se verificaron rechazo de datos distintos, usuario sin rol, destino inválido y stock insuficiente. Es un **modelo aislado**, no una prueba del RPC productivo.

## Estado
Este documento es una especificación, no la implementación. No se han cambiado funciones productivas ni el formulario principal.
