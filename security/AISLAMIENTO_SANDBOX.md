# Aislamiento de Deudas e Inventario — sandbox (2026-11-12)

## Entorno
- Archivo de prueba: `sandbox/index.html`. No reemplaza `index.html` de producción ni está desplegado.
- **Único proyecto de Supabase usado por la página**: `dozcnytevqhoymzqlxah` (Comercial Lopez Pruebas).
- **Deudas**: `cl2_sandbox.test_debts` y `cl2_sandbox.test_transactions`, solo datos sintéticos.
- **Inventario**: `cl2_sandbox.test_inventory_items`, independiente de `public.inv_*`; no se concedió membresía de inventario a los usuarios de prueba.
- **Roles**: `cl2_sandbox.test_members` contiene una cuenta de administrador y una de secretaria; no se copian datos reales.
- **Acceso**: `public.cl2_sandbox_status()` y `public.cl2_sandbox_list(text)` verifican `auth.uid()` y membresía; RPC concedidas solo a `authenticated`. Las tablas privadas tienen RLS activado y no conceden acceso directo a `anon` ni `authenticated`.
- La página guarda su sesión Auth bajo `cl2-sandbox-auth`, separado del almacenamiento Auth de la app normal.
- No hay clave ni URL del proyecto de producción de Deudas en `sandbox/index.html`.

## Verificaciones ejecutadas
- Migración SQL aplicada con éxito en proyecto de pruebas.
- Pruebas de RPC bajo roles SQL `anon` y `authenticated` sin JWT válido: las cuatro solicitudes fueron rechazadas. **No equivalen a sesiones Auth reales**.
- Sintaxis del JavaScript de `sandbox/index.html`: correcta.
- Auditor de seguridad revisado: avisos `rls_enabled_no_policy` en las tablas privadas son intencionales; advertencias de funciones SECURITY DEFINER autenticadas se deben a los dos RPC del sandbox que validan membresía. Revisar estos privilegios antes de ampliar funciones.

## Limitaciones y pendientes
- No se ha iniciado sesión mediante navegador con las dos cuentas reales de prueba. No afirmar que se completó E2E.
- La página es una **interfaz de consulta**, no la aplicación completa de Deudas ni Inventario; operaciones de pagos, entradas, garantías, realtime y offline no están probadas en esta página.
- La rama principal y la producción permanecen sin cambios.
- No abrir `cl2_sandbox` en los esquemas expuestos del Data API ni otorgar permisos directos a los roles cliente.
- Antes de publicar la PWA completa: sustituir conexiones de producción por endpoints de sandbox en una compilación de prueba separada y crear pruebas E2E con usuarios autenticados, sin exponer datos reales.
