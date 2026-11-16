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
