# Evidencia de pruebas SQL aisladas de acceso a Deudas

Fecha: 2026-11-16. Proyecto: Supabase LAB `dozcnytevqhoymzqlxah`.

Se realizaron pruebas mediante transacciones SQL con `SET LOCAL ROLE authenticated` y JWT simulado en `request.jwt.claims`. Cada transacción terminó en `ROLLBACK`. Esto NO es una prueba con sesiones reales emitidas por Supabase Auth ni una prueba de la PWA o de Realtime.

## Casos que terminaron sin excepciones
- Sin membresía, `debt_lab_access_valid` devuelve falso.
- Con membresía: contraseña incorrecta devuelve NULL; correcta autoriza; `debt_lab_lock` revoca la sesión.
- RLS: SELECT e INSERT bloqueados antes de desbloquear; SELECT, INSERT, UPDATE y DELETE permitidos tras desbloquear; SELECT bloqueado de nuevo después del cierre.
- Admin y Secretaria tienen sesiones independientes; otra sesión del mismo usuario no hereda el desbloqueo; bloquear Admin no revoca Secretaria.
- Expiración simulada en `debt_gate_lab.unlocks` invalida el acceso; cambiar `secrets.revision` revoca accesos anteriores.
- Cinco contraseñas erróneas consecutivas activan `blocked_until` durante aproximadamente 15 minutos. La contraseña correcta tampoco desbloquea durante ese período.

## Pendiente antes de publicar
- Pruebas HTTP/JWT auténticas con cuentas LAB, sin usar credenciales de producción.
- Realtime y sincronización de dos dispositivos, incluido modo offline/caché.
- Integrar el bloqueo en `index.html` y verificar que ninguna ruta de UI permita leer caché de Deudas sin autorización.
- Revisar SQL de producción, respaldar base real, preparar rollback, aprobación del corte y despliegue controlado.

**No ejecutar el SQL de LAB ni el borrador de migración sobre producción.**
