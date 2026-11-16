-- FASE 15AE: registro MANUAL de vendedores para la nueva sección.
-- PREPARADO, NO APLICADO. Solo ejecutar en PostgreSQL aislado con autorización.
-- No importa nombres de inv_items ni modifica inv_vendedores histórico.
BEGIN;
CREATE TABLE IF NOT EXISTS public.inv_vendedores_manual (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 nombre text NOT NULL CHECK (length(pg_catalog.btrim(nombre)) BETWEEN 2 AND 200),
 activo boolean NOT NULL DEFAULT true,
 creado_por uuid NOT NULL DEFAULT auth.uid(),
 creado_en timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.inv_vendedores_manual ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.inv_vendedores_manual FROM anon,authenticated;

CREATE OR REPLACE FUNCTION public.inv_catalogo_vendedores_manual()
RETURNS TABLE(id uuid,nombre text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.inv_members m
   WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 RETURN QUERY SELECT v.id,v.nombre FROM public.inv_vendedores_manual v
 WHERE v.activo=true ORDER BY v.nombre,v.id LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.inv_crear_vendedor_manual(p_nombre text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.inv_members m
   WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_nombre IS NULL OR length(pg_catalog.btrim(p_nombre)) NOT BETWEEN 2 AND 200
 THEN RAISE EXCEPTION 'Nombre de vendedor inválido'; END IF;
 INSERT INTO public.inv_vendedores_manual(nombre,creado_por)
 VALUES(pg_catalog.btrim(p_nombre),auth.uid()) RETURNING id INTO v_id;
 RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.inv_catalogo_vendedores_manual() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_crear_vendedor_manual(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inv_catalogo_vendedores_manual() TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_crear_vendedor_manual(text) TO authenticated;
COMMIT;
