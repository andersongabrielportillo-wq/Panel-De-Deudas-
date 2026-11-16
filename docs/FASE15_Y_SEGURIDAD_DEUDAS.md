# Fase 15Y — Hallazgo de seguridad en módulo Deudas (auditoría de solo lectura)

Fecha: 15 de noviembre de 2026. Proyecto de producción consultado **sin escrituras**.

## Hallazgo confirmado
Las políticas RLS actuales de `public.debts` permiten SELECT, INSERT, UPDATE y DELETE a miembros autenticados del workspace, bajo `is_workspace_member(workspace_id)`; INSERT/UPDATE además comprueban autoría/actualización. **No se observa una condición de autorización adicional para la contraseña del módulo Deudas** en esas políticas. Un bloqueo visual del menú o formulario no equivale a protección de acceso a los datos a través de la API.

Se comprobó consultando `pg_catalog.pg_policies` para `debts`, `workspace_members` y `workspaces` en el proyecto actual. No se inspeccionaron ni modificaron datos de clientes.

## Riesgo
Una cuenta autenticada que pertenece al workspace puede potencialmente leer datos de Deudas mediante la API de Supabase aunque no haya introducido la contraseña adicional en la interfaz. Esto debe verificarse con cuentas de prueba antes de concluir que existe explotación práctica, pero la política RLS actual no implementa el segundo factor de acceso.

## Recomendación de arquitectura (NO desplegada)
1. Elegir método de autorización del módulo en servidor: preferiblemente concesión de sesión corta vinculada a usuario y workspace, validada mediante funciones `SECURITY DEFINER` con auditoría; evitar contraseña compartida en JavaScript.
2. Revocar acceso directo de `authenticated` a `public.debts` **solo después** de disponer de RPCs equivalentes para todas las operaciones existentes (lectura, inserción, edición, eliminación, sincronización/realtime y backups). Hacerlo antes rompería la PWA actual.
3. Las RPCs deberán comprobar membresía, concesión activa y permisos por operación; verificar que la autorización no se pueda reutilizar entre usuarios o workspaces.
4. Migración de datos y pruebas de regresión en proyecto aislado, con tres roles y dispositivos múltiples; plan de reversión y backup.
5. **No modificar políticas de producción sin aprobación explícita y pruebas completas.**

## Estado
Hallazgo documentado; corrección de backend pendiente. No hay cambio aplicado en producción.
