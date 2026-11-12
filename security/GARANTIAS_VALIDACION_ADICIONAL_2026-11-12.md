# Validación adicional de garantías — 12 de noviembre de 2026

## Alcance
Pruebas SQL realizadas sobre la función aislada `public.cl2_sandbox_warranty_release_safe` del proyecto de Inventario. No se ejecutó `public.inv_liberar_garantia`, no se modificaron existencias comerciales y no se publicó la PWA.

## Caso A: dos solicitudes simultáneas de la misma cuenta
- Cuenta simulada: administrador ficticio autorizado del sandbox.
- Artículo: `c5000000-0000-4000-8000-000000000001`.
- Clave de operación: `c6000000-0000-4000-8000-000000000010`.
- Destino ficticio 2, cantidad 1, observación «Prueba paralela misma cuenta».
- Dos llamadas lanzadas simultáneamente mediante `Promise.allSettled`.
- Primera respuesta: `released`.
- Segunda respuesta: `already_released`.
- Ambas devolvieron `movement_id=f9ecf83a-6498-4b8c-97e7-96c5c27c8d10`.
- Verificación posterior: stock en Garantía 7; destino 2: 1; movimientos con esta clave: 1; claves idempotentes: 1.

## Caso B: misma clave con cantidad cambiada
- Mismo administrador, misma clave, destino 1 y cantidad 2.
- Resultado: excepción «Identificador reutilizado con datos diferentes».
- Operación de prueba envuelta en transacción con rollback.

## Caso C: misma clave usada por otra cuenta autorizada
- Secretaria ficticia, misma clave y datos originales.
- Resultado: excepción «Operación pertenece a otra cuenta».
- Operación de prueba envuelta en transacción con rollback.

## Interpretación
Las comprobaciones respaldan que la función sandbox evita duplicar movimientos por la misma clave y rechaza reintentos incompatibles. Las pruebas de llamadas simultáneas se lanzaron desde el cliente de herramientas; no equivalen a pruebas de navegador, estrés ni auditoría de seguridad integral.

## Pendiente antes de producción
1. Probar `sandbox/garantias-rpc-prueba.html` en un navegador con autenticación real.
2. Revisar expiración de sesión, interrupción de red, recarga de página y recuperación de clave pendiente.
3. Diseñar RPC productivo compatible con triggers de garantía, permisos y auditoría existentes.
4. Validar migración y compatibilidad con versiones PWA antiguas.
5. Obtener aprobación expresa antes de desplegar o modificar datos reales.
