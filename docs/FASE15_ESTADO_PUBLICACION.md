# Fase 15 — Estado de publicación (15 noviembre 2026)

## Alcance
Integración de contratos, clientes, referencias, vendedores, primas y ventas de inventario en Comercial López. **No modificar main ni producción hasta completar las puertas de publicación.**

## Revisión en GitHub
- Pull Request borrador #2: https://github.com/andersongabrielportillo-wq/Panel-De-Deudas-/pull/2 — abierto, no fusionado. GitHub Actions aún sin ejecución confirmada.

## Evidencia disponible
- 101 casos preparados: 34 API con mock de Supabase, 36 UI, 27 SQL estructurales/estáticos y 4 de montaje de staging. Las baterías se ejecutaron en un entorno JavaScript adaptado; tras ajustar una aserción obsoleta, las 36 pruebas de UI pasaron. No se ha ejecutado aún el conjunto completo de 101 tras ese último ajuste. No se ha confirmado la ejecución de las 101 pruebas en GitHub Actions. Los 36 casos de interfaz incluyen protección contra búsquedas y fichas obsoletas, modificaciones durante el guardado y coerción de importes. **No equivale a Node.js CI ni a PostgreSQL real.**
- Preflight read-only del proyecto de inventario: 12/12 dependencias iniciales, 6/6 dependencias de ventas, 5/5 verificaciones adicionales, 18/18 columnas de esquema compatibles y 3/3 firmas de RPC de ventas/movimientos/anulación verificadas.
- 15J: búsqueda de clientes con coincidencia literal, sin interpretar comodines LIKE; validación estricta de primas y comisiones en API. DUI y longitud de referencias validados también en servidor.
- UI: las búsquedas y fichas anteriores no pisan resultados nuevos, se bloquean cambios de artículos/cliente durante el guardado y se rechazan booleanos en importes/cantidades. Estado visual e historial de vendedores descartan respuestas tardías; ficha muestra referencias y el historial incluye resumen financiero. Una confirmación tardía no borra ni reactiva la revisión de otro contrato.
- 15J: comprobaciones de tipos JSON, UUID y formatos monetarios antes de convertir datos de artículos en PostgreSQL; formato DUI estricto y prueba para impedir duplicación de funciones en la migración.
- 15Q: se verifican UUID de detalle y ubicaciones JSON numéricas antes de convertir. Se restauró el archivo tras detectar una edición defectuosa; pruebas estructurales repetidas.
- 15Q endurecida: si el contrato ya fue confirmado, solo admite reintento con el ID de operación original y rechaza venta anulada. Limita 100 líneas y total/ prima. No se ha aplicado al servidor.
- 27/27 casos estructurales/estáticos ejecutados sobre la versión más reciente en un entorno JavaScript adaptado; esto no sustituye GitHub Actions/Node.
- Montaje staging `prototipos/contratos-montaje-staging.js`: exige sesión autenticada, comprueba permisos mediante RPC antes de montar, evita doble montaje; cuatro pruebas y workflow actualizados. No está conectado a producción.
- Seis migraciones SQL preparadas (15I/J/K/N/P/Q), **no aplicadas**. Tablas y RPC nuevos no instalados en el proyecto de pruebas al momento de la revisión.
- La rama de integración no es la rama de producción.

## Puertas obligatorias antes de publicar
- [ ] GitHub Actions / Node 22: 101 pruebas ejecutadas y aprobadas en CI, sin saltos.
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
**79% del trabajo de preparación**, no de certificación de lanzamiento. Las puertas de integración y pruebas reales siguen abiertas; este número es una estimación de gestión, no una métrica automatizada.
