# Fase 15E — Auditoría de rutas de garantía y reparación

Fecha: 2026-11-15. Proyecto: Comercial Lopez Pruebas (dozcnytevqhoymzqlxah).
Modo: inspección de definiciones SQL; **no se ejecutaron operaciones de negocio ni se alteraron datos**.

## Funciones inspeccionadas
- `inv_crear_reparacion`: exige membresía admin/secretaria, cantidad positiva, tipo proveedor/taller, nombre y motivo no vacíos y artículo activo. Registra reparación pendiente.
- `inv_enviar_reparacion`: exige admin/secretaria y reparación pendiente; bloquea reparación, artículo y stock; verifica cantidad en Garantía (ubicación 3); genera autorizaciones privadas, mueve 3→4 y cambia estado a enviado.
- `inv_resolver_reparacion`: exige admin/secretaria, reparación enviada, operación recepción/baja, cantidad positiva y observaciones; controla cantidad pendiente y stock en ubicación 4; recepción mueve 4→3 y baja descuenta stock.
- `inv_bloquear_salida_garantia`: impide disminución de stock en ubicación 3 sin autorización interna ligada a usuario, transacción, backend, operación y cantidad; admite destino 1/2 o 4 con reparación pendiente autorizada.
- `inv_bloquear_entrada_proveedor`: exige autorización de reparación para incrementar stock en ubicación 4.
- `inv_bloquear_salida_proveedor`: exige tipo de operación y autorización de reparación para disminuir stock en ubicación 4.
- `inv_validar_ruta_reparacion`: bloquea movimientos que tocan ubicación 4 sin registro privado coincidente, con rutas 3→4, 4→3 o salida desde 4.

## Fortalezas observadas
- Validación de roles dentro de funciones SECURITY DEFINER.
- Bloqueos FOR UPDATE para evitar carreras en operaciones sensibles.
- Validación de stock antes de descontar.
- Uso de autorizaciones privadas consumibles para rutas restringidas.
- Prevención de reenvío de una reparación cuyo estado ya no sea pendiente.
- Seguimiento de cantidades recibidas y dadas de baja.

## Aspectos por verificar
1. Inspeccionar `inv_private.consumir_autorizacion_reparacion` y `inv_bloquear_ruta_general_proveedor`; comprobar que el consumo no pueda reutilizarse.
2. Revisar funciones de ventas, anulaciones y recepciones y sus controles de concurrencia.
3. Revisar todas las rutas de escritura de stock y movimientos, incluidos triggers, para descartar bypass.
4. Verificar que observaciones sean obligatorias también en movimientos generales y no solo en reparación.
5. Ejecutar pruebas de permisos negativos, reintentos, concurrencia y doble aprobación **solo en entorno aislado**.
6. Verificar migración de identidades Supabase Auth y RLS por módulo antes de integración.

## Resultado
**Controles implementados en el código inspeccionado; no se certifica seguridad integral sin pruebas.** Ningún cambio a Supabase de producción, laboratorio ni rama main.
