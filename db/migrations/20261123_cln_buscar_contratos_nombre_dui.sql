-- CL Nexus: búsquedas de contratos por nombre, DUI o número, sin exponer UUID en la interfaz.
CREATE OR REPLACE FUNCTION public.inv_buscar_contratos(p_busqueda text)
RETURNS TABLE (
 id uuid, numero text, cliente_nombre text, dui_mostrado text,
 fecha date, estado text, prima_estado text, prima_monto numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
 v_q text := pg_catalog.btrim(COALESCE(p_busqueda,''));
 v_digits text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.inv_members m
   WHERE m.user_id = auth.uid() AND m.rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF pg_catalog.length(v_q) < 3 OR pg_catalog.length(v_q) > 100
 THEN RAISE EXCEPTION 'Escribí entre 3 y 100 caracteres'; END IF;
 v_digits := pg_catalog.regexp_replace(v_q,'[^0-9]','','g');
 RETURN QUERY
 SELECT c.id,c.numero,cl.nombre,
   CASE WHEN cl.dui IS NULL THEN 'Sin registrar' ELSE '*****'||pg_catalog.right(cl.dui,5) END,
   c.fecha,c.estado,
   COALESCE(pr.estado,'sin prima'),
   COALESCE(pr.monto,0)::numeric
 FROM public.inv_contratos c
 JOIN public.inv_clientes cl ON cl.id=c.cliente_id
 LEFT JOIN public.inv_contrato_primas pr ON pr.contrato_id=c.id
 WHERE pg_catalog.strpos(pg_catalog.lower(cl.nombre),pg_catalog.lower(v_q))>0
    OR (pg_catalog.length(v_digits)>=4
        AND pg_catalog.regexp_replace(cl.dui,'[^0-9]','','g') LIKE v_digits||'%')
    OR pg_catalog.strpos(pg_catalog.lower(c.numero),pg_catalog.lower(v_q))>0
 ORDER BY c.fecha DESC,c.numero DESC,c.id DESC
 LIMIT 60;
END
$function$;
REVOKE ALL ON FUNCTION public.inv_buscar_contratos(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.inv_buscar_contratos(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.inv_buscar_contratos(text) TO authenticated;