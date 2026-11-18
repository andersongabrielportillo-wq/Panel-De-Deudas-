import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {createDebtGate}=require('../debt-gate-client.cjs');
const workspaceId='11111111-1111-4111-8111-111111111111';
const rpcNames={unlock:'unlock_debts',verify:'has_debts_unlock',lock:'lock_debts'};
test('production RPCs use server contract, not workspace arguments',async()=>{
 const calls=[];
 const client={rpc:async(name,args)=>{calls.push({name,args});return {data:name==='unlock_debts'||name==='has_debts_unlock'?true:null,error:null}}};
 const gate=createDebtGate({client,workspaceId,rpcNames});
 const expiry=await gate.unlock('example-test-only');
 assert.ok(expiry>Date.now());
 assert.equal(await gate.verify(),true);
 await gate.lock();
 assert.equal(gate.isUnlocked(),false);
 assert.deepEqual(calls.map(x=>x.name),['unlock_debts','has_debts_unlock','has_debts_unlock','lock_debts']);
 assert.deepEqual(calls[0].args,{p_password:'example-test-only'});
 for(const call of calls.slice(1))assert.equal(call.args,undefined);
});
test('production wrong password never unlocks',async()=>{
 const gate=createDebtGate({workspaceId,rpcNames,client:{rpc:async()=>({data:false,error:null})}});
 await assert.rejects(gate.unlock('wrong'),/incorrecta/);
 assert.equal(gate.isUnlocked(),false);
});
test('production unlock requires independent server verification',async()=>{
 const calls=[];
 const gate=createDebtGate({workspaceId,rpcNames,client:{rpc:async(name)=>{calls.push(name);return {data:name==='unlock_debts',error:null}}}});
 await assert.rejects(gate.unlock('example'),/no confirmado/);
 assert.deepEqual(calls,['unlock_debts','has_debts_unlock']);
 assert.equal(gate.isUnlocked(),false);
});
test('production verify failure revokes local state',async()=>{
 let valid=true;
 const gate=createDebtGate({workspaceId,rpcNames,client:{rpc:async(name)=>({data:name==='unlock_debts'?true:valid,error:null})}});
 await gate.unlock('example');
 valid=false;
 assert.equal(await gate.verify(),false);
 assert.equal(gate.isUnlocked(),false);
});
