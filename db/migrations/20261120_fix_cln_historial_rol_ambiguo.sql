-- Hotfix 2026-11-20: evita conflicto entre la columna "rol" y el parámetro
-- de salida RETURNS TABLE(rol text) en las funciones PL/pgSQL.
-- No borra ni modifica registros previos de historial.
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
  IF NOT EXISTS (SELECT 1 FROM public.workspace_members wm WHERE wm.user_id=v_user)
     OR NOT public.has_debts_unlock()
  THEN RAISE EXCEPTION 'Se necesita desbloquear Deudas'; END IF;
 ELSE
  IF NOT EXISTS (SELECT 1 FROM public.inv_members m WHERE m.user_id=v_user AND m.rol IN ('admin','secretaria'))
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
