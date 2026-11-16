import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const archivos=[
 '20261115_fase15i_contratos_base.sql',
 '20261115_fase15j_contratos_rpc.sql',
 '20261115_fase15k_historial_vendedores.sql',
 '20261115_fase15n_catalogos_ficha_cliente.sql',
 '20261115_fase15p_historial_cliente.sql',
 '20261115_fase15q_confirmar_contrato.sql'
];
for(const archivo of archivos){
 test('estructura transaccional '+archivo,()=>{
  const sql=readFileSync(new URL('../migrations/'+archivo,import.meta.url),'utf8');
  assert.match(sql,/^BEGIN;\s*$/m);
  assert.equal((sql.match(/^COMMIT;\s*$/gm)||[]).length,1);
  assert.match(sql,/COMMIT;\s*$/);
  assert.equal((sql.match(/\$\$/g)||[]).length%2,0,'Bloques PL/pgSQL desbalanceados');
  assert.doesNotMatch(sql,/COMMIT;[\s\S]*\bCREATE\s+OR\s+REPLACE\s+FUNCTION\b/i);
 });
}
test('15J valida cantidades antes de convertir a integer',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15j_contratos_rpc.sql',import.meta.url),'utf8');
 const regex=sql.indexOf("(v_line->>'cantidad') !~");
 const cast=sql.indexOf("v_cantidad:=(v_line->>'cantidad')::integer");
 assert.ok(regex>=0 && cast>regex);
});
test('15Q exige prima y saldo consistentes antes de registrar venta',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15q_confirmar_contrato.sql',import.meta.url),'utf8');
 const prima=sql.indexOf("IF v_prima>v_total");
 const saldo=sql.indexOf("v_contrato.saldo_inicial<>v_total-v_prima");
 const venta=sql.indexOf("v_venta_id:=public.inv_registrar_venta");
 assert.ok(prima>=0 && saldo>prima && venta>saldo);
});

test('15Q reintento de contrato confirmado exige el mismo ID de operación',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15q_confirmar_contrato.sql',import.meta.url),'utf8');
 assert.match(sql,/v\.id=v_contrato\.venta_id AND v\.client_op_id=p_client_op_id/);
 assert.match(sql,/Contrato ya confirmado con otra operación/);
 assert.match(sql,/IF v_contrato\.estado='confirmado' THEN[\s\S]*?RETURN v_contrato\.venta_id;/);
});
