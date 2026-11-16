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
 const prima=sql.indexOf("IF v_prima<0 OR v_prima>v_total");
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

test('15Q rechaza reintento de venta anulada',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15q_confirmar_contrato.sql',import.meta.url),'utf8');
 assert.match(sql,/v\.anulada_en IS NOT NULL/);
 assert.match(sql,/La venta asociada fue anulada/);
});
test('15Q valida límites de líneas y monto antes de registrar venta',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15q_confirmar_contrato.sql',import.meta.url),'utf8');
 assert.match(sql,/v_cantidad_lineas>100/);
 assert.match(sql,/v_total>999999999999\.99/);
 assert.match(sql,/v_prima<0 OR v_prima>v_total/);
});

test('15Q rechaza UUID de línea inválido antes de convertir',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15q_confirmar_contrato.sql',import.meta.url),'utf8');
 const validar=sql.indexOf("Identificador de línea inválido");
 const convertir=sql.indexOf("(v_linea->>'detalle_id')::uuid");
 assert.ok(validar>=0 && convertir>validar);
});
test('15Q exige ubicación numérica sin coerción de texto',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15q_confirmar_contrato.sql',import.meta.url),'utf8');
 assert.match(sql,/jsonb_typeof\(v_linea->'location_id'\)<>'number'/);
 assert.match(sql,/Solo se permiten ubicaciones numéricas 1 y 2/);
});

test('15Q contiene una sola definición de función y un único cierre transaccional',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15q_confirmar_contrato.sql',import.meta.url),'utf8');
 assert.equal((sql.match(/CREATE OR REPLACE FUNCTION public\.inv_confirmar_contrato\(/g)||[]).length,1);
 assert.equal((sql.match(/^COMMIT;\s*$/gm)||[]).length,1);
 assert.equal((sql.match(/^END \$\$;\s*$/gm)||[]).length,1);
});

test('15J busca nombre literal sin comodines SQL que expongan listados amplios',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15j_contratos_rpc.sql',import.meta.url),'utf8');
 assert.match(sql,/pg_catalog\.strpos\(lower\(c\.nombre\),lower\(v_q\)\)>0/);
 assert.doesNotMatch(sql,/lower\(c\.nombre\) LIKE/);
});

test('15J valida DUI también en servidor sin limpiar letras silenciosamente',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15j_contratos_rpc.sql',import.meta.url),'utf8');
 const rechazo=sql.indexOf("p_dui !~ '^[0-9[:space:]-]*$'");
 const normalizar=sql.indexOf("v_dui:=NULLIF(");
 assert.ok(rechazo>=0 && normalizar>rechazo);
});
test('15J limita el nombre de referencias a 200 caracteres',()=>{
 const sql=readFileSync(new URL('../migrations/20261115_fase15j_contratos_rpc.sql',import.meta.url),'utf8');
 assert.match(sql,/length\(pg_catalog\.btrim\(coalesce\(v_ref->>'nombre',''\)\)\) NOT BETWEEN 2 AND 200/);
});
