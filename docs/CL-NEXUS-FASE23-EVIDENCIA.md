# Fase 23 — Evidencia de ejecución (2026-11-16)

## Hecho y comprobado

- Inspección **solo lectura** de políticas de `public.debts` en producción: 4 políticas existentes permiten operaciones a miembros del workspace sin segunda contraseña. `authenticated` tiene privilegios SQL de SELECT/INSERT/UPDATE/DELETE; `anon` no tiene SELECT.
- Laboratorio: inventario sin stock negativo, movimientos de salida con destino incorrecto, traslados inválidos ni identificadores duplicados (todos los contadores consultados = 0). No se ejecutaron movimientos reales de prueba.
- Laboratorio: `inv_members` contiene 4 administradores y 1 secretaria; `cl2_sandbox.test_members` contiene 2 administradores y 1 secretaria. **La pertenencia no sustituye prueba de inicio de sesión.**
- Función `cl2_sandbox_test_sale` examinada: utiliza bloqueo por identificador de operación, bloqueo `FOR UPDATE` sobre stock y resultado `registered`, `already_registered` o `insufficient_stock`.
- Staging incorpora botones para probar `inv_revisar_entrada` con UUID ficticio inexistente y para lanzar dos ventas simultáneas en `cl2_sandbox`, siempre con JWT de una sesión de prueba real y confirmación antes de escribir.
- GitHub Actions de commit `152222c9`: dos ejecuciones satisfactorias. La suite valida estructura y seguridad de frontend, no sustituye los resultados de la API real.

## Pendiente (no afirmar que está aprobado)

1. Iniciar sesión en staging con cada cuenta de laboratorio y pulsar «Verificar permisos»; conservar resultado por rol. **No enviar contraseñas al chat.**
2. Registrar existencias de un artículo de `cl2_sandbox.test_concurrency_stock`, ejecutar la prueba desde staging y volver a consultar existencias y ventas. Para demostrar carreras de stock, repetir con existencias insuficientes y dos conexiones separadas.
3. Probar las 24 operaciones de la matriz con datos ficticios y comparar existencias antes/después.
4. Revisar y probar `docs/sql/debt-gate-review-only.sql` en un clon, con hashes configurados fuera del repositorio, verificación de JWT, bloqueo por intentos, RLS, Realtime, compatibilidad del frontend y rollback.
5. Generar migraciones versionadas CL Nexus tras inventario de dependencias; ninguna migración fue aplicada a producción.

## Referencias

- `docs/CL-NEXUS-FASE21-MATRIZ-E2E.md`
- `docs/CL-NEXUS-FASE23-PLAN-CORTE-SEGURO.md`
- `docs/sql/debt-gate-review-only.sql`

**Estado final: pruebas reales de sesión y concurrencia preparadas para ejecutar, NO ejecutadas. Backend de Deudas diseñado en borrador, NO instalado. Producción sin cambios.**
