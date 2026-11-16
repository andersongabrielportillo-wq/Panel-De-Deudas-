-- FASE 15J. Requiere aplicar primero 20261115_fase15i_contratos_base.sql.
-- NO APLICAR en producción. Ejecutar pruebas con JWT de usuario en entorno aislado.
BEGIN;

CREATE OR REPLACE FUNCTION public.inv_buscar_clientes(p_busqueda text)
RETURNS TABLE(id uuid,nombre text,dui_mostrado text,telefono text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_q text := pg_catalog.btrim(coalesce(p_busqueda,'')); v_digits text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF length(v_q)<3 OR length(v_q)>100 THEN RAISE EXCEPTION 'Escribe al menos 3 caracteres'; END IF;
 v_digits:=pg_catalog.regexp_replace(v_q,'[^0-9]','','g');
 RETURN QUERY SELECT c.id,c.nombre,
   CASE WHEN c.dui IS NULL THEN NULL ELSE '*****'||right(c.dui,5) END,
   c.telefono
 FROM public.inv_clientes c
 WHERE lower(c.nombre) LIKE '%'||lower(v_q)||'%'
    OR (length(v_digits)>=4 AND pg_catalog.regexp_replace(c.dui,'[^0-9]','','g') LIKE v_digits||'%')
 ORDER BY c.nombre,c.id LIMIT 30;
END $$;

CREATE OR REPLACE FUNCTION public.inv_crear_cliente(
 p_nombre text,p_dui text DEFAULT NULL,p_direccion text DEFAULT NULL,
 p_ubicacion text DEFAULT NULL,p_telefono text DEFAULT NULL,
 p_vivienda text DEFAULT NULL,p_lugar_trabajo text DEFAULT NULL,
 p_telefono_trabajo text DEFAULT NULL,p_referencias jsonb DEFAULT '[]'::jsonb
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_id uuid; v_dui text; v_ref jsonb; v_n int:=0;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
   SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF length(pg_catalog.btrim(coalesce(p_nombre,''))) NOT BETWEEN 2 AND 200 THEN RAISE EXCEPTION 'Nombre inválido'; END IF;
 v_dui:=NULLIF(pg_catalog.regexp_replace(coalesce(p_dui,''),'[^0-9]','','g'),'');
 IF v_dui IS NOT NULL THEN
   IF length(v_dui)<>9 THEN RAISE EXCEPTION 'DUI inválido'; END IF;
   v_dui:=left(v_dui,8)||'-'||right(v_dui,1);
 END IF;
 IF p_vivienda IS NOT NULL AND p_vivienda NOT IN ('alquila','propia') THEN RAISE EXCEPTION 'Vivienda inválida'; END IF;
 IF p_referencias IS NULL OR pg_catalog.jsonb_typeof(p_referencias)<>'array' OR pg_catalog.jsonb_array_length(p_referencias)>2
 THEN RAISE EXCEPTION 'Se admiten hasta dos referencias'; END IF;
 INSERT INTO public.inv_clientes(nombre,dui,direccion,ubicacion,telefono,vivienda,lugar_trabajo,telefono_trabajo)
 VALUES(pg_catalog.btrim(p_nombre),v_dui,NULLIF(pg_catalog.btrim(p_direccion),''),
 NULLIF(pg_catalog.btrim(p_ubicacion),''),NULLIF(pg_catalog.btrim(p_telefono),''),
 p_vivienda,NULLIF(pg_catalog.btrim(p_lugar_trabajo),''),NULLIF(pg_catalog.btrim(p_telefono_trabajo),''))
 RETURNING id INTO v_id;
 FOR v_ref IN SELECT value FROM pg_catalog.jsonb_array_elements(p_referencias) LOOP
   v_n:=v_n+1;
   IF pg_catalog.jsonb_typeof(v_ref)<>'object' OR length(pg_catalog.btrim(coalesce(v_ref->>'nombre','')))<2
   THEN RAISE EXCEPTION 'Referencia % inválida',v_n; END IF;
   INSERT INTO public.inv_cliente_referencias(cliente_id,orden,nombre,telefono,direccion,parentesco)
   VALUES(v_id,v_n,pg_catalog.btrim(v_ref->>'nombre'),v_ref->>'telefono',v_ref->>'direccion',v_ref->>'parentesco');
 END LOOP;
 RETURN v_id;
EXCEPTION WHEN unique_violation THEN
 RAISE EXCEPTION 'Ya existe un cliente con ese DUI';
END $$;

CREATE OR REPLACE FUNCTION public.inv_crear_contrato_borrador(
 p_numero text,p_cliente_id uuid,p_vendedor_id uuid,p_fecha date,
 p_modalidad text,p_frecuencia text,p_plan text,p_cuota numeric,
 p_saldo_inicial numeric,p_fecha_plan date,p_ruta text,p_dia_cobro text,
 p_receptor_alterno text,p_comision numeric,p_prima numeric,p_prima_recibida boolean,
 p_detalles jsonb,p_observaciones text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_id uuid;v_line jsonb;v_item uuid;v_cantidad int;v_precio numeric;v_comision numeric;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF length(pg_catalog.btrim(coalesce(p_numero,''))) NOT BETWEEN 1 AND 80
 OR p_cliente_id IS NULL OR p_vendedor_id IS NULL OR p_fecha IS NULL
 THEN RAISE EXCEPTION 'Datos principales incompletos'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.inv_clientes WHERE id=p_cliente_id)
 OR NOT EXISTS(SELECT 1 FROM public.inv_vendedores WHERE id=p_vendedor_id AND activo=true)
 THEN RAISE EXCEPTION 'Cliente o vendedor inválido'; END IF;
 IF p_modalidad NOT IN ('credito','contado') OR p_modalidad IS NULL
 OR p_plan NOT IN ('normal','3_pagos','6_pagos') OR p_plan IS NULL
 OR (p_frecuencia IS NOT NULL AND p_frecuencia NOT IN ('semanal','quincenal','mensual'))
 THEN RAISE EXCEPTION 'Modalidad o plan inválido'; END IF;
 IF p_comision IS NULL OR p_comision<0 OR p_prima IS NULL OR p_prima<0
 OR p_comision>999999999999.99 OR p_prima>999999999999.99
 OR p_comision<>pg_catalog.round(p_comision,2) OR p_prima<>pg_catalog.round(p_prima,2)
 OR p_prima_recibida IS NULL
 THEN RAISE EXCEPTION 'Comisión o prima inválida'; END IF;
 IF (p_cuota IS NOT NULL AND (p_cuota<0 OR p_cuota>999999999999.99 OR p_cuota<>pg_catalog.round(p_cuota,2)))
 OR (p_saldo_inicial IS NOT NULL AND (p_saldo_inicial<0 OR p_saldo_inicial>999999999999.99 OR p_saldo_inicial<>pg_catalog.round(p_saldo_inicial,2)))
 THEN RAISE EXCEPTION 'Cuota o saldo inicial inválido'; END IF;
 IF p_detalles IS NULL OR pg_catalog.jsonb_typeof(p_detalles)<>'array'
 OR pg_catalog.jsonb_array_length(p_detalles) NOT BETWEEN 1 AND 100
 THEN RAISE EXCEPTION 'Agrega entre 1 y 100 líneas'; END IF;
 INSERT INTO public.inv_contratos(numero,cliente_id,vendedor_id,fecha,modalidad,frecuencia,plan,cuota,saldo_inicial,
 fecha_plan,ruta,dia_cobro,receptor_alterno,comision_total,observaciones)
 VALUES(pg_catalog.btrim(p_numero),p_cliente_id,p_vendedor_id,p_fecha,p_modalidad,p_frecuencia,p_plan,p_cuota,p_saldo_inicial,
 p_fecha_plan,p_ruta,p_dia_cobro,p_receptor_alterno,p_comision,p_observaciones) RETURNING id INTO v_id;
 FOR v_line IN SELECT value FROM pg_catalog.jsonb_array_elements(p_detalles) LOOP
   IF pg_catalog.jsonb_typeof(v_line)<>'object' THEN RAISE EXCEPTION 'Línea inválida'; END IF;
   v_item:=(v_line->>'item_id')::uuid;
   IF (v_line->>'cantidad') IS NULL OR (v_line->>'cantidad') !~ '^[1-9][0-9]*
   v_precio:=(v_line->>'precio_credito_unitario')::numeric;
   v_comision:=coalesce((v_line->>'comision_linea')::numeric,0);
   IF v_item IS NULL OR NOT EXISTS(SELECT 1 FROM public.inv_items WHERE id=v_item AND estado='activo')
   OR v_cantidad IS NULL OR v_cantidad<=0 OR v_precio IS NULL OR v_precio<0
   OR v_comision<0 OR v_precio>999999999999.99 OR v_comision>999999999999.99
   OR v_precio<>pg_catalog.round(v_precio,2) OR v_comision<>pg_catalog.round(v_comision,2)
   THEN RAISE EXCEPTION 'Artículo, cantidad o importe inválido'; END IF;
   INSERT INTO public.inv_contrato_detalles(contrato_id,item_id,cantidad,precio_credito_unitario,comision_linea)
   VALUES(v_id,v_item,v_cantidad,v_precio,v_comision);
 END LOOP;
 INSERT INTO public.inv_contrato_primas(contrato_id,monto,estado,fecha_recibida,registrado_por)
 VALUES(v_id,p_prima,CASE WHEN p_prima_recibida THEN 'recibida' ELSE 'pendiente' END,
 CASE WHEN p_prima_recibida THEN now() ELSE NULL END,auth.uid());
 INSERT INTO public.inv_prima_eventos(prima_id,estado_anterior,estado_nuevo,usuario,observaciones)
 SELECT id,NULL,estado,auth.uid(),'Registro inicial de prima'
 FROM public.inv_contrato_primas WHERE contrato_id=v_id;
 RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.inv_marcar_prima_recibida(p_contrato_id uuid,p_observaciones text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_prima uuid;v_estado text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF NULLIF(pg_catalog.btrim(coalesce(p_observaciones,'')),'') IS NULL THEN RAISE EXCEPTION 'Indica cómo se entregó la prima'; END IF;
 SELECT id,estado INTO v_prima,v_estado FROM public.inv_contrato_primas
 WHERE contrato_id=p_contrato_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Prima no encontrada'; END IF;
 IF v_estado='recibida' THEN RAISE EXCEPTION 'La prima ya fue registrada como recibida'; END IF;
 UPDATE public.inv_contrato_primas SET estado='recibida',fecha_recibida=now(),actualizado_en=now() WHERE id=v_prima;
 INSERT INTO public.inv_prima_eventos(prima_id,estado_anterior,estado_nuevo,usuario,observaciones)
 VALUES(v_prima,'pendiente','recibida',auth.uid(),pg_catalog.btrim(p_observaciones));
 RETURN true;
END $$;

REVOKE ALL ON FUNCTION public.inv_buscar_clientes(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_crear_cliente(text,text,text,text,text,text,text,text,jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_crear_contrato_borrador(text,uuid,uuid,date,text,text,text,numeric,numeric,date,text,text,text,numeric,numeric,boolean,jsonb,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_marcar_prima_recibida(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inv_buscar_clientes(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_crear_cliente(text,text,text,text,text,text,text,text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_crear_contrato_borrador(text,uuid,uuid,date,text,text,text,numeric,numeric,date,text,text,text,numeric,numeric,boolean,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_marcar_prima_recibida(uuid,text) TO authenticated;
COMMIT;
 THEN
     RAISE EXCEPTION 'Cantidad debe ser un entero positivo';
   END IF;
   v_cantidad:=(v_line->>'cantidad')::integer;
   v_precio:=(v_line->>'precio_credito_unitario')::numeric;
   v_comision:=coalesce((v_line->>'comision_linea')::numeric,0);
   IF v_item IS NULL OR NOT EXISTS(SELECT 1 FROM public.inv_items WHERE id=v_item AND estado='activo')
   OR v_cantidad IS NULL OR v_cantidad<=0 OR v_precio IS NULL OR v_precio<0
   OR v_comision<0 OR v_precio>999999999999.99 OR v_comision>999999999999.99
   OR v_precio<>pg_catalog.round(v_precio,2) OR v_comision<>pg_catalog.round(v_comision,2)
   THEN RAISE EXCEPTION 'Artículo, cantidad o importe inválido'; END IF;
   INSERT INTO public.inv_contrato_detalles(contrato_id,item_id,cantidad,precio_credito_unitario,comision_linea)
   VALUES(v_id,v_item,v_cantidad,v_precio,v_comision);
 END LOOP;
 INSERT INTO public.inv_contrato_primas(contrato_id,monto,estado,fecha_recibida,registrado_por)
 VALUES(v_id,p_prima,CASE WHEN p_prima_recibida THEN 'recibida' ELSE 'pendiente' END,
 CASE WHEN p_prima_recibida THEN now() ELSE NULL END,auth.uid());
 INSERT INTO public.inv_prima_eventos(prima_id,estado_anterior,estado_nuevo,usuario,observaciones)
 SELECT id,NULL,estado,auth.uid(),'Registro inicial de prima'
 FROM public.inv_contrato_primas WHERE contrato_id=v_id;
 RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.inv_marcar_prima_recibida(p_contrato_id uuid,p_observaciones text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_prima uuid;v_estado text;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
 SELECT 1 FROM public.inv_members WHERE user_id=auth.uid() AND rol IN ('admin','secretaria')
 ) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF NULLIF(pg_catalog.btrim(coalesce(p_observaciones,'')),'') IS NULL THEN RAISE EXCEPTION 'Indica cómo se entregó la prima'; END IF;
 SELECT id,estado INTO v_prima,v_estado FROM public.inv_contrato_primas
 WHERE contrato_id=p_contrato_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Prima no encontrada'; END IF;
 IF v_estado='recibida' THEN RAISE EXCEPTION 'La prima ya fue registrada como recibida'; END IF;
 UPDATE public.inv_contrato_primas SET estado='recibida',fecha_recibida=now(),actualizado_en=now() WHERE id=v_prima;
 INSERT INTO public.inv_prima_eventos(prima_id,estado_anterior,estado_nuevo,usuario,observaciones)
 VALUES(v_prima,'pendiente','recibida',auth.uid(),pg_catalog.btrim(p_observaciones));
 RETURN true;
END $$;

REVOKE ALL ON FUNCTION public.inv_buscar_clientes(text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_crear_cliente(text,text,text,text,text,text,text,text,jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_crear_contrato_borrador(text,uuid,uuid,date,text,text,text,numeric,numeric,date,text,text,text,numeric,numeric,boolean,jsonb,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.inv_marcar_prima_recibida(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.inv_buscar_clientes(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_crear_cliente(text,text,text,text,text,text,text,text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_crear_contrato_borrador(text,uuid,uuid,date,text,text,text,numeric,numeric,date,text,text,text,numeric,numeric,boolean,jsonb,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.inv_marcar_prima_recibida(uuid,text) TO authenticated;
COMMIT;
