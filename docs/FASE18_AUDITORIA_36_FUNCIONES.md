# Fase 18 — Auditoría de 36 funciones privilegiadas y corrección de búsqueda

Proyecto **Comercial Lopez Pruebas**; producción intacta.

## Auditoría SQL directa
Se inspeccionaron las 36 funciones `public.inv_*` con `SECURITY DEFINER` mediante `pg_proc`, `pg_get_functiondef`, `has_function_privilege` y `proconfig`.
- **36/36** niegan `EXECUTE` a `anon`.
- **36/36** configuran `search_path` explícito vacío.
- Las funciones RPC expuestas a `authenticated` verifican `auth.uid()` y `inv_members` según inspección textual. Funciones de disparador/bloqueo no expuestas a `authenticated` no requieren ese mismo patrón.
- Esto es revisión de permisos y código, **no** prueba de autorización real con JWT ni garantía de ausencia de vulnerabilidades. Persisten advertencias del asesor sobre `SECURITY DEFINER`.

## Corrección de compatibilidad
`public.inv_buscar_clientes` exige longitud de búsqueda entre 3 y 100. Staging decía 2; ahora exige 3, con prueba de regresión.

## Pendiente
Pruebas HTTP autenticadas y de rechazo por rol, auditoría de lógica transaccional, y protección servidor del módulo Deudas. No habilitar escrituras ni desplegar PWA aún.
