# Fase 15D — Auditoría de funciones y permisos (solo lectura)

Fecha: 2026-11-15. Proyecto revisado: Comercial Lopez Pruebas (`dozcnytevqhoymzqlxah`). **Sin cambios en bases de datos ni en main.**

## Verificaciones realizadas
- 14 tablas públicas `inv_*` con RLS activado.
- El rol `authenticated` tiene SELECT en 13 de esas tablas, sin INSERT, UPDATE ni DELETE directos; `inv_venta_anulacion_movimientos` tampoco expone SELECT.
- Las 3 tablas del esquema `inv_private` tienen RLS y no conceden SELECT/INSERT/UPDATE/DELETE a `authenticated`.
- Las funciones públicas de negocio que sí permiten EXECUTE a `authenticated` usan `SECURITY DEFINER`; las funciones de trigger y utilitarias consultadas no conceden EXECUTE directo a `authenticated` ni `anon`.
- Se identificaron 10 combinaciones trigger/evento en `inv_movements` e `inv_stock` (inmutabilidad, rutas y protecciones de stock).
- No se identificaron funciones públicas de inventario ejecutables por `anon` en la consulta.

## Inspección del código de 4 funciones críticas
### inv_registrar_movimiento
- Verifica `auth.uid()` contra `inv_members` con rol admin o secretaria.
- Solo permite salida y traslado; valida cantidad, origen/destino, artículo activo, ubicación, stock y `client_op_id`.
- Bloquea fila de artículo y stock con `FOR UPDATE`.
- Impide usar ubicación 4 como origen/destino en ruta general.
- **Revisión pendiente:** evaluar política de uso de ubicación 3 (Garantía) en movimientos generales; confirmar que los triggers impidan cualquier salida no autorizada. Validar observaciones obligatorias conforme a reglas de negocio: la función actualmente admite `p_observaciones` NULL y no hace comprobación explícita de contenido no vacío.

### inv_liberar_garantia
- Requiere rol admin o secretaria, destino 1 o 2, cantidad positiva, observaciones no vacías, artículo activo y existencias en ubicación 3.
- Emite autorización interna con identificador de operación y comprueba movimiento resultante.
- Requiere inspección adicional del trigger y su consumo de autorización antes de habilitar operaciones en producción.

### inv_revisar_entrada
- Requiere rol admin o secretaria, solicitud pendiente, artículo activo.
- Aprobación incrementa stock y registra movimiento; rechazo no incrementa stock.
- Requiere pruebas de concurrencia e idempotencia en ambiente aislado.

### inv_revisar_devolucion
- Requiere rol admin o secretaria, solicitud pendiente y destino Garantía (ubicación 3).
- Aprobación incrementa stock en Garantía y registra movimiento; rechazo no incrementa stock.
- Bloquea la solicitud y artículo para revisión.

## Pendientes obligatorios
1. Inspeccionar definición completa de triggers de stock y movimientos y su interacción con las funciones SECURITY DEFINER.
2. Auditar `inv_registrar_venta`, `inv_anular_venta`, `inv_crear_reparacion`, `inv_enviar_reparacion`, `inv_resolver_reparacion` y recepciones.
3. Confirmar modelo de ubicación 3/4 y compatibilidad con reglas de garantías.
4. Revisar integridad del laboratorio: inv_items e inv_locations se reportan con 0 filas mientras hay stock y movimientos; verificar si las estadísticas son estimaciones, si hay datos inconsistentes o si existen otras causas, sin modificar nada.
5. Validar identidad de usuarios entre ambos proyectos Supabase antes de unificar.
6. Diseñar y probar control de segunda contraseña para Deudas con autorización servidor, revocación y RLS.
7. No habilitar escrituras reales ni migrar hasta completar revisión y pruebas.

**Conclusión:** base prometedora con protecciones verificables; no certificada aún como segura para producción.
