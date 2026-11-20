-- CL Nexus: listado seguro de solicitudes pendientes para aprobar/rechazar sin escribir UUID.
-- Es un RPC de solo lectura: no modifica stock ni crea entradas.
CREATE OR REPLACE FUNCTION public.inv_solicitudes_entrada_pendientes()
RETURNS TABLE(
  id uuid,
  nombre text,
  cantidad integer,
  ubicacion text,
  creado_en timestamptz,
  observaciones text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.inv_members AS m
    WHERE m.user_id = auth.uid()
      AND m.rol IN ('admin','secretaria')
  ) THEN
    RAISE EXCEPTION 'No autorizado para consultar solicitudes de entrada';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    i.nombre_original AS nombre,
    r.cantidad,
    l.nombre AS ubicacion,
    r.creado_en,
    r.observaciones
  FROM public.inv_entry_requests AS r
  INNER JOIN public.inv_items AS i ON i.id = r.item_id
  INNER JOIN public.inv_locations AS l ON l.id = r.location_id
  WHERE r.estado = 'pendiente'
  ORDER BY r.creado_en ASC, r.id ASC
  LIMIT 500;
END;
$function$;
REVOKE ALL ON FUNCTION public.inv_solicitudes_entrada_pendientes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inv_solicitudes_entrada_pendientes() TO authenticated;
