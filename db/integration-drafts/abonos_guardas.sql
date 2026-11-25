-- Deploy after payroll and contract migrations.
CREATE FUNCTION cln_admin_internal.registrar_abono(p_contrato uuid,p_op uuid,p_monto numeric,p_fecha date,p_cobrador text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_user uuid:=auth.uid(); v_contract public.inv_contratos%ROWTYPE;
 v_sale public.inv_ventas%ROWTYPE; v_existing public.cln_route_payments%ROWTYPE;
 v_paid numeric; v_prima numeric; v_id uuid;
BEGIN
 IF v_user IS NULL OR NOT EXISTS(SELECT 1 FROM public.inv_members m WHERE m.user_id=v_user AND m.rol IN ('admin','secretaria')) THEN RAISE EXCEPTION 'No autorizado'; END IF;
 IF p_contrato IS NULL OR p_op IS NULL OR p_monto IS NULL OR p_monto<=0 OR p_monto>999999999999.99 OR round(p_monto,2)<>p_monto OR p_fecha IS NULL OR length(trim(coalesce(p_cobrador,''))) NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION 'Abono inválido'; END IF;
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_op::text,1));
 SELECT * INTO v_existing FROM public.cln_route_payments WHERE op_id=p_op;
 IF FOUND THEN
  IF v_existing.contrato_id IS DISTINCT FROM p_contrato OR v_existing.monto IS DISTINCT FROM p_monto OR v_existing.fecha IS DISTINCT FROM p_fecha OR v_existing.cobrador IS DISTINCT FROM trim(p_cobrador) OR v_existing.registrado_por IS DISTINCT FROM v_user THEN RAISE EXCEPTION 'Operación ya utilizada con otros datos'; END IF;
  RETURN v_existing.id;
 END IF;
 SELECT * INTO v_contract FROM public.inv_contratos WHERE id=p_contrato FOR UPDATE;
 IF NOT FOUND OR v_contract.estado<>'confirmado' OR v_contract.modalidad<>'credito' THEN RAISE EXCEPTION 'Contrato no cobrable'; END IF;
 SELECT * INTO v_sale FROM public.inv_ventas WHERE id=v_contract.venta_id FOR UPDATE;
 IF NOT FOUND OR v_sale.estado<>'registrada' OR v_sale.anulada_en IS NOT NULL THEN RAISE EXCEPTION 'Venta no vigente'; END IF;
 SELECT coalesce(sum(monto),0) INTO v_paid FROM public.cln_route_payments WHERE contrato_id=p_contrato;
 SELECT coalesce(sum(monto),0) INTO v_prima FROM public.inv_contrato_primas WHERE contrato_id=p_contrato AND estado='recibida';
 IF p_monto>v_sale.total-v_paid-v_prima THEN RAISE EXCEPTION 'Abono supera el saldo disponible'; END IF;
 INSERT INTO public.cln_route_payments(contrato_id,op_id,monto,fecha,cobrador,registrado_por) VALUES(p_contrato,p_op,p_monto,p_fecha,trim(p_cobrador),v_user) RETURNING id INTO v_id;
 RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION cln_admin_internal.registrar_abono(uuid,uuid,numeric,date,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION cln_admin_internal.registrar_abono(uuid,uuid,numeric,date,text) TO authenticated;
CREATE FUNCTION public.cln_registrar_abono(p_contrato uuid,p_op uuid,p_monto numeric,p_fecha date,p_cobrador text)
RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path TO ''
AS $$ SELECT cln_admin_internal.registrar_abono(p_contrato,p_op,p_monto,p_fecha,p_cobrador) $$;
REVOKE ALL ON FUNCTION public.cln_registrar_abono(uuid,uuid,numeric,date,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.cln_registrar_abono(uuid,uuid,numeric,date,text) TO authenticated;

-- Serialize the transition of a received prime with payments and sale cancellation.
CREATE FUNCTION cln_admin_internal.validar_prima_abonos()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $guard$
DECLARE v_sale_id uuid; v_total numeric; v_estado text; v_abonos numeric;
BEGIN
 IF NEW.estado IS DISTINCT FROM 'recibida' THEN RETURN NEW; END IF;
 SELECT venta_id INTO v_sale_id FROM public.inv_contratos WHERE id=NEW.contrato_id FOR UPDATE;
 IF v_sale_id IS NULL THEN RETURN NEW; END IF;
 SELECT total,estado INTO v_total,v_estado FROM public.inv_ventas WHERE id=v_sale_id FOR UPDATE;
 IF v_estado IS DISTINCT FROM 'registrada' THEN RAISE EXCEPTION 'Venta no vigente'; END IF;
 SELECT coalesce(sum(monto),0) INTO v_abonos FROM public.cln_route_payments WHERE contrato_id=NEW.contrato_id;
 IF NEW.monto+v_abonos>v_total THEN RAISE EXCEPTION 'La prima supera el saldo después de los abonos'; END IF;
 RETURN NEW;
END;
$guard$;
REVOKE ALL ON FUNCTION cln_admin_internal.validar_prima_abonos() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER cln_guard_prima_abonos BEFORE UPDATE OF estado,monto ON public.inv_contrato_primas
FOR EACH ROW EXECUTE FUNCTION cln_admin_internal.validar_prima_abonos();
-- Until an authorized reversal workflow exists, do not hide money by voiding a paid sale.
CREATE FUNCTION cln_admin_internal.validar_anulacion_abonos()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $guard$
BEGIN
 IF OLD.estado='registrada' AND NEW.estado='anulada' AND EXISTS(
 SELECT 1 FROM public.inv_contratos c JOIN public.cln_route_payments a ON a.contrato_id=c.id WHERE c.venta_id=NEW.id
 ) THEN RAISE EXCEPTION 'La venta tiene abonos registrados; requiere conciliacion antes de anular'; END IF;
 RETURN NEW;
END;
$guard$;
REVOKE ALL ON FUNCTION cln_admin_internal.validar_anulacion_abonos() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER cln_guard_anulacion_abonos BEFORE UPDATE OF estado ON public.inv_ventas
FOR EACH ROW EXECUTE FUNCTION cln_admin_internal.validar_anulacion_abonos();
