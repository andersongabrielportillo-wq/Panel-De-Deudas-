import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const sql=(f)=>readFileSync(new URL('../migrations/20261115_fase15'+f+'.sql',import.meta.url),'utf8');
const base=sql('i_contratos_base');
const rpc=sql('j_contratos_rpc');
const confirmacion=sql('q_confirmar_contrato');
const consultas=['j_contratos_rpc','k_historial_vendedores','n_catalogos_ficha_cliente','p_historial_cliente','q_confirmar_contrato'];

test('tablas sensibles activan RLS y no conceden acceso directo',()=>{
 for(const tabla of ['inv_clientes','inv_cliente_referencias','inv_contratos','inv_contrato_detalles','inv_contrato_primas','inv_prima_eventos']){
  assert.ok(base.includes('ALTER TABLE public.'+tabla+' ENABLE ROW LEVEL SECURITY;'),tabla);
 }
 assert.match(base,/REVOKE ALL ON public\.inv_clientes,[^;]* FROM anon,authenticated;/);
});
test('RPC de contratos exige miembro autorizado',()=>{
 for(const file of consultas){
  const s=sql(file);
  const funciones=(s.match(/CREATE OR REPLACE FUNCTION public\./g)||[]).length;
  const controles=(s.match(/rol IN \('admin','secretaria'\)/g)||[]).length;
  assert.ok(funciones>0,file);
  assert.equal(controles,funciones,file+' debe validar rol en cada función');
 }
});
test('RPC de contratos nunca concede ejecución a anon',()=>{
 for(const file of consultas){
  const s=sql(file);
  assert.doesNotMatch(s,/GRANT\s+(?:ALL|EXECUTE)[^;]*\bTO\s+anon\b/i,file);
 }
});
test('el borrador no invoca venta ni actualiza existencias',()=>{
 assert.doesNotMatch(rpc,/inv_registrar_venta\s*\(/);
 assert.doesNotMatch(rpc,/UPDATE\s+public\.inv_stock\b/i);
});
test('confirmación bloquea contrato, verifica ubicaciones y deduplica operación',()=>{
 assert.match(confirmacion,/WHERE id=p_contrato_id FOR UPDATE/);
 assert.match(confirmacion,/v_cantidad_lineas<>pg_catalog\.jsonb_array_length\(p_ubicaciones\)/);
 assert.match(confirmacion,/Línea de contrato repetida/);
 assert.match(confirmacion,/\^\[12\]\$/);
 assert.match(confirmacion,/pg_advisory_xact_lock/);
 assert.match(confirmacion,/WHERE v\.client_op_id=p_client_op_id/);
});
test('confirmación registra venta antes de marcar contrato confirmado',()=>{
 const venta=confirmacion.indexOf('v_venta_id:=public.inv_registrar_venta');
 const update=confirmacion.indexOf("SET estado='confirmado',venta_id=v_venta_id");
 assert.ok(venta>=0&&update>venta);
});

test('preflight postmigración enumera RPC esperadas y no oculta ausentes',()=>{
 const q=readFileSync(new URL('./15x_verificacion_postmigracion_solo_lectura.sql',import.meta.url),'utf8');
 assert.match(q,/FROM \(VALUES[\s\S]*?inv_confirmar_contrato/);
 assert.match(q,/LEFT JOIN pg_catalog\.pg_proc p ON/);
 assert.match(q,/p\.oid IS NOT NULL/);
 assert.equal((q.match(/\('inv_(?:buscar_clientes|crear_cliente|crear_contrato_borrador|marcar_prima_recibida|historial_vendedor|resumen_vendedor|catalogo_vendedores|catalogo_articulos_contratos|ficha_cliente|historial_cliente|detalle_contrato|confirmar_contrato)'\)/g)||[]).length,12);
});

test('auditoría de roles incluye empleado y evita exponer identidades',()=>{
 const q=readFileSync(new URL('./15ab_preflight_roles_y_rpc_solo_lectura.sql',import.meta.url),'utf8');
 for(const rol of ['admin','secretaria','empleado'])assert.ok(q.includes("('"+rol+"')"));
 assert.match(q,/count\(\*\)::integer AS cantidad/);
 assert.match(q,/has_function_privilege\('anon'/);
 assert.doesNotMatch(q,/SELECT\s+\*\s+FROM\s+public\.inv_members/i);
});
test('auditoría de roles inspecciona las tres RPC existentes',()=>{
 const q=readFileSync(new URL('./15ab_preflight_roles_y_rpc_solo_lectura.sql',import.meta.url),'utf8');
 for(const rpc of ['inv_registrar_venta','inv_anular_venta','inv_registrar_movimiento'])
  assert.ok(q.includes("'"+rpc+"'"));
 assert.match(q,/p\.prosecdef/);
});

test('preflight de ventas comprueba ocho puntos sin escribir inventario',()=>{
 const q=readFileSync(new URL('./15ac_preflight_payload_ventas_solo_lectura.sql',import.meta.url),'utf8');
 for(const campo of ['item_id','location_id','cantidad','precio_unitario','descuento'])
  assert.ok(q.includes("'"+campo+"'"),campo);
 assert.match(q,/inv_private\.verificar_reintento_venta/);
 assert.match(q,/public\.inv_registrar_movimiento/);
 assert.match(q,/pg_catalog\.pg_get_functiondef/);
 assert.doesNotMatch(q,/^\s*(?:INSERT\s+INTO|UPDATE\s+|DELETE\s+FROM|CREATE\s+|ALTER\s+|DROP\s+)/mi);
});
test('confirmación usa la RPC existente y conserva el identificador de operación',()=>{
 const q=readFileSync(new URL('../migrations/20261115_fase15q_confirmar_contrato.sql',import.meta.url),'utf8');
 for(const campo of ['item_id','location_id','cantidad','precio_unitario','descuento'])
  assert.ok(q.includes("'"+campo+"'"),campo);
 assert.match(q,/v_venta_id:=public\.inv_registrar_venta\(/);
 assert.match(q,/p_client_op_id\s*\n\s*\);/);
 assert.match(q,/pg_advisory_xact_lock/);
});

test('registrar prima bloquea primero el contrato y rechaza anulados',()=>{
 const q=readFileSync(new URL('../migrations/20261115_fase15j_contratos_rpc.sql',import.meta.url),'utf8');
 const inicio=q.indexOf('CREATE OR REPLACE FUNCTION public.inv_marcar_prima_recibida(');
 const fin=q.indexOf('END $$;',inicio);
 const fn=q.slice(inicio,fin);
 assert.ok(inicio>=0 && fin>inicio);
 const lockContrato=fn.indexOf('FROM public.inv_contratos');
 const lockPrima=fn.indexOf('FROM public.inv_contrato_primas');
 assert.ok(lockContrato>=0 && lockPrima>lockContrato,'Bloquear contrato antes que prima');
 assert.match(fn,/v_contrato_estado='anulado'/);
 assert.match(fn,/No se puede recibir prima de un contrato anulado/);
 assert.match(fn,/WHERE id=p_contrato_id FOR UPDATE/);
 assert.match(fn,/WHERE contrato_id=p_contrato_id FOR UPDATE/);
});

test('prima no puede marcarse recibida si su venta ya fue anulada',()=>{
 const q=readFileSync(new URL('../migrations/20261115_fase15j_contratos_rpc.sql',import.meta.url),'utf8');
 const fn=q.slice(q.indexOf('CREATE OR REPLACE FUNCTION public.inv_marcar_prima_recibida('));
 assert.match(fn,/SELECT estado,venta_id INTO v_contrato_estado,v_venta_id/);
 assert.match(fn,/v\.id=v_venta_id AND v\.anulada_en IS NOT NULL/);
 assert.match(fn,/La venta asociada fue anulada; revisar prima/);
});

test('inventario y vendedores permanecen separados sin precarga de nombres',()=>{
 const q=readFileSync(new URL('./15ad_preflight_separacion_inventario_vendedores_solo_lectura.sql',import.meta.url),'utf8');
 const catalogos=sql('n_catalogos_ficha_cliente');
 const vendedores=catalogos.slice(catalogos.indexOf('CREATE OR REPLACE FUNCTION public.inv_catalogo_vendedores()'),catalogos.indexOf('CREATE OR REPLACE FUNCTION public.inv_catalogo_articulos_contratos()'));
 const articulos=catalogos.slice(catalogos.indexOf('CREATE OR REPLACE FUNCTION public.inv_catalogo_articulos_contratos()'),catalogos.indexOf('CREATE OR REPLACE FUNCTION public.inv_ficha_cliente('));
 assert.match(q,/tablas_distintas/);
 assert.match(q,/to_regclass\('public\.inv_items'\)<>to_regclass\('public\.inv_vendedores'\)/);
 assert.doesNotMatch(q,/^\s*(?:INSERT|UPDATE|DELETE|TRUNCATE|CREATE|DROP|ALTER)\b/mi);
 assert.match(vendedores,/FROM public\.inv_vendedores v/);
 assert.doesNotMatch(vendedores,/FROM public\.inv_items/);
 assert.match(articulos,/FROM public\.inv_items i/);
 assert.doesNotMatch(articulos,/FROM public\.inv_vendedores/);
});

test('venta de contrato usa una sola RPC transaccional para descontar stock',()=>{
 const q=sql('q_confirmar_contrato');
 const funcion=q.slice(q.indexOf('CREATE OR REPLACE FUNCTION public.inv_confirmar_contrato('),q.indexOf('END $$;'));
 assert.equal((funcion.match(/v_venta_id:=public\.inv_registrar_venta\(/g)||[]).length,1);
 assert.doesNotMatch(funcion,/\b(?:UPDATE|INSERT INTO|DELETE FROM)\s+public\.inv_(?:stock|movimientos)\b/i);
 assert.match(funcion,/IF v_cantidad_lineas=0 OR v_cantidad_lineas>100/);
 assert.match(funcion,/v_cantidad_lineas<>pg_catalog\.jsonb_array_length\(p_ubicaciones\)/);
 assert.match(funcion,/IF v_contrato\.estado='confirmado' THEN/);
 assert.match(funcion,/WHERE v\.client_op_id=p_client_op_id/);
 const venta=funcion.indexOf('v_venta_id:=public.inv_registrar_venta');
 const confirmar=funcion.indexOf("SET estado='confirmado',venta_id=v_venta_id");
 assert.ok(venta>=0&&confirmar>venta);
});
test('borrador no altera stock y confirmacion exige ubicacion por linea',()=>{
 const borrador=sql('j_contratos_rpc');
 const confirmacion=sql('q_confirmar_contrato');
 assert.doesNotMatch(borrador,/public\.inv_registrar_venta\s*\(/);
 assert.doesNotMatch(borrador,/\bUPDATE\s+public\.inv_stock\b/i);
 assert.match(confirmacion,/location_id/);
 assert.match(confirmacion,/Solo se permiten ubicaciones numéricas 1 y 2/);
});

test('registro manual de vendedores comienza sin precarga de inventario',()=>{
 const q=readFileSync(new URL('../migrations/20261115_fase15ae_vendedores_manuales.sql',import.meta.url),'utf8');
 assert.match(q,/CREATE TABLE IF NOT EXISTS public\.inv_vendedores_manual/);
 assert.match(q,/ALTER TABLE public\.inv_vendedores_manual ENABLE ROW LEVEL SECURITY/);
 assert.match(q,/REVOKE ALL ON public\.inv_vendedores_manual FROM anon,authenticated/);
 assert.match(q,/CREATE OR REPLACE FUNCTION public\.inv_catalogo_vendedores_manual\(\)/);
 assert.match(q,/CREATE OR REPLACE FUNCTION public\.inv_crear_vendedor_manual\(p_nombre text\)/);
 assert.equal((q.match(/rol IN \('admin','secretaria'\)/g)||[]).length,2);
 assert.doesNotMatch(q,/\b(?:FROM|JOIN|INSERT INTO|UPDATE|DELETE FROM)\s+public\.inv_items\b/i);
 assert.doesNotMatch(q,/\b(?:FROM|JOIN|UPDATE|DELETE FROM)\s+public\.inv_vendedores\s/i);
 assert.match(q,/id uuid PRIMARY KEY REFERENCES public\.inv_vendedores\(id\) ON DELETE RESTRICT/);
 assert.match(q,/INSERT INTO public\.inv_vendedores\(id,nombre,activo\)/);
 assert.match(q,/INSERT INTO public\.inv_vendedores_manual\(id,nombre,creado_por\)/);
 assert.doesNotMatch(q,/^\s*INSERT\s+INTO\s+public\.inv_vendedores_manual[^;]*SELECT\b/mi);
 assert.doesNotMatch(q,/GRANT EXECUTE[^;]* TO anon/i);
});
