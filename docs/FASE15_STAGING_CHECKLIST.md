# Fase 15 — Plan de certificación de contratos en staging (sin tocar producción)

**Estado:** procedimiento preparado; no se han aplicado migraciones ni creado usuarios.

## 1. Separación obligatoria
- Confirmar por ID que la conexión corresponde a un **proyecto de staging aislado** y no al proyecto productivo de Deudas ni al inventario poblado actual.
- Obtener autorización antes de crear/copiar bases, instalar migraciones, modificar usuarios o insertar registros.
- Copiar únicamente datos ficticios o anonimizados. No usar nombres, DUI, teléfonos ni contratos reales en pruebas.
- Tomar respaldo, guardar identificador del proyecto y plan de reversión.

## 2. Preflight de solo lectura
- Ejecutar `tests/15t_preflight_solo_lectura.sql`, `15u`, `15v`, `15w`, `15z` según sus dependencias.
- Ejecutar `tests/15aa_preflight_confirmacion_dependencias.sql` (7 verificaciones de funciones/columnas).
- Ejecutar `tests/15ab_preflight_roles_y_rpc_solo_lectura.sql` (roles y privilegios sin identidades).
- Ejecutar `tests/15ac_preflight_payload_ventas_solo_lectura.sql` (8 verificaciones de compatibilidad).
- Ejecutar `tests/15ad_preflight_separacion_inventario_vendedores_solo_lectura.sql` (5 verificaciones sin nombres ni escrituras).
- No interpretar resultados estáticos como ejecución exitosa de una venta.

## 3. Instalación aislada, solo tras autorización
- Instalar las siete migraciones 15I, 15AE, 15J, 15K, 15N, 15P, 15Q en ese orden. 15AE debe existir antes de 15J y 15K porque sus RPC consultan `inv_vendedores_manual`.
- Ejecutar `tests/15x_verificacion_postmigracion_solo_lectura.sql` y exigir que **todas** las tablas y las 12 RPC esperadas estén presentes y protegidas.
- Crear tres cuentas ficticias independientes: admin, secretaria y empleado. Actualmente el proyecto poblado de inventario no tiene membresías empleado; no cambiar usuarios reales para resolverlo.

## 4. Pruebas con JWT reales (no reemplazables por mocks)
1. Anónimo: negar todas las RPC sensibles de contratos y acceso directo a las seis tablas.
2. Empleado: negar crear cliente, crear borrador, consultar ficha sensible, registrar prima y confirmar contrato.
3. Admin y secretaria: permitir operaciones autorizadas con datos ficticios y registrar identidad de auditoría.
4. Probar RLS con SELECT/INSERT/UPDATE/DELETE directos a tablas sensibles: todos denegados para cliente normal; solo RPC autorizadas.
5. Confirmar borrador con artículos de prueba: exactamente una venta, una secuencia coherente de movimientos y descuento de existencias.
6. Reintentar con el mismo `client_op_id`: devolver la misma venta sin descontar existencias dos veces.
7. Reintentar con otro `client_op_id`: rechazar contrato ya confirmado.
8. Simular falta de existencias y error a mitad de operación: comprobar rollback total (sin contrato confirmado, venta huérfana ni movimiento parcial).
9. Anular venta de prueba: revisar el estado del contrato y la prohibición de tratar una venta anulada como confirmación vigente.
10. Simular doble clic, cambio de sesión, desconexión y recuperación en la interfaz.

## 5. Puerta de publicación
- GitHub Actions verde para el commit exacto que se publicará.
- PostgreSQL aislado y matriz de JWT aprobados con evidencia.
- Protección backend adicional de Deudas implementada y auditada; la contraseña visual sola no basta.
- Pruebas de sincronización/respaldos y recuperación realizadas.
- Revisión final y autorización explícita para fusionar y publicar.

**No ejecutar migraciones ni modificar datos en proyectos existentes como atajo.**

## 6. Requisitos de negocio confirmados
- El inventario proporcionado contiene artículos; **no usar sus nombres para precargar vendedores**. La sección Vendedores debe comenzar vacía y llenarse manualmente después.
- No borrar registros históricos de vendedores ni romper referencias de ventas existentes para conseguir la lista vacía. La nueva UI y sus RPC apuntan al registro manual vacío, pero faltan pruebas de integración real con JWT y vendedores ficticios antes de publicar.
- Al confirmar una venta, descontar stock mediante la RPC transaccional existente, una sola vez. Un borrador no descuenta; si falla cualquier artículo, no hay descuento parcial. Probar físicamente con datos ficticios antes de certificar.
