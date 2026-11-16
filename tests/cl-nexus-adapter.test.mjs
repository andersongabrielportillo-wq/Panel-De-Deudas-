import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {makeAdapter}=require('../cl-nexus-adapter.cjs');
test('adapter fails closed without explicit enable',async()=>{const a=makeAdapter({client:{rpc:()=>{throw Error('should not call')}}});await assert.rejects(a.inventario(),/no habilitada/)});
test('allowlisted inventory RPC uses sandbox argument',async()=>{let call;const a=makeAdapter({client:{rpc:async(...args)=>{call=args;return {data:[],error:null}}},enabled:true});await a.inventario();assert.deepEqual(call,['cl2_sandbox_list',{p_module:'inventario'}])});
test('rejects invalid client IDs before RPC',async()=>{const a=makeAdapter({client:{rpc:async()=>({data:[],error:null})},enabled:true});assert.throws(()=>a.ficha('bad'),/inválido/)});
test('discards late results after session closes',async()=>{let finish;const a=makeAdapter({client:{rpc:()=>new Promise(resolve=>{finish=resolve})},enabled:true});const pending=a.vendedores();a.disable();finish({data:['secret'],error:null});await assert.rejects(pending,/descartado/)});
test('rejects unrecognized RPC methods',async()=>{const a=makeAdapter({client:{rpc:async()=>({data:[],error:null})},enabled:true});assert.throws(()=>a.clientes('ab'),/Búsqueda/)});

test('write operations reject invalid quantities before RPC',()=>{const a=makeAdapter({client:{rpc:async()=>({data:1,error:null})},enabled:true});assert.throws(()=>a.solicitarEntrada({itemId:'00000000-0000-4000-8000-000000000001',ubicacion:1,cantidad:0,observaciones:'ok'}),/Cantidad/)});
test('entry approval uses server-side RPC',async()=>{let call;const a=makeAdapter({client:{rpc:async(...args)=>{call=args;return {data:'aprobada',error:null}}},enabled:true});await a.revisarEntrada({solicitudId:'00000000-0000-4000-8000-000000000001',aprobar:true});assert.equal(call[0],'inv_revisar_entrada')});
test('warranty destination 3 is forbidden',()=>{const a=makeAdapter({client:{rpc:async()=>({data:1,error:null})},enabled:true});assert.throws(()=>a.liberarGarantia({itemId:'00000000-0000-4000-8000-000000000001',destino:3,cantidad:1,observaciones:'revisado'}),/Destino/)});
