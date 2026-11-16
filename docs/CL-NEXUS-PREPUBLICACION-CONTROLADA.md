# Prepublicación controlada CL Nexus — 2026-11-16

## Autorización y alcance
El propietario autorizó preparar cambios para producción, conservando respaldo y **sin activar operaciones no validadas**. Esta autorización no equivale a aprobar la fusión del PR borrador ni a ejecutar migraciones inseguras.

## Respaldo disponible
Rama inmutable de referencia creada desde `main`: `respaldo-pre-cl-nexus-2026-11-16`. Respalda **código del repositorio**, NO la base de datos Supabase, Auth, Storage ni secretos. Antes de migraciones de producción se requiere respaldo restaurable de base de datos y procedimiento de reversión probado.

## Verificaciones de corte
- [x] Rama de respaldo del código desde `main`.
- [x] Cambios de integración aislados en `integracion-inventario-fase15`; PR #2 permanece borrador.
- [x] CI de shell/adapter aprobado en commit `6daf95e2`.
- [x] RPC anónimas de inventario/sandbox: ninguna de las 40 funciones SECURITY DEFINER inspeccionadas ejecutable por rol anon en LAB.
- [ ] Autenticación compartida segura: JWT de producción no se debe asumir válido para Supabase LAB; no reutilizar ni copiar contraseñas.
- [ ] Pruebas autenticadas de admin y secretaria, rechazo de terceros, permisos y auditoría.
- [ ] Pruebas de concurrencia con stock ficticio y verificación antes/después.
- [ ] Contraseña adicional de Deudas verificada en servidor y aplicada a SELECT/INSERT/UPDATE/DELETE, con Realtime probado.
- [ ] Respaldo restaurable de base de datos de producción y plan de rollback.
- [ ] Confirmar canal real de despliegue, caché del service worker y comportamiento de actualización en 2 dispositivos.

## Decisión
**NO GO para fusionar o desplegar** hasta completar controles anteriores. Es seguro preparar el paquete de publicación y mantener el código en rama aislada. El shell existente falla cerrado en producción: las RPC CL Nexus no se habilitan si el origen no es LAB. No se debe presentar como inventario operativo en producción.
