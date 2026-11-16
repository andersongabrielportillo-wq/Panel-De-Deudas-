# Fase 24 — Paridad operativa de Administrador y Secretaria

## Cambio aplicado en laboratorio (2026-11-16)

La función `public.inv_crear_vendedor_manual(text)` exigía exclusivamente `m.rol='admin'`. Se aplicó mediante migración `allow_secretaria_create_manual_vendor` el cambio a `m.rol IN ('admin','secretaria')` en el proyecto LAB. Se comprobó después que la definición almacenada contiene ambos roles. **No se modificó producción.**

La función `inv_anular_venta` ya acepta `admin` y `secretaria`, exige motivo, bloquea registros y restituye existencias con movimientos compensatorios. No se han ejecutado todavía sesiones E2E.

## Decisión de producto

Solo dos personas operarán CL Nexus: Administrador y Secretaria, con iguales permisos operativos de Inventario, Garantías y Contratos, incluidas anulaciones permitidas y registradas. Una sesión ajena debe ser rechazada por el servidor. La contraseña adicional de Deudas sigue siendo un requisito independiente.

## Bloqueadores antes de publicar

1. Validar sesión real de cada rol y rechazo de un no miembro; verificar operaciones y concurrencia con existencias iniciales/finales.
2. Auditar funciones RPC de inventario y sus grants; evitar funciones `SECURITY DEFINER` expuestas sin comprobación de membresía.
3. Implementar y probar backend de contraseña de Deudas y cliente compatible. El borrador SQL `docs/sql/debt-gate-review-only.sql` **no está listo para ejecutar**.
4. Preparar y validar migración CL Nexus en clon; respaldo, rollback y despliegue controlado.

**Estado:** permiso puntual corregido en LAB y verificado por definición SQL; publicación general pendiente.
