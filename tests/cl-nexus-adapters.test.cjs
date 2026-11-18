'use strict';
const assert=require('node:assert/strict');
const {test}=require('node:test');
const {createNexusReader}=require('../cl-nexus-reader.cjs');
const {createNexusActions}=require('../cl-nexus-actions.cjs');
const id='123e4567-e89b-42d3-a456-426614174000';
test('reader refuses unauthenticated calls',async()=>{
 let calls=0;
 const reader=createNexusReader({client:{rpc:async()=>{calls++;return {data:[]}}},authorized:()=>false});
 await assert.rejects(reader.list('inventory'),/Sesión/);
 assert.equal(calls,0);
});
test('reader preserves item identifiers',async()=>{
 const reader=createNexusReader({client:{rpc:async()=>({data:[{id,nombre:'Artículo',categoria:'Hogar'}]})},authorized:()=>true});
 assert.deepEqual(await reader.list('inventory'),[{id,nombre:'Artículo',categoria:'Hogar'}]);
});
test('reader rejects stale responses after reset',async()=>{
 let finish;
 const reader=createNexusReader({client:{rpc:()=>new Promise(resolve=>finish=resolve)},authorized:()=>true});
 const pending=reader.list('inventory');
 reader.reset();finish({data:[]});
 await assert.rejects(pending,/Sesión cerrada/);
});
test('action rejects invalid quantity before RPC',async()=>{
 let calls=0;
 const actions=createNexusActions({client:{rpc:async()=>{calls++;return {data:1}}},authorized:()=>true});
 await assert.rejects(actions.execute('requestEntry',{p_item_id:id,p_location_id:1,p_cantidad:0,p_observaciones:'test'}),/Cantidad/);
 assert.equal(calls,0);
});
test('action calls exact whitelisted RPC',async()=>{
 let called;
 const actions=createNexusActions({client:{rpc:async(name,args)=>{called=[name,args];return {data:id}}},authorized:()=>true});
 const params={p_item_id:id,p_location_id:1,p_cantidad:2,p_observaciones:'Ingreso'};
 assert.equal(await actions.execute('requestEntry',params),id);
 assert.deepEqual(called,['inv_solicitar_entrada',params]);
});
test('action refuses unauthenticated calls',async()=>{
 let calls=0;
 const actions=createNexusActions({client:{rpc:async()=>{calls++;return {data:1}}},authorized:()=>false});
 await assert.rejects(actions.execute('requestEntry',{}),/Sesión/);
 assert.equal(calls,0);
});
test('action rejects unexpected parameters',async()=>{
 const actions=createNexusActions({client:{rpc:async()=>({data:1})},authorized:()=>true});
 await assert.rejects(actions.execute('requestEntry',{p_item_id:id,p_location_id:1,p_cantidad:1,p_observaciones:'x',p_admin:true}),/inesperado/);
});
test('action rejects stale success after reset',async()=>{
 let finish;
 const actions=createNexusActions({client:{rpc:()=>new Promise(resolve=>finish=resolve)},authorized:()=>true});
 const pending=actions.execute('requestEntry',{p_item_id:id,p_location_id:1,p_cantidad:1,p_observaciones:'x'});
 actions.reset();finish({data:id});
 await assert.rejects(pending,/Sesión cerrada/);
});

test('warehouse location accepts numeric IDs and rejects UUID-like values',async()=>{
 let calls=0;
 const actions=createNexusActions({client:{rpc:async()=>{calls++;return {data:id}}},authorized:()=>true});
 await actions.execute('requestEntry',{p_item_id:id,p_location_id:1,p_cantidad:2,p_observaciones:'Prueba'});
 assert.equal(calls,1);
 await assert.rejects(actions.execute('requestEntry',{p_item_id:id,p_location_id:id,p_cantidad:2,p_observaciones:'Prueba'}),/Cantidad o ubicación/);
 assert.equal(calls,1);
});
