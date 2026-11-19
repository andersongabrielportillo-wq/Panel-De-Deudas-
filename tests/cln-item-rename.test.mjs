import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
const require=createRequire(import.meta.url);
const {createNexusActions}=require('../cl-nexus-actions.cjs');
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
const ID='a542e833-e9a2-4aba-8c60-ec94726464bc';
test('name correction calls only allowed backend RPC and includes stale-name protection',async()=>{
 const calls=[];
 const actions=createNexusActions({client:{rpc:async(rpc,args)=>{calls.push({rpc,args});return {data:ID,error:null}}},authorized:()=>true});
 assert.equal(await actions.execute('renameItem',{p_item_id:ID,p_nombre:'Nombre Corregido',p_nombre_esperado:'Nombre previo'}),ID);
 assert.deepEqual(calls,[{rpc:'inv_corregir_nombre_articulo',args:{p_item_id:ID,p_nombre:'Nombre Corregido',p_nombre_esperado:'Nombre previo'}}]);
});
test('name correction denies unauthenticated, invalid IDs and unexpected columns',async()=>{
 let sent=0;
 const client={rpc:async()=>{sent++;return {data:ID,error:null}}};
 const unauthorized=createNexusActions({client,authorized:()=>false});
 await assert.rejects(unauthorized.execute('renameItem',{p_item_id:ID,p_nombre:'nuevo',p_nombre_esperado:'anterior'}),/Sesión no autorizada/);
 const authorized=createNexusActions({client,authorized:()=>true});
 await assert.rejects(authorized.execute('renameItem',{p_item_id:'bad',p_nombre:'nuevo',p_nombre_esperado:'anterior'}),/ID inválido/);
 await assert.rejects(authorized.execute('renameItem',{p_item_id:ID,p_nombre:'nuevo'}),/Falta p_nombre_esperado/);
 await assert.rejects(authorized.execute('renameItem',{p_item_id:ID,p_nombre:'nuevo',p_nombre_esperado:'anterior',admin:true}),/Parámetro inesperado/);
 assert.equal(sent,0);
});
test('PWA includes name correction, source code disambiguation and unregistered stock messaging',()=>{
 assert.match(html,/renameSelector=renameSelect/);
 assert.match(html,/actions\.execute\("renameItem"/);
 assert.match(html,/p_nombre_esperado:previous/);
 assert.match(html,/option\.dataset\.expectedName=article\.nombre/);
 assert.match(html,/item\.codigo/);
 assert.match(html,/Sin registrar/);
 assert.match(html,/guardará el cambio en su auditoría/);
});
