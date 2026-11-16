# Fase 15 — Estado de publicación (15 noviembre 2026)

## Alcance
Integración de contratos, clientes, referencias, vendedores, primas y ventas de inventario en Comercial López. **No modificar main ni producción hasta completar las puertas de publicación.**

## Revisión en GitHub
- Pull Request borrador #2: https://github.com/andersongabrielportillo-wq/Panel-De-Deudas-/pull/2 — abierto, no fusionado. GitHub Actions ejecución #184 (commit 8f99bce): **success**, Node 22, sintaxis y pruebas unitarias completadas. También ejecución #187 (commit f340e8f): **success** con la nueva prueba de auditoría.

## Evidencia disponible
- 128 casos preparados: 36 API con mock de Supabase, 38 UI, 38 SQL estructurales/estáticos, 5 de montaje estático y 11 pruebas funcionales de montaje. Los 104 casos de la batería adaptada pasaron juntos; los 5 escenarios funcionales se ejecutaron aparte contra el código de montaje en JavaScript V8 (5/5). Las baterías se ejecutaron en un entorno JavaScript adaptado; tras ajustar una aserción obsoleta, las 36 pruebas de UI pasaron. El conjunto completo fue ejecutado después de los últimos ajustes. Confirmados flujos reales exitosos en Node 22: #184 y #187; el último incluye las 110 pruebas preparadas. Los 36 casos de interfaz incluyen protección contra búsquedas y fichas obsoletas, modificaciones durante el guardado y coerción de importes. **No equivale a Node.js CI ni a PostgreSQL real.**
- Preflight read-only del proyecto de inventario: 12/12 dependencias iniciales, 6/6 dependencias de ventas, 5/5 verificaciones adicionales, 18/18 columnas de esquema compatibles y 3/3 firmas de RPC de ventas/movimientos/anulación verificadas.
- 15J: búsqueda de clientes con coincidencia literal, sin interpretar comodines LIKE; validación estricta de primas y comisiones en API. DUI y longitud de referencias validados también en servidor.
- UI: las búsquedas y fichas anteriores no pisan resultados nuevos, se bloquean cambios de artículos/cliente durante el guardado y se rechazan booleanos en importes/cantidades. Estado visual e historial de vendedores descartan respuestas tardías; ficha muestra referencias y el historial incluye resumen financiero. Una confirmación tardía no borra ni reactiva la revisión de otro contrato.
- 15J: comprobaciones de tipos JSON, UUID y formatos monetarios antes de convertir datos de artículos en PostgreSQL; formato DUI estricto y prueba para impedir duplicación de funciones en la migración.
- 15Q: se verifican UUID de detalle y ubicaciones JSON numéricas antes de convertir. Se restauró el archivo tras detectar una edición defectuosa; pruebas estructurales repetidas.
- 15Q endurecida: si el contrato ya fue confirmado, solo admite reintento con el ID de operación original y rechaza venta anulada. Limita 100 líneas y total/ prima. No se ha aplicado al servidor.
- 27/27 casos estructurales/estáticos en la tanda anterior; una prueba adicional pendiente de confirmar en CI ejecutados sobre la versión más reciente en un entorno JavaScript adaptado; esto no sustituye GitHub Actions/Node.
- Montaje staging `prototipos/contratos-montaje-staging.js`: exige sesión autenticada, comprueba permisos mediante RPC antes de montar, evita doble montaje; cinco pruebas y workflow actualizados; revalida la identidad al terminar la comprobación de permisos. No está conectado a producción.
- Seis migraciones SQL preparadas (15I/J/K/N/P/Q), **no aplicadas**. Tablas y RPC nuevos no instalados en el proyecto de pruebas al momento de la revisión.
- La rama de integración no es la rama de producción.


