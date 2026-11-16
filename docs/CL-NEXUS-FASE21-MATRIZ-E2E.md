# Matriz de pruebas funcionales CL Nexus — laboratorio

**Entorno:** exclusivamente proyecto de pruebas `dozcnytevqhoymzqlxah`. No ejecutar en producción. Usar artículos, clientes, vendedores y usuarios ficticios autorizados. No usar el antiguo flujo HTTP autenticado que se descartó.

## Permisos: tres identidades

- Administrador: acceso permitido a las operaciones definidas por las RPC.
- Secretaria: acceso permitido a las operaciones definidas por las RPC.
- No miembro: denegación de lectura y escritura; no debe poder cambiar existencias, contratos, garantías o datos de clientes.
- Anónimo: RPC no ejecutable. Esta condición fue comprobada por consulta de privilegios, pero falta validación funcional de sesión.

## Casos E2E obligatorios

| Caso | Acción | Resultado esperado |
|---|---|---|
| INV-01 | Solicitar entrada de 2 unidades | Solicitud pendiente; stock intacto |
| INV-02 | Secretaria aprueba entrada | Stock +2 exactamente una vez, movimiento registrado |
| INV-03 | Admin intenta aprobar la misma solicitud | Error de solicitud ya revisada; stock intacto |
| INV-04 | Rechazar otra entrada | Solicitud rechazada; stock intacto |
| INV-05 | Salida 1 unidad con destino NULL | Stock origen -1, movimiento salida |
| INV-06 | Traslado 1 unidad bodega 1 → 2 | Origen -1 y destino +1; total global intacto |
| INV-07 | Dos salidas simultáneas superiores a existencias | No permitir stock negativo; una o ambas rechazadas según stock |
| INV-08 | Reintento con mismo UUID de movimiento | No duplicar movimiento |
| DEV-01 | Solicitar devolución | No aumentar stock antes de aprobación |
| DEV-02 | Aprobar devolución | Aumentar stock una sola vez |
| GAR-01 | Liberar desde garantía hacia bodega 1 | Disminuir garantía, aumentar bodega 1 |
| GAR-02 | Liberar hacia ubicación 3 o 4 | Rechazar sin mutaciones |
| REP-01 | Crear y enviar orden de reparación | Estado y movimientos según RPC; sin doble envío |
| REP-02 | Resolver reparación | Rechazar resoluciones repetidas y cantidades inválidas |
| CON-01 | Crear cliente y vendedor ficticios | Registros visibles a roles autorizados |
| CON-02 | Crear borrador de contrato con detalles | No descontar stock en borrador |
| CON-03 | Confirmar con lista de `{detalle_id,location_id}` | Venta asociada, descuento correcto de stock |
| CON-04 | Confirmar dos veces con mismo UUID | Reutilizar venta existente sin descuento duplicado |
| CON-05 | Confirmar con UUID distinto tras confirmación | Rechazar |
| CON-06 | Confirmar con location_id 3 | Rechazar sin mutaciones |
| SEC-01 | No miembro intenta operaciones de cada módulo | Denegado sin efectos |
| SEC-02 | Cerrar sesión durante consulta | Descartar resultado y limpiar UI |
| SEC-03 | Cambiar de módulo durante operación | No presentar resultado en módulo diferente; comprobar efecto en servidor |
| DEP-01 | Instalar actualización de PWA | Conservar Deudas, sesión, datos y sincronización |

## Criterios de aprobación

- Capturar estado inicial y final de existencias y número de movimientos.
- Revisar audit trail y roles para cada caso, con IDs ficticios y sin credenciales en capturas.
- Verificar invariantes: stock no negativo; devoluciones pendientes no suman; confirmación idempotente; RLS; separación de datos Deudas/Inventario.
- Si una respuesta falla por desconexión, consultar el servidor antes de reintentar.
- No habilitar producción ni fusionar rama mientras exista un caso crítico fallido o no ejecutado.

## Hallazgo corregido

La función `inv_confirmar_contrato` requiere **array JSON**, una entrada por línea con `detalle_id` UUID y `location_id` numérico 1 o 2. La UI anterior aceptaba objeto; corregido en los commits de fase 21.
