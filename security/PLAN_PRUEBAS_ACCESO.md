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
