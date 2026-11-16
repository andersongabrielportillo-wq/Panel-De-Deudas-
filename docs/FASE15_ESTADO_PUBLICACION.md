# Fase 15 — Estado de publicación (15 noviembre 2026)

## Alcance
Integración de contratos, clientes, referencias, vendedores, primas y ventas de inventario en Comercial López. **No modificar main ni producción hasta completar las puertas de publicación.**

## Revisión en GitHub
- Pull Request borrador #2: https://github.com/andersongabrielportillo-wq/Panel-De-Deudas-/pull/2 — abierto, no fusionado. GitHub Actions aún sin ejecución confirmada.

## Evidencia disponible
- 60 casos preparados: 24 API con mock de Supabase, 19 UI y 17 SQL estructurales/estáticos. Se ejecutaron 24 API y los 19 UI actuales en un intérprete adaptado sin fallos; las otras pruebas estructurales se ejecutaron previamente. No se ha confirmado la ejecución de las 60 pruebas juntas en CI. Los 19 casos actuales de interfaz se reejecutaron tras corregir revisiones obsoletas, altas duplicadas, catálogo vacío y eliminación de líneas. **No equivale a Node.js CI ni a PostgreSQL real.**
- Preflight read-only del proyecto de inventario: 12/12 dependencias iniciales, 6/6 dependencias de ventas, 5/5 verificaciones adicionales, 18/18 columnas de esquema compatibles y 3/3 firmas de RPC de ventas/movimientos/anulación verificadas.
- 15Q endurecida: si el contrato ya fue confirmado, solo admite reintento con el ID de operación original y rechaza venta anulada. Limita 100 líneas y total/ prima. No se ha aplicado al servidor.
- 34/34 casos estructurales/estáticos ejecutados sobre la versión más reciente en un entorno JavaScript adaptado; esto no sustituye GitHub Actions/Node.
- Seis migraciones SQL preparadas (15I/J/K/N/P/Q), **no aplicadas**. Tablas y RPC nuevos no instalados en el proyecto de pruebas al momento de la revisión.
- La rama de integración no es la rama de producción.

## Puertas obligatorias antes de publicar
- [ ] GitHub Actions / Node 22: 60 pruebas ejecutadas y aprobadas en CI, sin saltos.
- [ ] PostgreSQL aislado con copia anonimizada o datos ficticios: aplicar migraciones 15I/J/K/N/P/Q en orden, registrar resultados y comprobar reversibilidad. Ejecutar luego tests/15x_verificacion_postmigracion_solo_lectura.sql para auditar RLS, permisos y funciones.
- [ ] Probar JWT de admin, secretaria, empleado y usuario ajeno: permisos por función y acceso directo a tablas.
- [ ] Probar contrato de múltiples artículos y dos ubicaciones; verificar movimientos de stock y venta en una transacción.
- [ ] Probar reintento con mismo ID, concurrencia y rechazo por existencias insuficientes, comprobando ausencia de descuentos parciales.
- [ ] Probar prima pendiente/recibida y bitácora de entrega; historial de vendedor y ficha de cliente.
- [ ] Integrar interfaz con autenticación y navegación de la PWA principal, sin exponer secretos.
- [x] Auditar RLS actual de Deudas en producción con consulta de solo lectura: se identificó que la membresía de workspace permite acceso sin autorización adicional del módulo (ver docs/FASE15_Y_SEGURIDAD_DEUDAS.md).
- [ ] Implementar y probar protección adicional de Deudas en el servidor sin romper sincronización, después de diseñar RPCs y un entorno aislado.
- [ ] Pruebas de regresión de sincronización y roles en dos dispositivos, backup y plan de reversión.
- [ ] Aprobación explícita para desplegar cambios a producción.

## Porcentaje orientativo
**65% del trabajo de preparación**, no de certificación de lanzamiento. Las puertas de integración y pruebas reales siguen abiertas; este número es una estimación de gestión, no una métrica automatizada.
