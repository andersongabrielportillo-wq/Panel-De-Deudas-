-- CL Nexus: ajustes manuales auditados + historial de acceso por módulo.
-- No cambia los datos previos ni relaja bloqueos de Garantía/Proveedor.
CREATE TABLE IF NOT EXISTS public.inv_stock_adjustments (
 id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
 client_op_id uuid NOT NULL UNIQUE,
 item_id uuid NOT NULL REFERENCES public.inv_items(id) ON DELETE RESTRICT,
 location_id smallint NOT NULL REFERENCES public.inv_locations(id),
 anterior integer,
 nueva integer NOT NULL CHECK (nueva BETWEEN 0 AND 100000000),
 motivo text NOT NULL CHECK (length(pg_catalog.btrim(motivo)) BETWEEN 5 AND 500),
 usuario uuid NOT NULL REFERENCES auth.users(id),
 registrado_en timestamptz NOT NULL DEFAULT pg_catalog.now(),
 CONSTRAINT inv_stock_adjustments_location CHECK (location_id IN (1,2)),
 CONSTRAINT inv_stock_adjustments_anterior CHECK (anterior IS NULL OR anterior >= 0)
);
ALTER TABLE public.inv_stock_adjustments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.inv_stock_adjustments FROM PUBLIC, anon, authenticated;
CREATE INDEX IF NOT EXISTS idx_inv_stock_adjustments_item_date ON public.inv_stock_adjustments(item_id,registrado_en DESC);

CREATE TABLE IF NOT EXISTS public.cln_module_use (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 modulo text NOT NULL CHECK (modulo IN ('inventario','ventas','contratos','vendedores','garantias','deudas')),
 evento text NOT NULL DEFAULT 'acceso' CHECK (evento IN ('acceso','ajuste')),
 detalle text NOT NULL DEFAULT '' CHECK (length(detalle) <= 500),
 usuario uuid NOT NULL REFERENCES auth.users(id),
 registrado_en timestamptz NOT NULL DEFAULT pg_catalog.now()
);
ALTER TABLE public.cln_module_use ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.cln_module_use FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.cln_module_use_id_seq FROM PUBLIC, anon, authenticated;
CREATE INDEX IF NOT EXISTS idx_cln_module_use_module_order ON public.cln_module_use(modulo,id DESC);

