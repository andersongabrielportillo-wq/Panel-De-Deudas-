import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {createDebtGate}=require('../debt-gate-client.cjs');
const WID='00000000-0000-4000-8000-000000000001';
test('password is never sent to read verification',async()=>{
 const calls=[];const gate=createDebtGate({client:{rpc:async(n,a)=>{calls.push([n,a]);return {data:n==='debt_lab_unlock'?new Date(Date.now()+60000).toISOString():true,error:null}}},workspaceId:WID});
 await gate.unlock('contraseña temporal');assert.equal(await gate.verify(),true);assert.deepEqual(calls[1],['debt_lab_access_valid',{p_workspace_id:WID}]);assert.equal(JSON.stringify(calls[1]).includes('contraseña'),false);
});
test('wrong password does not unlock',async()=>{
 const gate=createDebtGate({client:{rpc:async()=>({data:null,error:null})},workspaceId:WID});
 await assert.rejects(gate.unlock('incorrecta'),/incorrecta|expirado/);assert.equal(gate.isUnlocked(),false);
});
test('server denial revokes local access',async()=>{
 let allowed=true;const gate=createDebtGate({client:{rpc:async(n)=>({data:n==='debt_lab_unlock'?new Date(Date.now()+60000).toISOString():allowed,error:null})},workspaceId:WID});
 await gate.unlock('temporal');allowed=false;assert.equal(await gate.verify(),false);assert.equal(gate.isUnlocked(),false);
});
test('lock invalidates local state before remote request',async()=>{
 let resolve;const gate=createDebtGate({client:{rpc:async(n)=>n==='debt_lab_lock'?new Promise(r=>{resolve=r}):{data:new Date(Date.now()+60000).toISOString(),error:null}},workspaceId:WID});
 await gate.unlock('temporal');const pending=gate.lock();assert.equal(gate.isUnlocked(),false);resolve({data:null,error:null});await pending;
});
test('logout reset discards delayed unlock response',async()=>{
 let resolve;const gate=createDebtGate({client:{rpc:()=>new Promise(r=>{resolve=r})},workspaceId:WID});
 const pending=gate.unlock('temporal');gate.reset();resolve({data:new Date(Date.now()+60000).toISOString(),error:null});await assert.rejects(pending,/Sesión modificada/);assert.equal(gate.isUnlocked(),false);
});

test('no permite desbloqueo mientras el bloqueo remoto está pendiente',async()=>{
 let resolveLock;
 const client={rpc:async(name)=>name==='debt_lab_lock'
  ? new Promise(resolve=>{resolveLock=resolve})
  : {data:new Date(Date.now()+60000).toISOString(),error:null}};
 const gate=createDebtGate({client,workspaceId:WID});
 await gate.unlock('temporal');
 const locking=gate.lock();
 await assert.rejects(gate.unlock('temporal'),/Bloqueo en curso/);
 resolveLock({data:null,error:null});
 await locking;
 assert.equal(gate.isUnlocked(),false);
});
test('un fallo de bloqueo remoto mantiene acceso local revocado',async()=>{
 const gate=createDebtGate({client:{rpc:async(name)=>name==='debt_lab_lock'
  ? {data:null,error:{message:'Servidor no disponible'}}
  : {data:new Date(Date.now()+60000).toISOString(),error:null}},workspaceId:WID});
 await gate.unlock('temporal');
 await assert.rejects(gate.lock(),/Servidor no disponible/);
 assert.equal(gate.isUnlocked(),false);
});

test('dos sesiones no comparten estado de desbloqueo en cliente',async()=>{
 const calls=[];
 const client={rpc:async(name,args)=>{calls.push([name,args]);return {data:name==='debt_lab_unlock'?new Date(Date.now()+60000).toISOString():true,error:null}}};
 const a=createDebtGate({client,workspaceId:WID}),b=createDebtGate({client,workspaceId:WID});
 await a.unlock('clave temporal');
 assert.equal(a.isUnlocked(),true);assert.equal(b.isUnlocked(),false);
 assert.equal(await b.verify(),false);
 assert.equal(calls.filter(x=>x[0]==='debt_lab_access_valid').length,0);
});
test('desbloqueos simultáneos se serializan sin crear autorización fantasma',async()=>{
 let firstResolve;let attempts=0;
 const gate=createDebtGate({workspaceId:WID,client:{rpc:async name=>{
  if(name==='debt_lab_unlock'){attempts++;return new Promise(r=>firstResolve=r)}
  return {data:true,error:null};
 }}});
 const first=gate.unlock('primera');
 await assert.rejects(gate.unlock('segunda'),/Desbloqueo en curso/);
 assert.equal(attempts,1);
 gate.reset();
 firstResolve({data:new Date(Date.now()+60000).toISOString(),error:null});
 await assert.rejects(first,/Sesión modificada/);
 assert.equal(gate.isUnlocked(),false);
});
test('verificación retrasada no reautoriza después de reset',async()=>{
 let verifyResolve;
 const gate=createDebtGate({workspaceId:WID,client:{rpc:async name=>name==='debt_lab_unlock'
 ? {data:new Date(Date.now()+60000).toISOString(),error:null}
 : new Promise(r=>verifyResolve=r)}});
 await gate.unlock('temporal');const check=gate.verify();gate.reset();
 verifyResolve({data:true,error:null});
 assert.equal(await check,false);assert.equal(gate.isUnlocked(),false);
});
test('caducidad local rechaza sin solicitar permiso al servidor',async()=>{
 let calls=0;const original=Date.now;
 try{
  const start=original();Date.now=()=>start;
  const gate=createDebtGate({workspaceId:WID,client:{rpc:async name=>{calls++;return {data:name==='debt_lab_unlock'?new Date(start+1000).toISOString():true,error:null}}}});
  await gate.unlock('temporal');Date.now=()=>start+1001;
  assert.equal(gate.isUnlocked(),false);assert.equal(await gate.verify(),false);assert.equal(calls,1);
 }finally{Date.now=original}
});
test('un error de red al verificar revoca autorización local',async()=>{
 const gate=createDebtGate({workspaceId:WID,client:{rpc:async name=>name==='debt_lab_unlock'
 ? {data:new Date(Date.now()+60000).toISOString(),error:null}
 : {data:null,error:{message:'sin conexión'}}}});
 await gate.unlock('temporal');assert.equal(await gate.verify(),false);assert.equal(gate.isUnlocked(),false);
});
