-- FASE 15N: catálogos de solo lectura y ficha protegida de cliente.
-- Requiere 15I. Ejecutar únicamente después de validar migraciones previas en staging.
BEGIN;
CREATE OR REPLACE FUNCTION public.inv_catalogo_vendedores()
RETURNS TABLE(id uuid,nombre text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 RETURN QUERY SELECT v.id,v.nombre FROM public.inv_vendedores v WHERE v.activo=true ORDER BY v.nombre LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.inv_catalogo_articulos_contratos()
RETURNS TABLE(id uuid,nombre text,categoria text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 RETURN QUERY SELECT i.id,i.nombre_original,i.categoria FROM public.inv_items i
 WHERE i.estado='activo' ORDER BY i.nombre_original LIMIT 2000;
END $$;

CREATE OR REPLACE FUNCTION public.inv_ficha_cliente(p_cliente_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_ficha jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 SELECT pg_catalog.jsonb_build_object(
 'id',c.id,'nombre',c.nombre,'dui',c.dui,'direccion',c.direccion,
 'ubicacion',c.ubicacion,'telefono',c.telefono,'vivienda',c.vivienda,
 'lugar_trabajo',c.lugar_trabajo,'telefono_trabajo',c.telefono_trabajo,
 'referencias',COALESCE((
  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'orden',r.orden,'nombre',r.nombre,'telefono',r.telefono,
    'direccion',r.direccion,'parentesco',r.parentesco
  ) ORDER BY r.orden)
  FROM public.inv_cliente_referencias r WHERE r.cliente_id=c.id
 ),'[]'::jsonb)
 ) INTO v_ficha
 FROM public.inv_clientes c WHERE c.id=p_cliente_id;
 IF v_ficha IS NULL THEN RAISE EXCEPTION 'Cliente no encontrado'; END IF;
 RETURN v_ficha;
END $$;

REVOKE ALL ON FUNCTION public.inv_catalogo_vendedores() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_catalogo_articulos_contratos() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_ficha_cliente(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inv_catalogo_vendedores() TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_catalogo_articulos_contratos() TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_ficha_cliente(uuid) TO authenticated;
COMMIT;
