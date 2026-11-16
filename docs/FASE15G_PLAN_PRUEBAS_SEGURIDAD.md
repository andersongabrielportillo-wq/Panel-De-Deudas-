# Fase 15G — Plan ejecutable de pruebas de seguridad (sin modificar datos)

Proyecto de origen: Comercial Lopez Pruebas (`dozcnytevqhoymzqlxah`).
Estado: **PLAN DE PRUEBAS**, no ejecución de casos de escritura. No usar datos reales.

## Últimas funciones privadas inspeccionadas

### inv_private.verificar_reintento_venta
- Rechaza identificador o hash nulo y hash de longitud distinta a 64.
- Busca `inv_ventas.client_op_id`; si no existe, devuelve NULL.
- Si existe con hash distinto, lanza excepción; si coincide, devuelve el UUID de venta.
- No está expuesta para EXECUTE directo a `authenticated` ni `anon` según consulta de privilegios.

### inv_private.consumir_autorizacion_reparacion
- Obtiene UUID de operación de la configuración transaccional.
- Consume autorización mediante DELETE ... WHERE id = (SELECT ... FOR UPDATE).
- Exige coincidencia de artículo, cantidad, operación, auth.uid(), txid_current(), pg_backend_pid() e identificador de operación.
- Devuelve false si no hay autorización coincidente.
- No está expuesta para EXECUTE directo a `authenticated` ni `anon` según consulta de privilegios.

## Matriz de pruebas en una COPIA aislada

| ID | Operación | Escenario | Resultado esperado |
|---|---|---|---|
| V01 | Venta | Usuario sin membresía | Rechazada; sin movimientos |
| V02 | Venta | Admin registra venta válida | Una venta, stock descontado una vez |
| V03 | Venta | Repetir mismo client_op_id y payload | Mismo ID, sin nuevo descuento |
| V04 | Venta | Repetir client_op_id con payload diferente | Error, sin cambios |
| V05 | Venta | Dos ventas simultáneas con stock para una | Solo una se confirma |
| A01 | Anulación | Anular venta válida | Stock restituido una sola vez |
| A02 | Anulación | Repetir anulación | Rechazada, sin doble restitución |
| A03 | Anulación | Venta con devolución vinculada | Rechazada |
| R01 | Recepción | Crear recepción pendiente | Stock sin cambios |
| R02 | Recepción | Aprobar una vez | Stock incrementado una vez |
| R03 | Recepción | Aprobar simultáneamente dos veces | Solo una aprobación |
| R04 | Recepción | Rechazar | Stock sin cambios |
| G01 | Garantía | Movimiento normal 3→1 sin autorización | Rechazado |
| G02 | Reparación | Envío 3→4 autorizado | Movimiento y stock consistentes |
| G03 | Reparación | Reenvío de reparación enviada | Rechazado |
| G04 | Reparación | Resolución 4→3 | Cantidad recibida consistente |
| G05 | Reparación | Reutilizar autorización consumida | Rechazado |
| P01 | Permisos | anon llama RPC de negocio | Rechazado |
| P02 | Permisos | authenticated escribe directamente en inv_stock | Rechazado |

## Consultas SQL de inspección — solo lectura

```sql
-- Verificar RLS de tablas inv_*:
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename LIKE 'inv_%'
ORDER BY tablename;

-- Verificar permisos de escritura concedidos al rol authenticated:
SELECT table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'authenticated'
  AND table_schema = 'public'
  AND table_name LIKE 'inv_%'
  AND privilege_type IN ('INSERT','UPDATE','DELETE')
ORDER BY table_name, privilege_type;

-- Verificar permisos EXECUTE de las funciones inv_*:
SELECT p.proname,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
       has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname = 'public' AND p.proname LIKE 'inv_%'
ORDER BY p.proname;
```

## Requisitos antes de ejecutar casos con escrituras
1. Crear un entorno de integración aislado con copias de esquema/funciones/triggers, sin datos de clientes.
2. Crear usuarios de prueba con roles separados.
3. Preparar stock ficticio y verificar claves foráneas.
4. Ejecutar casos mediante JWT de usuario (no desde SQL editor con rol privilegiado), registrar respuestas y estados antes/después.
5. Asegurar restauración de estado y limpieza de datos ficticios.
6. No conectar la PWA publicada ni alterar la base de producción.

## Nota
El examen de código no demuestra que las operaciones simultáneas sean seguras. Las expectativas de la matriz son hipótesis que deberán verificarse con pruebas.
