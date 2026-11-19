# CL Nexus — preparación del corte seguro de Deudas (NO EJECUTAR EN PRODUCCIÓN)

Estado: borrador de revisión. Ninguna de las sentencias siguientes se ha aplicado a producción.

## Hallazgos comprobados
- Producción: public.debts usa RLS y cuatro políticas PERMISSIVE para authenticated.
- Membresía real: public.is_workspace_member(uuid) consulta public.workspace_members.
- Tabla public.debts: id text, workspace_id uuid, data jsonb, created_by uuid, updated_by uuid, created_at timestamptz, updated_at timestamptz.
- public.debts participa en supabase_realtime.
- La PWA de la rama tiene DEBT_GATE_ENABLED=false. NO cambiar el flag antes de activar RLS y RPCs reales.
- El laboratorio tiene RPCs debt_lab_unlock, debt_lab_access_valid, debt_lab_lock; NO apuntar la PWA real a esas RPCs.

## Bloqueos antes de publicar
1. Respaldar y verificar recuperación del estado __shared_state__, políticas, funciones, miembros y configuración de despliegue. Nunca subir datos reales al repositorio.
2. Crear en producción funciones propias (sin prefijo lab) de unlock, access_valid y lock, SECURITY DEFINER, search_path vacío, grants mínimos; usar public.is_workspace_member y auth.jwt()->>'session_id'; hash bcrypt y rate limit. Revisar permisos EXECUTE y revocación PUBLIC.
3. Verificar que el token real contiene session_id. Probar sesiones separadas y revocación.
4. Probar la nueva política RESTRICTIVE sobre una copia aislada del esquema, incluyendo SELECT/INSERT/UPDATE/DELETE, cambios en Realtime y usuarios sin rol.
5. Verificar que la PWA usa RPCs definitivas y el workspace real; desconectar Realtime, limpiar estado visible y bloquear cachés locales tras revocación. Verificar también Service Worker y respaldos.
6. Ejecutar corte coordinado: backend primero, frontend inmediatamente después, ventana de mantenimiento, comprobación de PC y teléfono, plan de rollback.

## Plantilla SQL de política (NO EJECUTAR SIN RPC DEFINITIVA)
-- El ejemplo utiliza public.debt_access_valid(uuid), que AÚN NO EXISTE.
-- Ejecutar solo tras crear y auditar esa función y confirmar que la UI está lista.
BEGIN;
CREATE POLICY debts_require_extra_unlock
  ON public.debts AS RESTRICTIVE FOR ALL TO authenticated
  USING (public.debt_access_valid(workspace_id))
  WITH CHECK (public.debt_access_valid(workspace_id));
-- Verificar pg_policies y acceso bajo sesión real antes de COMMIT.
-- COMMIT;  -- solo durante corte autorizado
ROLLBACK;   -- predeterminado seguro para revisión

## Reversión de la política (requiere autorización y plan de seguridad)
-- DROP POLICY IF EXISTS debts_require_extra_unlock ON public.debts;
-- ADVERTENCIA: retirar la política vuelve a permitir accesos por membresía sin segunda contraseña.
-- No hacer rollback aislado de RLS si la interfaz o las RPCs están desalineadas.

## Evidencia de laboratorio
- Desbloqueo real desde navegador y revocación real desde navegador: aprobados.
- RLS RESTRICTIVE vence una política SELECT permisiva: simulación aprobada con transacción revertida.
- Desbloqueo de una sesión no sirve en otra: simulación aprobada y revertida.
- Cambio de revisión invalida desbloqueos anteriores: simulación aprobada y revertida.

## Criterio de salida
Ningún acceso a public.debts ni evento sensible de Realtime sin permiso de membresía y autorización adicional de sesión vigente. Inventario, garantías y contratos permanecen independientes. Respaldo restaurable y rollback documentado.
