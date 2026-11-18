import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {createDebtGate}=require('../debt-gate-client.cjs');
const {createDebtModuleController}=require('../debt-module-controller.cjs');
const {inspectDebtCache}=require('../debt-cache-preflight.cjs');
const workspaceId='00000000-0000-4000-8000-000000000001';
function integration({pending=false,serverValid=true,wrongPassword=false}={}){
 const events=[];let authorized=false,visible=false,reads=0,valid=serverValid;
 const store={getItem(key){events.push('cache:'+key);reads++;if(key==='cp_pend')return pending?'1':null;if(key==='cp_v2')return '{"deudas":"ficticias"}';return null}};
 const client={rpc:async(name)=>{
  events.push('rpc:'+name);
  if(name==='debt_lab_unlock'){if(wrongPassword)return {data:null,error:null};authorized=true;return {data:new Date(Date.now()+60000).toISOString(),error:null}}
  if(name==='debt_lab_access_valid')return {data:authorized&&valid,error:null};
  if(name==='debt_lab_lock'){authorized=false;return {data:null,error:null}};
  throw Error('RPC desconocida');
 }};
 const gate=createDebtGate({client,workspaceId});
 const controller=createDebtModuleController({gate,load:async()=>{inspectDebtCache(store);events.push('load')},show:()=>{visible=true;events.push('show')},hide:()=>{visible=false;events.push('hide')},disconnect:async()=>events.push('disconnect'),hasPending:()=>pending,confirmPending:async()=>false});
 return {controller,events,get visible(){return visible},get reads(){return reads},revoke:()=>{valid=false}};
}
test('integración: no hay lectura de caché antes de RPC de desbloqueo y validación',async()=>{
 const x=integration();assert.equal(x.reads,0);await x.controller.open('ficticia');
 const firstCache=x.events.findIndex(e=>e.startsWith('cache:'));
 const verifies=x.events.map((e,i)=>e==='rpc:debt_lab_access_valid'?i:-1).filter(i=>i>=0);
 assert.ok(firstCache>verifies[0]);assert.ok(verifies[1]>firstCache);
 assert.equal(x.visible,true);
});
test('integración: contraseña incorrecta no consulta almacenamiento local',async()=>{
 const x=integration({wrongPassword:true});
 await assert.rejects(x.controller.open('incorrecta'),/incorrecta|expirado/);
 assert.equal(x.reads,0);assert.equal(x.visible,false);
});
test('integración: bloqueo no confirmado conserva pendientes',async()=>{
 const x=integration({pending:true});await x.controller.open('ficticia');
 assert.equal(await x.controller.lock(),false);assert.equal(x.visible,true);
 assert.equal(x.events.includes('rpc:debt_lab_lock'),false);
});
test('integración: revocación remota oculta módulo y corta conexión',async()=>{
 const x=integration();await x.controller.open('ficticia');x.revoke();
 assert.equal(await x.controller.verify(),false);assert.equal(x.visible,false);
 assert.ok(x.events.includes('disconnect'));
});
