-- Draft for isolated validation. No employee names or historical balances in Git.
BEGIN;
CREATE TABLE IF NOT EXISTS public.cln_payroll_people (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 nombre text NOT NULL CHECK (length(trim(nombre)) BETWEEN 1 AND 200),
 vendedor_id uuid UNIQUE REFERENCES public.inv_vendedores(id),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.cln_payroll_templates (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 persona_id uuid NOT NULL REFERENCES public.cln_payroll_people(id),
 source_key text NOT NULL,
 campos jsonb NOT NULL CHECK (jsonb_typeof(campos)='array'),
 UNIQUE(persona_id,source_key)
);
CREATE TABLE IF NOT EXISTS public.cln_payroll_periods (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 plantilla_id uuid NOT NULL REFERENCES public.cln_payroll_templates(id),
 desde date NOT NULL,
 hasta date NOT NULL CHECK (hasta>=desde),
 valores jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(valores)='object'),
 UNIQUE(plantilla_id,desde,hasta)
);
CREATE TABLE IF NOT EXISTS public.cln_route_payments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 contrato_id uuid NOT NULL REFERENCES public.inv_contratos(id),
 op_id uuid NOT NULL UNIQUE,
 monto numeric(14,2) NOT NULL CHECK (monto>0),
 fecha date NOT NULL,
 cobrador text NOT NULL CHECK(length(trim(cobrador)) BETWEEN 1 AND 200),
 registrado_por uuid NOT NULL,
 creado_en timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cln_route_payments_contract_idx ON public.cln_route_payments(contrato_id);
ALTER TABLE public.cln_payroll_people ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cln_payroll_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cln_payroll_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cln_route_payments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.cln_payroll_people,public.cln_payroll_templates,public.cln_payroll_periods,public.cln_route_payments FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.cln_payroll_people,public.cln_payroll_templates,public.cln_payroll_periods,public.cln_route_payments TO authenticated;
CREATE POLICY cln_payroll_people_admin ON public.cln_payroll_people FOR SELECT TO authenticated USING (EXISTS(SELECT 1 FROM public.inv_members m WHERE m.user_id=(SELECT auth.uid()) AND m.rol='admin'));
CREATE POLICY cln_payroll_templates_admin ON public.cln_payroll_templates FOR SELECT TO authenticated USING (EXISTS(SELECT 1 FROM public.inv_members m WHERE m.user_id=(SELECT auth.uid()) AND m.rol='admin'));
CREATE POLICY cln_payroll_periods_admin ON public.cln_payroll_periods FOR SELECT TO authenticated USING (EXISTS(SELECT 1 FROM public.inv_members m WHERE m.user_id=(SELECT auth.uid()) AND m.rol='admin'));
CREATE POLICY cln_route_payments_members ON public.cln_route_payments FOR SELECT TO authenticated USING (EXISTS(SELECT 1 FROM public.inv_members m WHERE m.user_id=(SELECT auth.uid()) AND m.rol IN ('admin','secretaria')));
-- Payment history is append-only through the checked RPC. No client direct writes.
CREATE SCHEMA IF NOT EXISTS cln_admin_internal;
REVOKE ALL ON SCHEMA cln_admin_internal FROM PUBLIC,anon;
GRANT USAGE ON SCHEMA cln_admin_internal TO authenticated;
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
-- Before deployment: test payment vs. prime receipt and sale cancellation concurrency,
-- add controlled reversals and historical imports; connect route projection to actual payments.
COMMIT;
