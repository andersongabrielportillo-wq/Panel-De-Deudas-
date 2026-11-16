# Fase 23 — Preparación del corte seguro de Deudas y CL Nexus

> **NO APLICAR A PRODUCCIÓN.** Documento de diseño y lista de verificación. No contiene credenciales ni contraseñas. El sistema actual funciona con acceso directo a `public.debts` y una fila `__shared_state__`.

## Hallazgo verificado en producción (lectura, 2026-11-16)

- `public.debts` tiene columnas `id text`, `workspace_id uuid`, `data jsonb`, `created_by uuid`, `updated_by uuid`, `created_at`, `updated_at`.
- Las políticas actuales `members_read_debts`, `members_insert_debts`, `members_update_debts`, `members_delete_debts` autorizan a miembros del workspace **sin contraseña adicional**.
- `index.html` usa `SB.from('debts')` para lectura/escritura y Realtime de `postgres_changes`. Ocultar la pestaña Deudas o pedir un PIN solo en frontend **no protege las APIs**.
- En producción no existen las RPC `inv_%` del laboratorio. Nunca apuntar el cliente de producción al proyecto de pruebas.

## Diseño de seguridad propuesto (sin despliegue)

1. **Credencial de Deudas por workspace:** almacenar solo hash resistente a ataques de diccionario (Argon2id mediante servicio backend, o bcrypt mediante `pgcrypto` con control de tasa). Nunca incluir secreto ni hash en JS, repositorio, localStorage o respuestas RPC.
2. **Desbloqueo en servidor:** endpoint/RPC que valide JWT actual, pertenencia a `workspace_members`, contraseña, límite de intentos y registre auditoría. Tras éxito crear autorización temporal ligada a `auth.uid()` y `workspace_id`, con vencimiento, revocación al cerrar sesión y al cambiar contraseña.
3. **Protección real de API:** modificar RLS de `public.debts` para exigir **membresía Y autorización temporal vigente** en SELECT/INSERT/UPDATE/DELETE; alternativamente revocar acceso directo y exponer RPC estrictamente autorizadas. No dejar la política anterior en paralelo: políticas permisivas se combinan con OR y permitirían saltarse el bloqueo.
4. **Realtime:** comprobar que el canal de cambios de `debts` no entregue información antes del desbloqueo ni después de la revocación; reconectar al desbloquear. Evitar eventos con datos privados si la autorización caducó.
5. **PWA:** mantener login único, CL Nexus disponible tras login, pedir contraseña solo al entrar a Deudas, bloquear el estado de Deudas en memoria/pantalla hasta validar servidor; limpiar datos y cancelar suscripciones al bloquear/cerrar sesión.
6. **Sincronización:** adaptar `cloudSnapshot`, `cloudSet`, `connectCloud`, `onRemote` y la cola `SY.pend` para no enviar cambios antes de autorización. Probar tres cuentas y reintentos después de expirar sesión.
7. **Despliegue atómico:** respaldo y restauración comprobada; publicar primero cliente compatible con bloqueo en laboratorio, aplicar políticas y backend en ventana controlada, probar admin/secretaria/tercero y rollback documentado. No ejecutar política restrictiva antes de que el cliente soporte desbloqueo.

## Plan de migración de CL Nexus

1. Inventariar en laboratorio todas las tablas, secuencias, constraints, índices, triggers, funciones y dependencias de esquemas `public.inv_%`, `inv_private` y roles.
2. Extraer migraciones reproducibles y versionadas con CLI compatible; comprobar cambios de Supabase CLI v3 antes de elegir comandos.
3. Revisión de `SECURITY DEFINER`, `search_path`, grants, RLS y funciones invocadas indirectamente. No copiar usuarios ficticios ni datos del laboratorio.
4. Ejecutar primero sobre clon/restauración **no productivo** del esquema real de Deudas; verificar que no cambia `public.debts`, `workspace_members` ni el estado `__shared_state__`.
5. Validar matriz E2E con identidades reales de prueba y operaciones ficticias; concurrencia desde conexiones independientes.
6. Publicación controlada con aprobación explícita, copia de seguridad verificada y rollback.

## Puertas de salida obligatorias

- [ ] Sesiones auténticas admin/secretaria/no miembro probadas en laboratorio.
- [ ] Pruebas de movimientos y contratos con stock inicial/final registradas.
- [ ] Concurrencia desde dos conexiones y reintentos de red verificados.
- [ ] Backend de contraseña adicional implementado y probado contra llamadas directas a REST/RPC y Realtime.
- [ ] Migraciones CL Nexus reproducibles, sin datos ficticios ni cambios en Deudas.
- [ ] Plan de restauración y publicación aprobado por el responsable.

**Estado:** NO LISTO PARA PRODUCCIÓN. Este documento no constituye una migración ejecutable.
