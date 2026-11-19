# Fase 15F — Auditoría de ventas, anulaciones y recepciones

Fecha: 2026-11-15. Proyecto de laboratorio: Comercial Lopez Pruebas (`dozcnytevqhoymzqlxah`). Inspección SQL **solo lectura**.

## Funciones revisadas

### inv_registrar_venta
- Exige rol admin o secretaria y `p_client_op_id` no nulo.
- Usa bloqueo transaccional advisory por identificador y verifica huella de solicitud mediante `inv_private.verificar_reintento_venta`.
- Verifica vendedor activo, modalidad contado/crédito, 1–100 líneas, cantidad positiva, ubicación 1/2, importes y descuentos.
- Crea cabecera y detalles y descuenta stock usando `inv_registrar_movimiento`.
- **Hallazgo:** `p_observaciones` se almacena sin validar contenido no vacío; la regla de observaciones obligatorias debe definirse/aplicarse.

### inv_anular_venta
- Exige rol admin o secretaria y motivo no vacío.
- Bloquea cabecera de venta y detalles con `FOR UPDATE`.
- Rechaza venta no registrada, con devoluciones asociadas o compensaciones previas.
- Valida movimientos originales; restaura existencias, registra movimientos de entrada compensatorios y marca venta anulada.
- Pendiente: pruebas de concurrencia e integridad de movimientos.

### inv_crear_recepcion
- Exige rol admin o secretaria; valida proveedor, referencia, fecha, array de 1–100 detalles, artículos activos, cantidad positiva y destino 1/2.
- Crea recepción pendiente sin sumar stock.
- **Hallazgo:** observaciones opcionales; comprobar regla de negocio y exigirlas si corresponde.

### inv_revisar_recepcion
- Exige rol admin o secretaria, recepción pendiente y decisión explícita.
- Bloquea cabecera con `FOR UPDATE`; al aprobar incrementa stock y registra movimientos; al rechazar no suma stock.
- Pendiente: pruebas simultáneas, reintentos, permisos negativos y revisión de orden de bloqueos.

## Próximas acciones antes de producción
1. Auditar las funciones privadas de reintentos de ventas y consumo de autorizaciones de reparación.
2. Preparar parches SQL versionados **para un entorno aislado**, no aplicarlos a producción.
3. Probar ventas repetidas con el mismo `client_op_id` y payload distinto.
4. Probar anulaciones simultáneas y anulaciones con devoluciones.
5. Probar recepción aprobada/rechazada concurrentemente y observar stock final.
6. Revisar consistencia de observaciones obligatorias en todas las operaciones.
7. Diseñar migración de identidad/roles entre los dos proyectos Supabase.
8. Mantener sin cambios main, producción y datos del laboratorio hasta autorización de una prueba controlada.

Resultado: funciones sustanciales reutilizables; **no certificadas para producción**.
