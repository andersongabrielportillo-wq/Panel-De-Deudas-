import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const base=new URL('../migrations/',import.meta.url);
const rpc=readFileSync(new URL('20261115_fase15j_contratos_rpc.sql',base),'utf8');
const confirm=readFileSync(new URL('20261115_fase15q_confirmar_contrato.sql',base),'utf8');
test('RPC contratos exigen membresía y rol en servidor',()=>{
 for(const fn of ['inv_buscar_clientes','inv_crear_cliente','inv_crear_contrato_borrador','inv_marcar_prima_recibida']){
  const pos=rpc.indexOf('FUNCTION public.'+fn+'(');assert.ok(pos>=0,'Falta '+fn);
  const body=rpc.slice(pos,rpc.indexOf('END $$;',pos)+7);
  assert.match(body,/auth\.uid\(\)/,'Falta autenticación '+fn);
  assert.match(body,/public\.inv_members/,'Falta membresía '+fn);
  assert.match(body,/admin.*secretaria/s,'Falta rol '+fn);
 }
});
test('confirmación de contrato requiere rol, bloqueo e idempotencia',()=>{
 assert.match(confirm,/FUNCTION public\.inv_confirmar_contrato\(/);
 assert.match(confirm,/auth\.uid\(\)/);
 assert.match(confirm,/public\.inv_members/);
 assert.match(confirm,/FOR UPDATE/);
 assert.match(confirm,/p_client_op_id/);
 assert.match(confirm,/Contrato ya confirmado con otra operación/);
});
test('migraciones advierten que no deben ejecutarse en producción',()=>{
 assert.match(rpc,/NO APLICAR en producción/);
 assert.match(confirm,/No ejecutar en producción/);
});