## Auditoría adicional de roles y dependencias (solo lectura)
- En el proyecto de inventario de pruebas, el conteo actual de membresías por rol es **admin: 4, secretaria: 1, empleado: 0**. No se consultaron identidades ni se modificaron miembros. Por lo tanto, **no se puede declarar aprobada una prueba JWT real del rol empleado** hasta preparar un usuario ficticio en una base aislada.
- Las RPC existentes `inv_registrar_venta`, `inv_registrar_movimiento` e `inv_anular_venta` conceden EXECUTE a `authenticated`, no a `anon`, y son SECURITY DEFINER. Esto **no prueba** que el control de rol interno sea correcto; hace falta probar JWT y acceso directo.
- Firma real de `inv_registrar_venta`: `(uuid,text,jsonb,numeric,text,uuid) RETURNS uuid`, compatible en tipos y orden con la llamada de 15Q. Su ejecución transaccional aún no ha sido probada con las nuevas tablas.
- Auditoría reproducible: `tests/15ab_preflight_roles_y_rpc_solo_lectura.sql`.

## Puertas obligatorias antes de publicar
- [x] GitHub Actions / Node 22: ejecuciones #184 y #187 aprobadas; la #187 incluye las 110 pruebas anteriores; las 2 pruebas nuevas de roles están aprobadas en GitHub Actions #193 (commit de59d58f).
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
**83% del trabajo de preparación**, no de certificación de lanzamiento. Las puertas de integración y pruebas reales siguen abiertas; este número es una estimación de gestión, no una métrica automatizada.

- Verificación real de solo lectura en inventario: 7/7 dependencias de confirmación/ventas existentes (RPCs SECURITY DEFINER y columnas requeridas). Archivo reproducible `tests/15aa_preflight_confirmacion_dependencias.sql`; no se aplicaron migraciones ni se alteraron ventas.
- Cliente y servidor alineados para DUI: exactamente 9 dígitos o 8 dígitos-guion-1; dos pruebas nuevas API.

- Auditoría postmigración `tests/15x`: corregido falso positivo cuando falta una RPC; ahora enumera las 12 funciones esperadas y devuelve `false` para las ausentes. Prueba de regresión añadida.

- GitHub Actions #193: ejecución real con Node 22 terminada en `success`, incluye las 112 pruebas preparadas y auditoría de roles. No equivale a pruebas JWT reales ni a PostgreSQL con migraciones.

- Compatibilidad de venta verificada en PostgreSQL existente, **solo lectura**: 8/8 checks del payload de artículos, firma, movimientos e idempotencia (auditoría de código SQL, no venta ejecutada). Script `tests/15ac_preflight_payload_ventas_solo_lectura.sql`.
- GitHub Actions #198: `success` para commit 18417d5, con 114 pruebas preparadas, incluyendo dos nuevas pruebas de compatibilidad.
- Runbook de staging `docs/FASE15_STAGING_CHECKLIST.md`: roles JWT, RLS, rollback, doble descuento, reversión y protección Deudas; ninguna acción de escritura autorizada ni realizada.

- Prima: la RPC `inv_marcar_prima_recibida` bloquea primero el contrato, rechaza contrato anulado y venta vinculada anulada; dos pruebas de regresión añadidas. **Cambios solo en SQL de la rama, migraciones sin aplicar**.
- Para desbloquear pruebas PostgreSQL end-to-end con JWT se requiere autorización explícita para preparar un **nuevo entorno de staging vacío**, con usuarios y ventas ficticios. No usar el inventario poblado como sustituto.

- Seguridad de sesión en montaje staging: cierre de sesión o cambio de usuario desmonta contratos, desuscribe el observador y limpia datos visuales; controlador invalida consultas pendientes. Tres pruebas nuevas. No instalado en PWA publicada.
- Supabase: rama de desarrollo cotizada en $0.01344/h; usuario rechazó ese costo. **No crear rama de pago ni alterar bases actuales.**

- Blindaje adicional: respuestas tardías del expediente y confirmación de venta no reactivan controles ni reescriben la pantalla después de destruir el controlador. Se añade prueba estática. No cancela una RPC ya enviada al servidor: su resultado debe consultarse mediante idempotencia si la sesión termina a mitad de confirmación.

- Montaje cancelable durante RPC de permisos, con limpieza ante fallo de suscripción de autenticación. Dos pruebas funcionales adicionales; no se despliega en PWA.

