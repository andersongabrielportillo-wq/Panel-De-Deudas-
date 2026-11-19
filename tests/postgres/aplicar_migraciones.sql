\set ON_ERROR_STOP on
\echo 'Verificando migraciones de contratos en PostgreSQL temporal'
\i migrations/20261115_fase15i_contratos_base.sql
\i migrations/20261115_fase15ae_vendedores_manuales.sql
\i migrations/20261115_fase15j_contratos_rpc.sql
\i migrations/20261115_fase15k_historial_vendedores.sql
\i migrations/20261115_fase15n_catalogos_ficha_cliente.sql
\i migrations/20261115_fase15p_historial_cliente.sql
\i migrations/20261115_fase15q_confirmar_contrato.sql
DO $$
BEGIN
 IF to_regclass('public.inv_vendedores_manual') IS NULL THEN
  RAISE EXCEPTION 'Falta tabla manual'; END IF;
 IF to_regprocedure('public.inv_confirmar_contrato(uuid,jsonb,uuid)') IS NULL THEN
  RAISE EXCEPTION 'Falta RPC confirmacion'; END IF;
 IF to_regprocedure('public.inv_crear_vendedor_manual(text)') IS NULL THEN
  RAISE EXCEPTION 'Falta RPC vendedor manual'; END IF;
 IF EXISTS (SELECT 1 FROM public.inv_vendedores_manual) THEN
  RAISE EXCEPTION 'El catalogo manual debe iniciar vacio'; END IF;
END $$;
\echo 'Migraciones instaladas en PostgreSQL temporal: OK'
