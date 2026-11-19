# Orden de migración autorizado — Comercial Lopez Pruebas

Autorización del usuario recibida en conversación. Alcance **exclusivo**: proyecto de pruebas `dozcnytevqhoymzqlxah`. Producción `josdmjjbnrugiwlwgjky`: prohibida.

## Preflight comprobado
- PostgreSQL 17.11.
- Ya existen `public.inv_vendedores`, `public.inv_ventas`, `public.inv_items`, `public.inv_members`.
- Faltan `public.inv_vendedores_manual`, `public.inv_contratos` y `public.inv_contrato_detalles`.
- No se ha verificado un respaldo externo recuperable del proyecto de pruebas.

## Secuencia requerida
1. `20261115_fase15ae_vendedores_manuales.sql`
2. `20261115_fase15i_contratos_base.sql`
3. `20261115_fase15j_contratos_rpc.sql`
4. `20261115_fase15k_historial_vendedores.sql`
5. `20261115_fase15n_catalogos_ficha_cliente.sql`
6. `20261115_fase15p_historial_cliente.sql`
7. `20261115_fase15q_confirmar_contrato.sql`

## Bloqueo de seguridad
**No ejecutar en el proyecto compartido hasta verificar respaldo recuperable** de esquema y datos previos, y comprobar el procedimiento de restauración. Las pruebas en PostgreSQL efímero ya aprobaron, pero no equivalen a backup del proyecto compartido.

## Validaciones después de aplicar
- Existencia de tablas, índices, funciones, permisos, RLS y secuencias.
- Rechazo a `anon` y usuarios sin membresía.
- Flujo con sesiones HTTP reales de administrador y secretaria, operaciones repetidas y confirmación concurrente.
- Sin cambios a `main` ni despliegue productivo.
