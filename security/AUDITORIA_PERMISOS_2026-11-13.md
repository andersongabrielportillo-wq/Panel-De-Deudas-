# Comercial López 2 — Evidencia de auditoría, 2026-11-13

## Límites de ejecución
Solo consultas SELECT de catálogo en proyecto Supabase `dozcnytevqhoymzqlxah`. Ningún DDL, DML, llamada a RPC de negocio, publicación, gasto ni modificación de producción. Repositorio: rama `feature/deudas-acceso-privado`.

## Hallazgo: matriz de permisos SQL
Se consultó `pg_proc`, `pg_namespace`, `has_function_privilege` para roles `anon`, `authenticated` y `public` sobre las 23 funciones `public.inv_%`.

- 15 funciones de entrada RPC: EXECUTE para `authenticated=true`, `anon=false`, `public=false`. Son: inv_anular_venta, inv_crear_recepcion, inv_crear_reparacion, inv_crear_vendedor, inv_enviar_reparacion, inv_liberar_garantia, inv_registrar_movimiento, inv_registrar_venta, inv_resolver_reparacion, inv_revisar_devolucion, inv_revisar_entrada, inv_revisar_recepcion, inv_solicitar_devolucion, inv_solicitar_devolucion_venta, inv_solicitar_entrada.
- 8 funciones auxiliares/disparadores: EXECUTE denegado a los tres roles: inv_bloquear_entrada_proveedor, inv_bloquear_ruta_general_proveedor, inv_bloquear_salida_garantia, inv_bloquear_salida_proveedor, inv_hash_solicitud_venta, inv_inmutabilidad_movimientos, inv_rechazar_movimiento_normal_proveedor, inv_validar_ruta_reparacion.
- 22/23 usan SECURITY DEFINER; inv_hash_solicitud_venta es SECURITY INVOKER. Propietario reportado para todas: postgres. Las 23 declaran search_path vacío.
- La autorización SQL para el rol `authenticated` NO demuestra que Admin/Secretaria puedan ejecutar cada función: las RPC deben además validar membresía/rol y la ruta JWT/PostgREST. Tampoco prueba RLS real.

## Comparación con auditoría anterior
La revisión de 2026-11-12 había inspeccionado seis funciones privilegiadas y probado validaciones tempranas mediante claims simulados dentro de transacciones revertidas. La ejecución presente amplió inventario de privilegios a 23 funciones, sin intentar llamadas de negocio.

## Pendiente y bloqueo de cobertura
1. Falta disponer de un proyecto/instancia realmente independiente con datos sintéticos y copia completa de dependencias, funciones, disparadores, políticas y permisos. El esquema `cl2_sandbox` dentro del mismo proyecto NO constituye aislamiento completo.
2. Faltan sesiones JWT firmadas y autenticadas de Admin y Secretaria contra el entorno aislado, para verificar permisos efectivos por PostgREST.
3. Falta ejecutar y verificar exhaustivamente el ciclo completo de movimientos, reversión, concurrencia, reintentos, garantía, reparación, recepción, venta y anulación en esa instancia.
4. No se deben generar costos ni modificar las tablas reales. No hay aprobación de despliegue.

## Estado
PARCIAL. Ninguna conclusión de aprobación integral. Continuar en próxima ejecución si se puede establecer aislamiento verdadero sin costos ni escrituras sobre datos reales.
