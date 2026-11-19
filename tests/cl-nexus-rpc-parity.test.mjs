import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const root=new URL('../',import.meta.url);
const file=name=>readFileSync(new URL(name,root),'utf8');
const schema=file('sql/cl_nexus_schema_lab_SNAPSHOT_SOLO_ENSAYO_NO_PRODUCCION.sql');
const addon=file('sql/cln_corregir_nombre_articulo_PREPARADO_NO_EJECUTAR.sql');
const originalFunctions=new Set([...schema.matchAll(/CREATE OR REPLACE FUNCTION public\.(inv_[a-z0-9_]+)\(/g)].map(x=>x[1]));
const functions=new Set([...originalFunctions,...[...addon.matchAll(/CREATE OR REPLACE FUNCTION public\.(inv_[a-z0-9_]+)\(/g)].map(x=>x[1])]);
test('all inventory RPCs referenced by CL Nexus clients exist in the staged schema',()=>{
  assert.equal(originalFunctions.size,37,'Expected 37 original lab inventory RPCs');
  assert.ok(functions.has('inv_catalogo_articulos_admin') && functions.has('inv_corregir_nombre_articulo'));
  assert.equal(functions.size,39,'37 lab inventory functions + 2 secured cutover additions');
  for(const path of ['cl-nexus-reader.cjs','cl-nexus-actions.cjs','cl-nexus-adapter.cjs']){
    const names=[...new Set(file(path).match(/inv_[a-z0-9_]+/g)||[])];
    for(const name of names)assert.ok(functions.has(name),path+' references missing RPC '+name);
  }
});
test('the current production PWA does not call sandbox-only RPC',()=>{
 assert.doesNotMatch(file('index.html'),/cl2_sandbox_list/);
 assert.match(file('cl-nexus-shell.js'),/origin!==LAB_ORIGIN/);
 assert.match(file('index.html'),/const DEBT_GATE_ENABLED=false;/);
});