## Regla de negocio confirmada: inventario y vendedores separados
- El archivo de inventario proporcionado por el usuario es **exclusivamente catálogo de artículos/existencias**. Los nombres incluidos en ese archivo NO representan vendedores y NO deben importarse, copiarse, inferirse ni sincronizarse a la sección de vendedores.
- La sección **Vendedores** debe iniciar **vacía** en la entrega; únicamente el usuario la llenará manualmente después de tener lista la aplicación.
- Prohibido usar registros de artículos, nombres de inventario o vendedores precargados como sustitutos. No crear vendedores ficticios en la aplicación final.
- Conservar intactos los registros existentes en `inv_vendedores` del staging poblado: **no borrar ni modificar** datos para vaciar la interfaz. Antes del despliegue se debe diseñar y validar la separación entre los vendedores históricos usados por ventas y el registro manual nuevo, sin alterar integridad referencial ni ventas previas.
- Bloqueo de publicación: la RPC actual `inv_catalogo_vendedores` lee `inv_vendedores`; por tanto, **todavía no satisface** el requisito de lista vacía. No declarar este punto completado hasta cambiar el origen del catálogo y probarlo con una base aislada.

## Regla obligatoria: descuento automático por venta confirmada
- Una venta **confirmada** debe descontar existencias de cada artículo vendido en su ubicación correspondiente. Una venta borrador no modifica stock.
- No implementar un segundo descuento desde la interfaz ni desde contratos: reutilizar exclusivamente la RPC transaccional existente `inv_registrar_venta` que coordina los movimientos del inventario.
- Rechazar ventas con stock insuficiente sin descuentos parciales; deduplicar reintentos mediante `client_op_id`; anulación mediante `inv_anular_venta` y sus reglas existentes, sin sumar stock manualmente en el navegador.
- En contratos, `inv_confirmar_contrato` debe registrar la venta y actualizar el estado del contrato dentro de la misma transacción, para evitar contrato confirmado sin descuento.
- Antes de publicar: probar en PostgreSQL aislado venta de uno y varios artículos, ubicaciones 1/2, falta de stock, reintento, anulación y concurrencia. No se ha ejecutado esta batería real todavía.
- Esta regla es independiente del catálogo de vendedores, que el usuario exige vacío al inicio.

- 15AD: auditoría de solo lectura para verificar separación de tablas de artículos/vendedores, sin listar nombres ni escribir datos; nueva prueba estática de catálogos. GitHub Actions #246 terminó en success. **Esto no certifica todavía la sección de vendedores vacía**, pues la RPC actual lee vendedores históricos.

- GitHub Actions #252: success para 127 pruebas preparadas. Añadidas dos aserciones de venta transaccional sin doble descuento y una prueba funcional contra cancelación obsoleta que no debe afectar al nuevo montaje. No son pruebas de ejecución PostgreSQL real.

## Fase 15AE: vendedores creados manualmente (migración propuesta)
- Preparada tabla nueva `inv_vendedores_manual`, inicialmente vacía, sin importación desde inventario y sin tocar vendedores históricos. Solo admin/secretaria mediante RPC pueden consultar y registrar; acceso directo a tabla denegado.
- **Pendiente:** enlazar esta tabla a los contratos y a la función de ventas de forma compatible con las claves foráneas y los registros históricos; la interfaz actual aún usa `inv_catalogo_vendedores`. No presentar la sección como terminada ni ejecutar 15AE en las bases existentes.
- Requiere revisar quién puede agregar vendedores en la UI final y validar en una base aislada que el primer catálogo no contiene registros.

- 15AE revisada: esquema real de `inv_vendedores` verificado solo lectura (id UUID, nombre, activo, creado_en). Alta manual crea un mismo UUID en tabla histórica de ventas y registro manual dentro de una transacción; catálogo manual permanece vacío hasta altas del usuario. La RPC actual de interfaz todavía necesita cambiarse al catálogo manual. No aplicada a ninguna base.
