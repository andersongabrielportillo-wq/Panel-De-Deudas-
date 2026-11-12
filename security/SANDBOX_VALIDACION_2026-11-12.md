# Comercial López 2 — verificación del sandbox (2026-11-12)

## Alcance
Proyecto Supabase existente **Comercial Lopez Pruebas** (`dozcnytevqhoymzqlxah`). No es un proyecto Supabase nuevo; la cuota gratuita de proyectos activos impidió crearlo. Esquema privado **`cl2_sandbox`**, independiente de tablas de inventario `inv_*`. No se copió información real.

## Fixtures y comprobaciones realizadas
- `cl2_sandbox.test_debts`: una deuda sintética de $100.
- `cl2_sandbox.test_transactions`: un abono sintético de $15; saldo verificado $85.
- RLS activado en ambas tablas, sin políticas permisivas.
- `anon` y `authenticated` sin USAGE sobre esquema ni SELECT sobre tablas (consultas a `has_schema_privilege` y `has_table_privilege`).
- Bloque SQL de aserciones ejecutado sin error: saldo, importe negativo de deuda, abono negativo, abono a deuda inexistente, cantidad de fixtures y privilegios. Las inserciones inválidas se revierten mediante subtransacciones PL/pgSQL.
- Auditor de seguridad de Supabase consultado. La alerta `rls_enabled_no_policy` en las dos tablas del sandbox es **intencional**: no se deben exponer hasta que exista un acceso de prueba diseñado y validado.
- El auditor también detecta en el proyecto de Inventario `public.rls_auto_enable()` como SECURITY DEFINER ejecutable por `anon`, además de otras advertencias de funciones de inventario. No se alteraron esos objetos; revisar permisos y justificación antes de intervenir.

## Pendientes — NO declarar listo para producción
1. Diseñar una API de pruebas que permita cuentas de prueba sin conceder acceso a `inv_*`, ni abrir el esquema privado a clientes.
2. Pruebas reales de autenticación, autorización, sesiones distintas, expiración, limitación de intentos y realtime.
3. Pruebas E2E con navegador y varios dispositivos; casos de pagos, inventario, garantías, desconexión y sincronización.
4. Proteger datos locales `cp_v2`, `cp_v2_bak`, `cp_prev` sin perder cambios pendientes; actualmente son texto plano.
5. Probar en entorno aislado la migración de políticas de Deudas antes de ejecutarla en producción.
6. Respaldos verificables y aprobación explícita antes de publicación. La rama `feature/deudas-acceso-privado` sigue sin desplegar.

## Referencia de seguridad
Supabase: https://supabase.com/docs/guides/database/postgres/row-level-security
