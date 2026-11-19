-- CL Nexus PRODUCTION STAGE 2: inventory-only Admin RPC and 3 approved existing admins.
-- No changes to Deudas gate, existing Auth, Vault, source tables or PWA.
-- Adds location metadata, does not insert merchandise or invent quantities.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $guard$ BEGIN
 IF (SELECT count(*) FROM auth.users)<>3 OR
    (SELECT count(*) FROM public.workspace_members)<>3 OR
    (SELECT count(*) FROM public.workspaces)<>1 OR
    (SELECT count(*) FROM public.debts)<>1 OR
    (SELECT md5(coalesce(string_agg(id||'='||data::text,'|' ORDER BY id),'')) FROM public.debts)<>'cae1aed74556ce96dde7f673e33d4668'
 THEN RAISE EXCEPTION 'Original Panel membership or Deudas fingerprint changed'; END IF;
 IF (SELECT count(*) FROM public.inv_members)<>0 OR
    (SELECT count(*) FROM public.inv_locations)<>0 OR
    (SELECT count(*) FROM public.inv_items)<>0 OR
    (SELECT count(*) FROM public.inv_stock)<>0
 THEN RAISE EXCEPTION 'Inventory stage 2 already applied or data exists'; END IF;
 IF to_regprocedure('public.inv_catalogo_articulos_admin()') IS NOT NULL OR
    to_regprocedure('public.inv_corregir_nombre_articulo(uuid,text,text)') IS NOT NULL
 THEN RAISE EXCEPTION 'Admin inventory RPCs already exist'; END IF;
END $guard$;
DO $preflight$ BEGIN
 IF to_regclass('public.inv_items') IS NULL
 OR to_regclass('public.inv_members') IS NULL
 OR to_regnamespace('inv_private') IS NULL
 THEN RAISE EXCEPTION 'CL Nexus inventory schema must exist before installing item rename'; END IF;
END $preflight$;
CREATE TABLE IF NOT EXISTS inv_private.cln_item_name_audit(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 item_id uuid NOT NULL REFERENCES public.inv_items(id),
 legacy_key text NOT NULL,
 previous_name text NOT NULL,
 new_name text NOT NULL,
 changed_by uuid NOT NULL REFERENCES auth.users(id),
 changed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE inv_private.cln_item_name_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE inv_private.cln_item_name_audit FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE inv_private.cln_item_name_audit_id_seq FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.inv_corregir_nombre_articulo(
 p_item_id uuid,p_nombre text,p_nombre_esperado text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $body$
DECLARE
 v_user uuid := auth.uid();
 v_current text;
 v_key text;
 v_clean text := pg_catalog.btrim(p_nombre);
BEGIN
 IF v_user IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.inv_members m
   WHERE m.user_id=v_user AND m.rol='admin'
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_item_id IS NULL OR p_nombre_esperado IS NULL
 OR v_clean IS NULL OR length(v_clean) NOT BETWEEN 2 AND 200
 OR v_clean ~ '[[:cntrl:]]'
 THEN RAISE EXCEPTION 'Nombre de artículo inválido'; END IF;
 SELECT nombre_original,legacy_key INTO v_current,v_key
 FROM public.inv_items
 WHERE id=p_item_id AND estado='activo'
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Artículo no disponible'; END IF;
 IF v_current IS DISTINCT FROM p_nombre_esperado
 THEN RAISE EXCEPTION 'El nombre cambió en otro dispositivo; actualiza el catálogo y reintenta'; END IF;
 IF v_current=v_clean THEN RETURN p_item_id; END IF;
 UPDATE public.inv_items SET nombre_original=v_clean WHERE id=p_item_id;
 INSERT INTO inv_private.cln_item_name_audit(
   item_id,legacy_key,previous_name,new_name,changed_by
 ) VALUES (p_item_id,coalesce(v_key,''),v_current,v_clean,v_user);
 RETURN p_item_id;
END $body$;
REVOKE ALL ON FUNCTION public.inv_corregir_nombre_articulo(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inv_corregir_nombre_articulo(uuid,text,text) TO authenticated;
-- Secure catalog includes stable MERCADERIA code and separates unregistered stock from zero.
CREATE OR REPLACE FUNCTION public.inv_catalogo_articulos_admin()
RETURNS TABLE(id uuid,nombre text,categoria text,codigo text,oficina integer,bodega integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $catalog$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
   SELECT 1 FROM public.inv_members m
   WHERE m.user_id=auth.uid() AND m.rol='admin'
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 RETURN QUERY
 SELECT i.id,i.nombre_original,i.categoria,i.legacy_key,
        o.cantidad,b.cantidad
 FROM public.inv_items i
 LEFT JOIN public.inv_stock o ON o.item_id=i.id AND o.location_id=1
 LEFT JOIN public.inv_stock b ON b.item_id=i.id AND b.location_id=2
 WHERE i.estado='activo'
 ORDER BY i.nombre_original,i.legacy_key,i.id
 LIMIT 2000;
END $catalog$;
REVOKE ALL ON FUNCTION public.inv_catalogo_articulos_admin() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inv_catalogo_articulos_admin() TO authenticated;
INSERT INTO public.inv_locations(id,nombre)
 VALUES (1,'Oficina'),(2,'Bodega'),(3,'Garantía'),(4,'Proveedor/Taller');
INSERT INTO public.inv_members(user_id,rol)
 SELECT wm.user_id,'admin'
 FROM public.workspace_members wm
 JOIN auth.users u ON u.id=wm.user_id
 WHERE wm.workspace_id=(SELECT id FROM public.workspaces)
 ORDER BY wm.user_id;
DO $verify$
BEGIN
 IF (SELECT count(*) FROM public.inv_members)<>3 OR
    (SELECT count(*) FROM public.inv_members WHERE rol='admin')<>3 OR
    (SELECT count(*) FROM public.inv_locations)<>4 OR
    (SELECT count(*) FROM public.inv_items)<>0 OR
    (SELECT count(*) FROM public.inv_stock)<>0 OR
    (SELECT count(*) FROM public.debts)<>1
 THEN RAISE EXCEPTION 'CL Nexus stage 2 verification failed'; END IF;
 IF EXISTS(SELECT user_id FROM public.inv_members
           EXCEPT SELECT user_id FROM public.workspace_members)
 THEN RAISE EXCEPTION 'Admin mappings include outsider'; END IF;
END $verify$;
COMMIT;
