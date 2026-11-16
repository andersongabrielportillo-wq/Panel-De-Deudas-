# Fase 15H — Requisitos de contratos digitales Comercial López

Fuente: documento proporcionado por el usuario, «CONTRATO DE CREDITO 2025.docx» (2 páginas). Esta especificación describe trabajo pendiente, NO funcionalidades implementadas.

## Campos exactos del contrato impreso
- Encabezado: número de contrato, fecha.
- Datos personales: nombre, dirección, ubicación, teléfono, DUI, vivienda alquilada/propia, lugar de trabajo y teléfono del trabajo.
- Dos referencias: nombre, teléfono, dirección y parentesco.
- Detalles del artículo: artículo, precio al crédito, prima, fecha de prima, resta, cuota, frecuencia semanal/quincenal/mensual.
- Plan 6 pagos: monto, resta, cuota, fecha.
- Plan 3 pagos: monto, resta, cuota, fecha.
- Cobranza: ruta, día, asesor de ventas, persona que recibe la letra si cliente ausente.
- Cláusulas impresas: mora 20% por cuota vencida, devolución/retiro sin devolución de dinero (texto contractual; no automatizar sin reglas validadas).
- Firmas de cliente y encargado (página 2).

## Requisitos adicionales confirmados por el usuario
- Buscar clientes por nombre o DUI, DUI normalizado e índice único cuando aplique.
- Ficha única de cliente, múltiples contratos por cliente.
- Una venta/contrato con múltiples artículos y precio individual de cada uno.
- Selección de vendedor mediante ID estable (no texto libre) y vinculación automática de venta al historial de ese vendedor.
- Comisión de vendedor registrada por contrato o línea, sujeto a definición pendiente.
- Prima: monto y estado `pendiente`/`recibida`; actualización posterior con usuario, fecha y bitácora inmutable. La prima recibida se la queda el vendedor.
- Reportes por vendedor: contratos/ventas, montos, comisiones y primas pendientes/recibidas.
- Recepción de pedidos de proveedor: no aumenta stock al crear pedido, solo al confirmar y aprobar mercadería recibida. Soportar recepción parcial.
- Distinguir registro de contrato, venta, movimientos de stock, cobranza y entrega de prima; no duplicar descuentos.
- Controlar acceso a datos personales y DUI mediante RLS, mínimo privilegio, trazabilidad y evitar mostrar DUI completo innecesariamente.

## Diseño de datos propuesto (pendiente de implementar)
- `inv_clientes`: id, nombre, dui_normalizado, datos de contacto, vivienda y trabajo.
- `inv_cliente_referencias`: cliente_id, orden (1/2), nombre, teléfono, dirección, parentesco.
- `inv_contratos`: id, numero, cliente_id, vendedor_id, fecha, ruta, dia_cobro, receptor_alterno, modalidad, plan, condiciones, etc.
- `inv_contrato_detalles`: contrato_id, item_id, cantidad, precio_credito_unitario, comisión asociada si aplica.
- `inv_contrato_primas`: contrato_id, monto, estado, fecha_recibida, recibido_por_vendedor_id, registrado_por.
- `inv_prima_eventos`: prima_id, estado_anterior, estado_nuevo, usuario, fecha, observaciones.
- Reutilizar `inv_ventas`/`inv_venta_detalles` cuando corresponda, mediante FK explícita y transacciones atómicas; evitar crear dos ventas por el mismo contrato.
- No guardar firmas digitales sin decidir método y consentimiento.

## Flujo propuesto
1. Buscar por nombre o DUI; crear cliente solo si no existe.
2. Elegir vendedor, ruta, frecuencia y plan.
3. Capturar referencias y todos los campos impresos.
4. Agregar una o varias líneas de artículo con precios.
5. Capturar prima y estado de recepción; registrar comisión separada.
6. Confirmar venta/contrato con idempotencia; descontar inventario una sola vez.
7. Consultar cliente por nombre/DUI y vendedor por historial.
8. Marcar prima pendiente como recibida mediante evento auditable.

## Pendiente de definir
- Comisión: por artículo o por contrato, porcentaje o monto fijo, cuándo se devenga/paga.
- Prima: si es única por contrato o por artículo; tratamiento de prima parcial.
- Número de contrato y si la firma será imagen o solo impresión.
- Validación legal de cláusulas y políticas de retención de datos personales.

No cambiar producción, main ni bases de datos en esta fase.
