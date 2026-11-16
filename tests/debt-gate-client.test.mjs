import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {createDebtGate}=require('../debt-gate-client.cjs');
const WID='00000000-0000-4000-8000-000000000001';
test('password is never sent to read verification',async()=>{
 const calls=[];const gate=createDebtGate({client:{rpc:async(n,a)=>{calls.push([n,a]);return {data:n==='debt_unlock'?new Date(Date.now()+60000).toISOString():true,error:null}}},workspaceId:WID});
 await gate.unlock('contraseña temporal');assert.equal(await gate.verify(),true);assert.deepEqual(calls[1],['debt_access_valid',{p_workspace_id:WID}]);assert.equal(JSON.stringify(calls[1]).includes('contraseña'),false);
});
test('wrong password does not unlock',async()=>{
 const gate=createDebtGate({client:{rpc:async()=>({data:null,error:null})},workspaceId:WID});
 await assert.rejects(gate.unlock('incorrecta'),/incorrecta|expirado/);assert.equal(gate.isUnlocked(),false);
});
test('server denial revokes local access',async()=>{
 let allowed=true;const gate=createDebtGate({client:{rpc:async(n)=>({data:n==='debt_unlock'?new Date(Date.now()+60000).toISOString():allowed,error:null})},workspaceId:WID});
 await gate.unlock('temporal');allowed=false;assert.equal(await gate.verify(),false);assert.equal(gate.isUnlocked(),false);
});
test('lock invalidates local state before remote request',async()=>{
 let resolve;const gate=createDebtGate({client:{rpc:async(n)=>n==='debt_lock'?new Promise(r=>{resolve=r}):{data:new Date(Date.now()+60000).toISOString(),error:null}},workspaceId:WID});
 await gate.unlock('temporal');const pending=gate.lock();assert.equal(gate.isUnlocked(),false);resolve({data:null,error:null});await pending;
});
test('logout reset discards delayed unlock response',async()=>{
 let resolve;const gate=createDebtGate({client:{rpc:()=>new Promise(r=>{resolve=r})},workspaceId:WID});
 const pending=gate.unlock('temporal');gate.reset();resolve({data:new Date(Date.now()+60000).toISOString(),error:null});await assert.rejects(pending,/Sesión modificada/);assert.equal(gate.isUnlocked(),false);
});
