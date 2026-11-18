# Auditoría de solo lectura — 2026-11-18

Estado: INCOMPLETA / NO APROBADA.

## Alcance y método
Consultas SELECT sobre metadatos de pg_proc y pg_get_functiondef en proyecto Supabase `dozcnytevqhoymzqlxah` («Comercial Lopez Pruebas»). Se verificó mediante list_projects que también existe el proyecto separado `josdmjjbnrugiwlwgjky` («Panel de Deudas»). No se ejecutaron RPC modificadoras, DDL, migraciones ni escrituras SQL.

## Evidencias
Se enumeraron 44 funciones públicas con prefijos inv_ o cl2_: 36 ejecutables por rol PostgreSQL authenticated, ninguna por anon; 43 SECURITY DEFINER y una SECURITY INVOKER (inv_hash_solicitud_venta); las 44 muestran search_path vacío. Estas comprobaciones NO equivalen a pruebas de autorización por usuario JWT.

Funciones examinadas por código:
- inv_anular_venta: autoriza explícitamente roles admin y secretaria, valida motivo, bloquea venta/detalles, comprueba devoluciones y compensaciones previas.
- inv_crear_vendedor: autoriza explícitamente admin y secretaria, valida nombre.
- inv_liberar_garantia: autoriza admin y secretaria, valida destino 1/2, cantidad y observaciones, bloquea artículo y stock de garantía; genera internamente `v_operacion_id := gen_random_uuid()`. No recibe `client_op_id` del cliente, por lo que la protección de reintentos de la interfaz sandbox no subsana esta función productiva.

Huellas MD5 de definición SQL observadas:
- inv_anular_venta c3566e118b8116dcf24b31a1ac2b679a
- inv_crear_vendedor 0361f8379dda51425e74da83bdfc3242
- inv_liberar_garantia 2605a6d55f0563f4e59f67e59916996c
- inv_registrar_movimiento f0233c01f056f0c8f90cdcd24b65d730
- inv_registrar_venta 08b0b5cf946f2dcdb5c1d19d64348cc8
- cl2_sandbox_warranty_release_safe 70be4b633ff32d3b204b6da585d9749a

## Bloqueos
1. No se han probado permisos efectivos mediante JWT reales de Administrador y Secretaria.
2. No se ha certificado que el proyecto «Comercial Lopez Pruebas» esté libre de registros reales y de dependencias comerciales; no ejecutar movimientos allí hasta certificarlo.
3. No se ha ejecutado batería completa de movimientos, concurrencia, idempotencia y recuperación sobre datos ficticios en entorno certificado.
4. La liberación productiva de garantías sigue teniendo riesgo de repetición de solicitudes al generar el UUID dentro del servidor.

No se alteró producción ni se incurrió en costos. No publicar ni declarar éxito.
