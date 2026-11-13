# Plan de pruebas antes de activar bloqueo de Deudas

Estado: PREPARACION; no publicar ni activar RLS en producción todavía.

## Riesgos encontrados en el código actual
- `startAuth()` y `connectCloud()` descargan el snapshot `debts.__shared_state__` inmediatamente tras iniciar sesión.
- `loadPrivate()` carga `cp_v2` desde almacenamiento local; ocultar un panel no impide leerlo.
- La sincronización realtime escucha cambios de `public.debts`.
- Políticas permisivas existentes en `debts` y `transactions` autorizan a miembros sin segundo factor.
- El borrador SQL de acceso necesita validación de sesión real, pruebas de limitación de intentos y revisión de privilegios antes de instalarse.

## Pruebas obligatorias
1. Sin iniciar sesión: ni RPC ni tablas exponen datos.
2. Con sesión válida pero bloqueada: SELECT/INSERT/UPDATE/DELETE denegados en ambas tablas; realtime sin payload.
3. Contraseña incorrecta: no desbloquea; 5 intentos generan bloqueo temporal.
4. Contraseña correcta: habilita únicamente sesión actual por 15 minutos.
5. Otro usuario o sesión no hereda desbloqueo.
6. Cerrar sesión o pulsar Bloquear: revoca permiso y elimina datos visibles y copias locales sensibles.
7. Caducidad: se niegan lecturas y escrituras al vencer la ventana.
8. Modo offline y recarga: no muestran datos en caché sin nuevo desbloqueo.
9. Sincronización entre dispositivos y operaciones existentes permanecen correctas.
10. Despliegue coordinado de frontend + políticas RLS, con plan de reversión y copia de seguridad verificada.

## Orden de implementación
1. Crear acceso y pruebas en proyecto aislado con datos sintéticos.
2. Adaptar pantalla principal y conexión para no cargar deudas antes de desbloquear.
3. Reemplazar políticas RLS permisivas existentes (no añadir una política OR).
4. Auditar vistas, funciones, realtime, almacenamiento local y permisos.
5. Validar con cuentas de prueba y recién entonces aprobar despliegue de producción.


## Auditoría estática de preparación (2026-11-12)
- [x] Nombre visible en `<title>`, metadatos móviles y manifiesto: Comercial López 2.
- [x] Cache del service worker versionada para que la actualización recupere el manifiesto.
- [x] Sintaxis de los 3 bloques JavaScript embebidos: verificada por compilación estática.
- [x] El frontend exige desbloqueo antes de descargar el snapshot de deudas y comprueba el estado durante conexión y sincronización.
- [x] El inventario consulta membresía del usuario antes de descargar tablas operativas.
- [x] Consultadas políticas de producción: siguen existiendo las ocho políticas originales de `debts` y `transactions`; **NO** se ha activado RLS con desbloqueo adicional.
- [ ] Pruebas E2E de autenticación, tres usuarios, realtime, entradas, salidas, reparaciones y modo sin conexión.
- [ ] Revisar datos sensibles en `localStorage` (`cp_v2`, `cp_v2_bak`, `cp_prev`) y diseñar migración segura sin perder cambios offline. **Bloquear la interfaz no cifra esos datos**.
- [ ] Revisar seguridad de eventos realtime, vistas y RPC; verificar bloqueo de lecturas directas con sesión autenticada pero sin segundo factor.
- [ ] Copia de seguridad verificada y plan de reversión de frontend + políticas SQL.
- [ ] Despliegue coordinado: no fusionar la rama ni aplicar el SQL de RLS antes de aprobar estas verificaciones.

**Estado:** desarrollo preparado parcialmente, NO APTO para publicación definitiva todavía. Ninguna prueba funcional real se debe marcar aprobada sin evidencia.
