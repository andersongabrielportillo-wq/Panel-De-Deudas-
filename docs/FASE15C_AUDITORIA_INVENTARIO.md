# Fase 15C — Inventario existente y estrategia de unificación

Fecha de revisión: 2026-11-15. Revisión solo lectura. NO desplegar.

## Proyectos confirmados
- Producción: Panel de Deudas, ref `josdmjjbnrugiwlwgjky`.
- Laboratorio de inventario: Comercial Lopez Pruebas, ref `dozcnytevqhoymzqlxah`.

## Inventario ya construido en el laboratorio
Tablas públicas existentes, todas con RLS habilitado:
`inv_members`, `inv_items`, `inv_locations`, `inv_stock`, `inv_movements`, `inv_returns`, `inv_entry_requests`, `inv_reparaciones`, `inv_vendedores`, `inv_ventas`, `inv_venta_detalles`, `inv_venta_anulacion_movimientos`, `inv_recepciones`, `inv_recepcion_detalles`.

Funciones públicas observadas: `inv_registrar_movimiento`, `inv_solicitar_entrada`, `inv_revisar_entrada`, `inv_solicitar_devolucion`, `inv_revisar_devolucion`, `inv_liberar_garantia`, `inv_crear_reparacion`, `inv_enviar_reparacion`, `inv_resolver_reparacion`, `inv_registrar_venta`, `inv_anular_venta`, `inv_crear_recepcion`, `inv_revisar_recepcion`, entre otras.

Los conteos observados incluyen `inv_items` 0 filas, `inv_locations` 0 filas, `inv_movements` 19 filas, `inv_stock` 4 filas y `inv_members` 3 filas. Los conteos pueden reflejar datos de pruebas; no asumir integridad referencial o equivalencia con datos reales sin verificarlos.

Políticas RLS observadas: SELECT para usuarios de `inv_members` en varias tablas; otras limitan lectura a roles admin/secretaria. **No equivale a una auditoría completa** de EXECUTE, SECURITY DEFINER, triggers ni permisos de escritura.

## Riesgo de autenticación
Cada proyecto Supabase tiene su propio Auth y su propio conjunto de UUID de usuario. Aunque existan tres usuarios en ambos proyectos, no asumir que sus UUID o roles coinciden. La PWA debe utilizar una sola sesión de Auth; no incrustar credenciales de ambos proyectos ni conectar de forma insegura desde el navegador.

## Camino propuesto
1. Auditar funciones, privilegios EXECUTE, triggers, tablas privadas, integridad y reglas de negocio del inventario de pruebas.
2. Diseñar copia/migración versionada de esquema, políticas y funciones a un entorno de integración; mapear membresías a identidades del proyecto definitivo.
3. Probar en un entorno aislado, con datos ficticios y sin tocar deudas reales.
4. Preparar controles de acceso a Deudas del lado servidor y RLS antes de mostrar datos detrás de la segunda contraseña.
5. Integrar interfaz en la rama GitHub y validar sesión, sincronización, respaldos, desconexión y Service Worker.
6. Revisión, copia de seguridad y despliegue controlado a producción.

## Invariantes
- Nunca modificar la rama main ni el Supabase de producción durante desarrollo.
- Mantener datos de deudas e inventario separados.
- No habilitar operaciones críticas del inventario sin superar pruebas de autorización.
- No copiar claves secretas ni contraseñas a GitHub.
- El aviso de actualización solo aparecerá cuando una versión final se publique y el Service Worker la detecte.
