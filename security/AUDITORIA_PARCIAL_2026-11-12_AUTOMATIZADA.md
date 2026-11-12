# Comercial López 2 — Auditoría aislada, ejecución 2026-11-12

## Alcance y garantías
Proyecto de prueba Supabase `dozcnytevqhoymzqlxah`; producción de Deudas `josdmjjbnrugiwlwgjky` sin acceso de escritura. No se modificaron registros reales ni se publicó código en producción. Todas las consultas de auditoría fueron de lectura; pruebas SQL encapsuladas en BEGIN/ROLLBACK.

## Auditoría de funciones privilegiadas
- Se inspeccionó código de `inv_registrar_movimiento`, `inv_revisar_entrada`, `inv_revisar_devolucion`, `inv_liberar_garantia`, `inv_anular_venta` e `inv_crear_vendedor`.
- Las funciones validan `auth.uid()` contra `public.inv_members` y requieren `admin` o `secretaria`; usan `SECURITY DEFINER` y `search_path=''`.
- La política actual autoriza a Secretaria a anular ventas y crear vendedores; requiere confirmación funcional de negocio, aunque no implica borrado permanente.
- `rls_auto_enable` es `SECURITY DEFINER` con `search_path=pg_catalog`, activa RLS en nuevas tablas de public mediante evento DDL. El analizador reportó permiso de ejecución anónimo; no se alteró el permiso sin una validación adicional.
- Disparadores presentes: inmutabilidad de movimientos, validación de rutas de reparación, protección de proveedor y garantía. Su presencia no equivale a prueba funcional exhaustiva.

## Pruebas no destructivas de autorización
- Simulación SQL mediante `set_config('request.jwt.claim.sub', user_id, true)` dentro de transacción revertida.
- Admin y Secretaria: `inv_registrar_movimiento` con tipo inválido devolvió exactamente «Tipo de movimiento no permitido», tras pasar autorización.
- Admin y Secretaria: `inv_revisar_entrada(NULL,NULL)` devolvió «Debes indicar la solicitud y la decisión», tras pasar autorización.
- Sin usuario: `inv_registrar_movimiento` devolvió «No tienes permiso para registrar movimientos».
- Todas las aserciones SQL finalizaron sin error y la transacción fue revertida.
- Limitación crucial: simular claim en sesión SQL privilegiada NO prueba JWT firmado, permisos PostgREST ni políticas RLS de sesión real.

## Pruebas de integridad ya ejecutadas
- En esquema ficticio `cl2_sandbox`: deuda 200, pagos 25+35, saldo 140; corrección 35→30, saldo 145; eliminación 25, saldo 170; inventario 10+5−3=12. Transacción revertida; conteo posterior de registros temporales 0.
- Restricciones inspeccionadas en `public.inv_movements`: cantidad positiva, rutas origen/destino, fecha no futura, ajuste directo bloqueado. `inv_stock` exige cantidad no negativa.
- No se ha ejecutado un ciclo end-to-end de las RPC reales con artículos y ubicaciones sintéticos en una copia completa e independiente de las tablas. NO afirmar cobertura completa.

## Próximas pruebas requeridas
1. Crear una réplica aislada de estructuras, dependencias, disparadores y funciones sin tocar `public.inv_*`; identificar dependencias hardcoded `public` e `inv_private` antes de duplicar.
2. Probar JWT reales de ambos roles con PostgREST, casos positivos y negativos y validaciones de RLS.
3. Matriz de entrada, salida, traslado, devolución, garantía, reparación, venta/anulación, concurrencia e idempotencia; evidenciar estados y reversión.
4. Corregir hallazgos confirmados únicamente en rama de desarrollo; repetir pruebas; no desplegar a producción sin autorización.
