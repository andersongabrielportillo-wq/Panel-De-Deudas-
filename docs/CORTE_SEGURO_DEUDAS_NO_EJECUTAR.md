# CL Nexus — lista de corte seguro para Deudas

**Estado:** preparación; **NO ejecutar migración de producción sin autorización explícita**. El borrador `sql/deudas_gate_produccion_BORRADOR_NO_EJECUTAR.sql` no instala por sí solo la contraseña compartida y puede bloquear acceso a Deudas si se ejecuta prematuramente.

## P0 — Protección de datos (bloquea el corte)
- [ ] Exportar y verificar respaldo **de la nube** de la fila compartida de Deudas, con integridad y ubicación segura, sin incluir datos personales en registros de pruebas.
- [ ] En cada navegador/dispositivo usado para Deudas, exportar respaldo **local cifrado** y comprobar su apertura con «Verificar respaldo cifrado». La copia local **no sustituye** a la nube.
- [ ] Confirmar `cp_pend` sin cambios sin sincronizar y comparar último estado de la nube con los dispositivos. Un marcador ausente o `0` **no prueba por sí solo** sincronización completa.
- [ ] Guardar procedimiento probado de restauración y designar ventana de mantenimiento.

## P1 — Seguridad (bloquea el corte)
- [ ] **BLOQUEADO para ensayo con Auth real:** el proyecto staging actual no contiene `public.workspaces`, `public.workspace_members` ni `public.debts`; crear/validar un entorno aislado con esquema equivalente (sin copiar datos personales) antes de probar la migración SQL, RLS, RPC y roles.
- [x] **Auditoría de metadatos productivos (solo lectura, 18 nov 2026):** RLS de `public.debts` activo; cuatro políticas `PERMISSIVE` para `authenticated` (SELECT, INSERT, UPDATE, DELETE), todas basadas en membresía; todavía no existen las tres RPC del gate ni su esquema privado. Este resultado **no autoriza el corte**.
- [x] **Inventario de staging (solo lectura, 18 nov 2026):** existen tablas `inv_*` pero faltan las tres tablas de Deudas indicadas arriba; no usar este proyecto como ensayo equivalente hasta preparar un esquema aislado compatible.
- [x] **Ensayo SQL aislado con datos ficticios (18 nov 2026):** siete flujos CI aprobados; contraseña correcta, separación de sesiones, bloqueo manual, caducidad, revocación por revisión, rechazo de no miembro, cinco fallos consecutivos, bloqueo de 15 minutos, rechazo de contraseña correcta durante bloqueo y recuperación tras vencimiento. **No sustituye** pruebas reales de JWT, roles, RLS bajo `authenticated` ni APIs/Realtime.
- [ ] Provisionar hash bcrypt de contraseña por canal seguro **sin poner contraseña ni hash en GitHub**.
- [ ] Confirmar que el JWT real contiene `session_id` UUID; verificar comportamiento cuando falta o expira.
- [ ] Probar con admin, secretaria y usuario no autorizado; comprobar bloqueo tras intentos fallidos, expiración, cierre de sesión y revocación.
- [ ] Verificar que ningún endpoint/API ni suscripción Realtime permite saltarse la autorización adicional.

## P2 — Funcionalidad y sincronización
- [ ] Probar lectura, edición y sincronización real de Deudas en PC y teléfono.
- [ ] Probar inventario, ventas, anulaciones, garantías y roles con dos sesiones simultáneas.
- [ ] Comprobar idempotencia, stock insuficiente, errores de red y recuperación de cambios pendientes.

## P3 — Publicación controlada
- [ ] Obtener aprobación explícita del propietario tras revisar respaldos y plan de reversión.
- [ ] Coordinar despliegue frontend, contraseña compartida y RLS en una ventana de mantenimiento; **no habilitar el gate de frontend ni aplicar RLS por separado**.
- [ ] Confirmar funcionamiento en ambas cuentas y dispositivos, incluyendo actualización de Service Worker.
- [ ] Vigilar errores y conservar copias para reversión; nunca borrar automáticamente caché heredada.

## Condiciones de NO-GO
Cualquier respaldo ausente/no verificable, datos locales pendientes, fallo de RLS, permisos incorrectos, diferencia entre estados, contraseña no provisionada, pruebas fallidas o falta de aprobación implica **NO MIGRAR**.
