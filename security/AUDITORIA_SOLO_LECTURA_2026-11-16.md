# Auditoría CL2 — 2026-11-16 (solo lectura, parcial)

## Alcance y protección
Consultas SQL SELECT a metadatos en Supabase; no DML, no DDL, no RPC mutadoras, sin publicación ni contratación de infraestructura. Esta evidencia no certifica aprobación integral.

## Inventario de proyectos
- Proyecto `dozcnytevqhoymzqlxah` ("Comercial Lopez Pruebas"), ACTIVE_HEALTHY, creado 2026-11-09, base de datos propia: 21 tablas public, 13 tablas cl2_sandbox, 5 usuarios Auth.
- Proyecto `josdmjjbnrugiwlwgjky` ("Panel de Deudas"), ACTIVE_HEALTHY, base de datos propia: 4 tablas public, 0 tablas cl2_sandbox, 3 usuarios Auth.
- No hay ramas Supabase en el proyecto de pruebas (`branches: []`). **Hallazgo importante:** sí existe un proyecto Supabase separado del Panel de Deudas. Esto aporta separación física entre ambos proyectos, pero NO demuestra que las 21 tablas public y sus 5 usuarios sean totalmente ficticios, ni que la aplicación comercial no utilice el proyecto "Pruebas". No ejecutar movimientos destructivos sin confirmar aislamiento y naturaleza de datos.
- La ausencia de ramas no implica ausencia de proyectos separados; rectifica el alcance de la limitación comunicada anteriormente.

## Auditoría de privilegios (catálogo pg_proc)
- Se examinaron 40 funciones `public.inv_%` y `public.cl2_%` (33 inv_, 7 cl2_).
- Todas las funciones examinadas deniegan EXECUTE a `anon`; las funciones operativas conceden EXECUTE a `authenticated`. Este GRANT no prueba controles internos por perfil.
- Funciones operativas examinadas usan SECURITY DEFINER y search_path vacío; la función auxiliar `inv_hash_solicitud_venta` usa SECURITY INVOKER.
- Hashes MD5 de definición para control de cambios:
  - inv_anular_venta: c3566e118b8116dcf24b31a1ac2b679a
  - inv_crear_vendedor: 0361f8379dda51425e74da83bdfc3242
  - inv_liberar_garantia: 2605a6d55f0563f4e59f67e59916996c
  - inv_registrar_movimiento: f0233c01f056f0c8f90cdcd24b65d730

## Pendientes no ejecutados
1. Verificación de permisos **efectivos** mediante JWT auténticos de Administrador y Secretaria, con usuarios y recursos exclusivamente ficticios, incluyendo negativas.
2. Verificar que los datos del proyecto de pruebas no son comerciales ni utilizados por la aplicación principal.
3. Ejecutar matriz completa de entradas, salidas, devoluciones, traslados, ajustes, garantías, reparaciones, idempotencia y concurrencia, verificando invariantes de existencias y auditoría.
4. Revisar lógica interna de funciones privilegiadas y resolver políticas de anulación de ventas/creación de vendedores por Secretaria e idempotencia de inv_liberar_garantia.

**Estado: NO APROBADA.** Ninguna prueba de movimientos se ha ejecutado en esta revisión. No se modificaron datos ni infraestructura.
