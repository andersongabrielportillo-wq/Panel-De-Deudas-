-- CL Nexus: ADD-ON FOR APPROVED CLONE CUTOVER ONLY. NO PRODUCTION EXECUTION.
-- Inventory item names can be corrected from the PWA without touching stock or Deudas.
-- Changes have an immutable original legacy key and a private audit trail.
-- This file is NOT a license to execute before authentic Auth/Vault recovery.
BEGIN;
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
COMMIT;
