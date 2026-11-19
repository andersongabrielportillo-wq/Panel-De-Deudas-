\set ON_ERROR_STOP on
-- Integracion REAL de RPC de vendedores sobre PostgreSQL temporal.
-- El modulo de ventas de esta fixture sigue siendo ficticio: NO certifica stock.
DO $$
DECLARE
 admin_id uuid:='11111111-1111-4111-8111-111111111111';
 secretaria_id uuid:='22222222-2222-4222-8222-222222222222';
 empleado_id uuid:='33333333-3333-4333-8333-333333333333';
 vendedor_id uuid;
 n int;
BEGIN
 INSERT INTO public.inv_members(user_id,rol) VALUES
 (admin_id,'admin'),(secretaria_id,'secretaria'),(empleado_id,'empleado');
 INSERT INTO public.inv_vendedores(nombre) VALUES ('Vendedor historico ficticio');
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',admin_id::text,true);
 SELECT count(*) INTO n FROM public.inv_catalogo_vendedores_manual();
 IF n<>0 THEN RAISE EXCEPTION 'Catalogo manual no comienza vacio'; END IF;
 vendedor_id:=public.inv_crear_vendedor_manual('Vendedor ficticio nuevo');
 IF NOT EXISTS(SELECT 1 FROM public.inv_vendedores v JOIN public.inv_vendedores_manual vm ON vm.id=v.id
 WHERE v.id=vendedor_id AND v.nombre='Vendedor ficticio nuevo' AND vm.nombre=v.nombre)
 THEN RAISE EXCEPTION 'Alta dual de vendedor no fue atomica'; END IF;
 SELECT count(*) INTO n FROM public.inv_catalogo_vendedores_manual();
 IF n<>1 THEN RAISE EXCEPTION 'El catalogo manual incluyo vendedor historico'; END IF;
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',secretaria_id::text,true);
 SELECT count(*) INTO n FROM public.inv_catalogo_vendedores_manual();
 IF n<>1 THEN RAISE EXCEPTION 'Secretaria no puede consultar vendedores'; END IF;
 BEGIN
  PERFORM public.inv_crear_vendedor_manual('No permitido');
  RAISE EXCEPTION 'Secretaria pudo crear vendedor';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'No autorizado' THEN RAISE; END IF;
 END;
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',empleado_id::text,true);
 BEGIN
  PERFORM count(*) FROM public.inv_catalogo_vendedores_manual();
  RAISE EXCEPTION 'Empleado pudo consultar catalogo';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'No autorizado' THEN RAISE; END IF;
 END;
 PERFORM pg_catalog.set_config('request.jwt.claim.sub','',true);
 BEGIN
  PERFORM count(*) FROM public.inv_catalogo_vendedores_manual();
  RAISE EXCEPTION 'Anonimo pudo consultar catalogo';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'No autorizado' THEN RAISE; END IF;
 END;
END $$;
\echo 'Integracion de vendedores manuales y roles: OK'
