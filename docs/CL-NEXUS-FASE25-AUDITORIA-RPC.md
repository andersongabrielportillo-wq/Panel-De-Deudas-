# Fase 25 — Auditoría de ejecución de RPC (laboratorio)

Fecha: 2026-11-16.

Se consultó directamente `pg_proc` en el proyecto de laboratorio `dozcnytevqhoymzqlxah` para todas las funciones `SECURITY DEFINER` cuyo nombre comienza con `inv_` o `cl2_`. Se comprobó `has_function_privilege('anon', oid, 'EXECUTE')`, `has_function_privilege('authenticated', oid, 'EXECUTE')` y la presencia textual de comprobaciones de usuario/membresía en su definición.

**Resultado:** 40 funciones revisadas; ninguna permite `EXECUTE` a `anon`. Las funciones operativas `inv_` invocables por `authenticated` contienen comprobación textual de `inv_members` y `auth.uid()`. Las funciones `cl2_` son del sandbox aislado y verifican identidad; deben revisarse contra su tabla de membresía propia. Los triggers internos `inv_` no son ejecutables directamente por `authenticated`.

**Límites:** un escaneo de código SQL no prueba por sí solo que todos los caminos de autorización sean correctos. No se ejecutaron operaciones con JWT real de Administrador, Secretaria o usuario ajeno; tampoco se ejecutó concurrencia de stock en esta fase.

**CI:** dos ejecuciones consecutivas de `cl-nexus-shell` para el commit `6daf95e2` completaron con `success`. Se mantuvo `main` sin cambios y producción sin modificaciones.

**Próximo paso obligatorio:** iniciar sesión en staging de laboratorio con las dos cuentas y verificar autorización de operaciones, rechazo a terceros, concurrencia e integridad del stock. El backend de contraseña de Deudas y el despliegue controlado siguen pendientes.