CREATE OR REPLACE FUNCTION public.cln_registrar_uso_modulo(p_modulo text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_id bigint; v_user uuid := auth.uid();
BEGIN
 IF v_user IS NULL OR p_modulo NOT IN ('inventario','ventas','contratos','vendedores','garantias','deudas')
    OR p_modulo IS NULL THEN RAISE EXCEPTION 'Acceso a módulo inválido'; END IF;
 IF p_modulo='deudas' THEN
  IF NOT EXISTS (SELECT 1 FROM public.workspace_members WHERE user_id=v_user)
     OR NOT public.has_debts_unlock()
  THEN RAISE EXCEPTION 'Se necesita desbloquear Deudas'; END IF;
 ELSE
  IF NOT EXISTS (SELECT 1 FROM public.inv_members WHERE user_id=v_user AND rol IN ('admin','secretaria'))
  THEN RAISE EXCEPTION 'Acceso a módulo no autorizado'; END IF;
 END IF;
 INSERT INTO public.cln_module_use(modulo,evento,detalle,usuario)
 VALUES(p_modulo,'acceso','',v_user) RETURNING id INTO v_id;
 RETURN v_id;
END $fn$;
REVOKE ALL ON FUNCTION public.cln_registrar_uso_modulo(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cln_registrar_uso_modulo(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.cln_historial_modulo(p_modulo text,p_antes_id bigint DEFAULT NULL)
RETURNS TABLE(id bigint,fecha_hora timestamptz,evento text,detalle text,rol text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_user uuid := auth.uid();
BEGIN
 IF v_user IS NULL OR p_modulo IS NULL OR p_modulo NOT IN
    ('inventario','ventas','contratos','vendedores','garantias','deudas')
 THEN RAISE EXCEPTION 'Módulo inválido'; END IF;
 IF p_modulo='deudas' THEN
  IF NOT EXISTS (SELECT 1 FROM public.workspace_members WHERE user_id=v_user)
     OR NOT public.has_debts_unlock()
  THEN RAISE EXCEPTION 'Se necesita desbloquear Deudas'; END IF;
 ELSE
  IF NOT EXISTS (SELECT 1 FROM public.inv_members WHERE user_id=v_user AND rol IN ('admin','secretaria'))
  THEN RAISE EXCEPTION 'No autorizado'; END IF;
 END IF;
 IF p_antes_id IS NOT NULL AND p_antes_id < 1 THEN RAISE EXCEPTION 'Paginación inválida'; END IF;
 RETURN QUERY
 SELECT a.id,a.registrado_en,a.evento,a.detalle,COALESCE(m.rol,'cuenta autorizada') AS rol
 FROM public.cln_module_use a
 LEFT JOIN public.inv_members m ON m.user_id=a.usuario
 WHERE a.modulo=p_modulo AND (p_antes_id IS NULL OR a.id<p_antes_id)
 ORDER BY a.id DESC LIMIT 80;
END $fn$;
REVOKE ALL ON FUNCTION public.cln_historial_modulo(text,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cln_historial_modulo(text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.inv_ajustar_existencia(
 p_item_id uuid,p_location_id smallint,p_nueva integer,
 p_esperado integer,p_motivo text,p_client_op_id uuid
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE
 v_user uuid := auth.uid();
 v_actual integer; v_exists boolean;
 v_prev public.inv_stock_adjustments%ROWTYPE;
 v_item_name text; v_id uuid;
BEGIN
 IF v_user IS NULL OR NOT EXISTS
  (SELECT 1 FROM public.inv_members WHERE user_id=v_user AND rol IN ('admin','secretaria'))
 THEN RAISE EXCEPTION 'No autorizado para editar inventario'; END IF;
 IF p_client_op_id IS NULL OR p_item_id IS NULL OR p_location_id NOT IN (1,2) OR p_location_id IS NULL
    OR p_nueva IS NULL OR p_nueva < 0 OR p_nueva > 100000000
    OR (p_esperado IS NOT NULL AND (p_esperado<0 OR p_esperado>100000000))
    OR length(pg_catalog.btrim(COALESCE(p_motivo,''))) NOT BETWEEN 5 AND 500
 THEN RAISE EXCEPTION 'Datos del ajuste inválidos'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_client_op_id::text,81231));
 SELECT * INTO v_prev FROM public.inv_stock_adjustments WHERE client_op_id=p_client_op_id;
 IF FOUND THEN
  IF v_prev.item_id IS NOT DISTINCT FROM p_item_id
   AND v_prev.location_id=p_location_id AND v_prev.nueva=p_nueva
   AND v_prev.anterior IS NOT DISTINCT FROM p_esperado
   AND v_prev.motivo=pg_catalog.btrim(p_motivo) AND v_prev.usuario=v_user
  THEN RETURN v_prev.id;
  ELSE RAISE EXCEPTION 'Identificador de ajuste reutilizado con datos diferentes'; END IF;
 END IF;
 SELECT i.nombre_original INTO v_item_name
 FROM public.inv_items i WHERE i.id=p_item_id AND i.estado='activo' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Artículo no disponible'; END IF;
 SELECT s.cantidad INTO v_actual FROM public.inv_stock s
 WHERE s.item_id=p_item_id AND s.location_id=p_location_id FOR UPDATE;
 v_exists:=FOUND;
 IF (CASE WHEN v_exists THEN v_actual ELSE NULL END) IS DISTINCT FROM p_esperado
 THEN RAISE EXCEPTION 'La cantidad cambió desde la consulta: recarga Inventario y verifica'; END IF;
 IF v_exists AND v_actual=p_nueva THEN RAISE EXCEPTION 'La cantidad ya es igual; no hay cambio'; END IF;
 IF v_exists THEN
  UPDATE public.inv_stock SET cantidad=p_nueva WHERE item_id=p_item_id AND location_id=p_location_id;
 ELSE
  INSERT INTO public.inv_stock(item_id,location_id,cantidad) VALUES(p_item_id,p_location_id,p_nueva);
 END IF;
 INSERT INTO public.inv_stock_adjustments(client_op_id,item_id,location_id,anterior,nueva,motivo,usuario)
 VALUES(p_client_op_id,p_item_id,p_location_id,(CASE WHEN v_exists THEN v_actual ELSE NULL END),p_nueva,pg_catalog.btrim(p_motivo),v_user)
 RETURNING id INTO v_id;
 INSERT INTO public.cln_module_use(modulo,evento,detalle,usuario)
 VALUES('inventario','ajuste',pg_catalog.left(
  v_item_name || ' · ' || (CASE WHEN p_location_id=1 THEN 'Oficina' ELSE 'Bodega' END)
  || ': ' || COALESCE(v_actual::text,'Sin registrar') || ' → ' || p_nueva::text
  || ' · Motivo: ' || pg_catalog.btrim(p_motivo),500),v_user);
 RETURN v_id;
END $fn$;
REVOKE ALL ON FUNCTION public.inv_ajustar_existencia(uuid,smallint,integer,integer,text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv_ajustar_existencia(uuid,smallint,integer,integer,text,uuid) TO authenticated;

-- Inventario visible para los dos roles operativos; sin otorgar escritura directa a la tabla.
CREATE OR REPLACE FUNCTION public.inv_catalogo_articulos_admin()
RETURNS TABLE(id uuid,nombre text,categoria text,codigo text,oficina integer,bodega integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
  SELECT 1 FROM public.inv_members m
  WHERE m.user_id=auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 RETURN QUERY
 SELECT i.id,i.nombre_original,i.categoria,i.legacy_key,o.cantidad,b.cantidad
 FROM public.inv_items i
 LEFT JOIN public.inv_stock o ON o.item_id=i.id AND o.location_id=1
 LEFT JOIN public.inv_stock b ON b.item_id=i.id AND b.location_id=2
 WHERE i.estado='activo'
 ORDER BY i.nombre_original,i.legacy_key,i.id
 LIMIT 2000;
END $fn$;
REVOKE ALL ON FUNCTION public.inv_catalogo_articulos_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv_catalogo_articulos_admin() TO authenticated;
