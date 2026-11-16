# Bloqueo de Deudas: auditoría previa a integración UI

Inspección del `index.html` actual en rama de integración, 2026-11-16.

## Hallazgos que impiden montar únicamente una pantalla de contraseña
1. `connectCloud()` ejecuta `loadPrivate()` antes de `cloudSnapshot()`; el estado local `cp_v2` queda cargado y renderizado antes de una validación adicional.
2. `load()` lee `cp_v2`, `cp_v2_bak`, `cp_items` y eventualmente `cp_v2_corrupt`; `onRemote()` escribe caché mediante `persist(false)`.
3. `cloudSnapshot()` consulta `public.debts` y `cloudSet()` consulta/escribe `public.debts` directamente. Deben esperar a `debt_access_valid` y estar protegidas además por RLS.
4. `connectCloud()` crea una suscripción Realtime de `public.debts`; debe establecerse únicamente tras desbloqueo y retirarse al bloquear.
5. `hidePrivate()` vacía el estado en memoria, pero no elimina la caché local persistente; no debe confundirse ocultar la UI con cifrar datos en reposo.
6. La aplicación tiene sincronización offline y cola `cp_pend`. El bloqueo no debe borrar silenciosamente cambios pendientes ni subirlos sin una autorización válida.
7. `cl-nexus-shell.js` monta Inventario/Garantías/Contratos tras login. El bloqueo adicional debe restringir SOLO Deudas, no cerrar la sesión global ni impedir acceder a otros módulos.

## Requisitos de integración segura
- Pantalla neutral de selección de módulos tras login global; Deudas requiere desbloqueo RPC por workspace.
- No llamar `loadPrivate()`, `render()`, `cloudSnapshot()`, `cloudSet()` ni iniciar Realtime de Deudas antes del desbloqueo confirmado.
- En cada lectura/escritura de Deudas, RLS servidor valida usuario, workspace, sesión, expiración y revisión; las comprobaciones UI no sustituyen RLS.
- Al bloquear: invalidar operaciones pendientes por generación, cancelar canal, vaciar memoria/DOM de Deudas y mantener Inventario operativo.
- Diseñar migración de `cp_v2` y copias locales: cifrado con clave no persistida o purga segura con respaldo previo y consentimiento. Eliminar sin respaldo arriesga pérdida de cambios offline; mantener en claro deja información expuesta a usuarios del mismo dispositivo.
- Probar carreras entre desbloqueo, logout, actualización de SW, dos dispositivos y escrituras offline.
- NO cambiar `main` ni ejecutar el borrador de políticas en producción hasta completar backup, rollback, sesiones reales y pruebas de caché.

## Estado
Auditoría estática completada. Integración UI **no aplicada** por los riesgos anteriores.
