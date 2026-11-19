# Fase 28 — Cierre de pruebas SQL y criterios para E2E real

**Fecha:** 2026-11-16. **Estado:** NO-GO para publicar.

## Evidencia ejecutada en LAB
Proyecto: `dozcnytevqhoymzqlxah`. Transacciones con `BEGIN` / `ROLLBACK`, rol `authenticated` y JWT simulado.

1. Admin y Secretaria: desbloqueo independiente por sesión, sin herencia a segunda sesión del mismo usuario.
2. Expiración forzada: acceso rechazado al caducar; reautorización posterior funciona.
3. Revisión de secreto incrementada: acceso previamente emitido revocado.
4. Cinco contraseñas erróneas: bloqueo de aproximadamente 15 minutos, incluso si después se ingresa la correcta.
5. Aislamiento entre workspaces A/B: SELECT solo devuelve filas de A; UPDATE y DELETE de B afectan cero filas; INSERT en B se rechaza.
6. Suplantación de `created_by` en INSERT se rechaza.
7. Usuario no miembro no ve deudas.
8. RLS inicial: SELECT/INSERT denegados bloqueado; CRUD autorizado después de desbloqueo; SELECT denegado al bloquear.

**Alcance de evidencia:** controles PostgreSQL y políticas RLS bajo rol/JWT simulados. No prueba de tokens auténticos, red HTTP/PostgREST, dispositivos, caché, Realtime ni frontend.

## Cambios de repositorio
- Cinco casos adicionales en `tests/debt-gate-client.test.mjs`: sesiones aisladas, carreras de desbloqueo, verificación retrasada, caducidad local, error de red.
- La auditoría `docs/CL-NEXUS-FASE27-AUDITORIA-CACHE-DEUDAS.md` identifica exposición de caché previa al desbloqueo. No se ha conectado aún la nueva pantalla.

## Bloqueos reales antes de una prueba E2E con dos dispositivos
- La PWA actual llama `loadPrivate()` antes de comprobar el gate de Deudas.
- El caché `cp_v2` y los cambios offline requieren política de cifrado/migración que evite pérdida de datos.
- El borrador de SQL de producción NO está aplicado. Una pantalla de contraseña aislada no sustituye el RLS.
- Faltan cuentas de prueba emitidas por Supabase Auth y pruebas HTTP auténticas en LAB.
- Faltan revisión de backup y rollback de base de datos real, integración de UI y validación multibodega/realtime con cuentas reales.

## Orden recomendado de ejecución
1. Preparar la pantalla de selección de módulos y el bloqueo de Deudas en rama, sin activarlo en producción.
2. Añadir tests de UI que demuestren que ninguna ruta de lectura/render/caché se ejecuta antes de autorizar.
3. Preparar y probar estrategia de caché offline con datos ficticios y preservación de pendientes.
4. Crear usuarios de prueba LAB con sesiones Supabase Auth reales y ejecutar HTTP/RPC/RLS.
5. Probar dos dispositivos simultáneos, conflictos, desconexión/reconexión y revocación.
6. Obtener backup verificable de producción, plan de reversión y aprobación explícita para el corte.

**Prohibido publicar o ejecutar la migración productiva antes de completar estos criterios.**
