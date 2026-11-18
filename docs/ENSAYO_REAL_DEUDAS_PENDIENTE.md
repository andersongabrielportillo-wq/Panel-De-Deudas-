# CL Nexus — preparación del ensayo real de Deudas (NO EJECUTAR CORTE)

## Resultado reproducible
- La suite aislada PostgreSQL 17 del commit e28cabc2 pasó 7/7 workflows. Las comprobaciones usan cuentas, JWT y contraseñas sintéticas.
- El proyecto staging de inventario NO tiene las tablas reales de Deudas. No es un ensayo fiel de producción.
- La migración de seguridad continúa en BORRADOR. No aplicar RLS ni activar `DEBT_GATE_ENABLED` de forma aislada.

## Secuencia obligatoria antes del corte
1. Obtener copia íntegra y verificable del registro compartido de Deudas en la nube, bajo custodia del propietario. No guardar información de clientes ni credenciales en GitHub o CI.
2. En cada PC y teléfono, exportar respaldo local cifrado, verificar apertura y cotejar cambios pendientes con la nube. La copia local no cubre la nube.
3. Preparar proyecto de ensayo aislado con esquema, grants, políticas, funciones y comportamiento de Auth equivalente a producción, pero solo con datos ficticios.
4. Comprobar JWT real con `session_id`, rol `authenticated`, membresía real, revocación de sesión, RPCs y acceso a `public.debts` bajo RLS. Verificar que Realtime y demás APIs no permitan leer Deudas sin desbloquear.
5. Validar admin, secretaria y cuenta no autorizada en PC y teléfono; probar cierre de sesión, expiración, cinco intentos fallidos y 15 minutos de bloqueo.
6. Aprobar contraseña compartida y aprovisionar su hash bcrypt mediante canal seguro, sin escribirla en código, repositorio, logs o chat.
7. Planificar ventana de mantenimiento, punto de restauración y reversión. Solicitar aprobación explícita antes de cualquier modificación en producción.
8. Coordinar RLS, RPC, frontend y Service Worker; verificar ambos dispositivos y revertir si algún requisito falla.

## No ejecutar
- No purgar `cp_v2`, `cp_v2_bak`, `cp_v2_corrupt`, `cp_prev`, `cp_items` ni `cp_pend` automáticamente.
- No confundir los siete workflows aprobados con autorización de migración.
- No usar el staging de inventario como si ya tuviera la base de Deudas.
