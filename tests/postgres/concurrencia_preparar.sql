\set ON_ERROR_STOP on
-- Preparar contrato y claves para dos sesiones simultaneas en PostgreSQL aislado.
DO $$
DECLARE
 a uuid:='11111111-1111-4111-8111-111111111111';
 v uuid; c uuid; i uuid; k uuid;
BEGIN
 PERFORM pg_catalog.set_config('request.jwt.claim.sub',a::text,true);
 SELECT id INTO v FROM public.inv_vendedores_manual WHERE activo=true LIMIT 1;
 SELECT id INTO c FROM public.inv_clientes LIMIT 1;
 INSERT INTO public.inv_items(nombre_original,categoria) VALUES('Articulo concurrencia ficticio','Ficticio') RETURNING id INTO i;
 INSERT INTO public.inv_stock(item_id,location_id,cantidad) VALUES(i,1,5);
 k:=public.inv_crear_contrato_borrador('CI-CONCURRENCIA',c,v,current_date,
 'credito','semanal','normal',10,50,NULL,NULL,NULL,NULL,0,10,false,
 pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('item_id',i,'cantidad',2,'precio_credito_unitario',30)),NULL);
END $$;
CREATE TABLE public.ci_concurrencia_ids AS
SELECT c.id contrato_id,d.id detalle_id,d.item_id,
 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid op_id
FROM public.inv_contratos c JOIN public.inv_contrato_detalles d ON d.contrato_id=c.id
WHERE c.numero='CI-CONCURRENCIA';
\echo 'Contrato de concurrencia listo'
