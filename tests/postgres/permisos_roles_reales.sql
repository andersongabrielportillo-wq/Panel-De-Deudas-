\set ON_ERROR_STOP on
-- Verifica permisos PostgreSQL como rol authenticated real (JWT emulado por GUC).
-- NO equivale a autenticacion JWT firmada por Supabase.
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
DO $$
DECLARE v_n integer;
BEGIN
 SELECT count(*) INTO v_n FROM public.inv_catalogo_vendedores_manual();
 IF v_n<>1 THEN RAISE EXCEPTION 'RPC de catalogo no disponible para authenticated admin'; END IF;
 BEGIN
  EXECUTE 'SELECT count(*) FROM public.inv_clientes';
  RAISE EXCEPTION 'Acceso directo a clientes permitido';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  EXECUTE 'SELECT count(*) FROM public.inv_contratos';
  RAISE EXCEPTION 'Acceso directo a contratos permitido';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  EXECUTE 'SELECT count(*) FROM public.inv_vendedores_manual';
  RAISE EXCEPTION 'Acceso directo a vendedores manuales permitido';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  EXECUTE 'INSERT INTO public.inv_clientes(nombre) VALUES (''Intruso'')';
  RAISE EXCEPTION 'Insercion directa a clientes permitida';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
ROLLBACK;
BEGIN;
SET LOCAL ROLE anon;
DO $$
BEGIN
 BEGIN
  PERFORM count(*) FROM public.inv_catalogo_vendedores_manual();
  RAISE EXCEPTION 'Anonimo pudo ejecutar catalogo';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
  PERFORM count(*) FROM public.inv_clientes;
  RAISE EXCEPTION 'Anonimo pudo consultar clientes';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
END $$;
ROLLBACK;
\echo 'Roles PostgreSQL authenticated/anon, RPC y acceso directo: OK'
