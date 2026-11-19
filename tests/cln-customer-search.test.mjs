import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
const require=createRequire(import.meta.url);
const {createNexusReader}=require('../cl-nexus-reader.cjs');
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');

test('Contracts does not submit empty, whitespace or 2-character searches to Supabase',async()=>{
 const calls=[];
 const reader=createNexusReader({client:{rpc:async(name,args)=>{calls.push({name,args});return {data:[],error:null}}},authorized:()=>true});
 for(const term of ['', ' ', 'ab', ' a ', 'x'.repeat(101)]) {
  await assert.rejects(reader.list('contracts',term),/Busca clientes con 3 a 100 caracteres/);
 }
 assert.equal(calls.length,0,'Must reject short searches BEFORE any network call');
 assert.deepEqual(await reader.list('contracts',' abc '),[]);
 assert.equal(calls.length,1);
 assert.equal(calls[0].name,'inv_buscar_clientes');
 assert.deepEqual(calls[0].args,{p_busqueda:'abc'});
});
test('CL Nexus inventory and sellers remain available without a text query',async()=>{
 const calls=[];
 const reader=createNexusReader({client:{rpc:async(name,args)=>{calls.push({name,args});return {data:[],error:null}}},authorized:()=>true});
 await reader.list('inventory');
 await reader.list('sellers');
 assert.deepEqual(calls.map(x=>x.name),['inv_catalogo_articulos_admin','inv_catalogo_vendedores']);
});
test('Contracts first render waits for search; inventory initial listing stays enabled',()=>{
 const start=html.indexOf('async function openIndependentModule(id)');
 const end=html.indexOf('for(const id of Object.keys(clnHubViews))',start);
 assert.ok(start>0&&end>start);
 const moduleCode=html.slice(start,end);
 assert.ok(moduleCode.includes('search.maxLength=100'));
 assert.ok(moduleCode.includes('if(query.length<3||query.length>100)'));
 assert.ok(moduleCode.includes('if(kind==="inventory"){\n   renderRows(await nexusReader.list("inventory"),++requestSequence);'));
 assert.ok(moduleCode.includes('Busca clientes por nombre o DUI (mínimo 3 caracteres).'));
 assert.ok(!moduleCode.includes('renderRows(await nexusReader.list(kind),++requestSequence)'));
});

test('Inventory retains source code and distinguishes unregistered stock from registered zero',async()=>{
 const reader=createNexusReader({client:{rpc:async()=>({data:[
  {id:'synthetic',nombre:'NOMBRE PENDIENTE · MERCADERIA-C217',categoria:null,codigo:'MERCADERIA-C217',oficina:null,bodega:0}
 ],error:null})},authorized:()=>true});
 const rows=await reader.list('inventory');
 assert.equal(rows.length,1);
 assert.equal(rows[0].codigo,'MERCADERIA-C217');
 assert.equal(rows[0].oficina,'','A missing stock row is not zero');
 assert.equal(rows[0].bodega,'0','A registered zero remains a real zero');
});
