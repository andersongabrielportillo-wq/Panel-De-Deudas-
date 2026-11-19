import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
const require=createRequire(import.meta.url);
const {probe}=require('../cln-http-auth-probe.cjs');
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
function client({valid=true,unlocked=false,visible=0,items=190,authError=false,gateError=null}={}){
 const requests=[];
 const c={
  auth:{getUser:async()=>({data:{user:valid?{id:'synthetic-only'}:null},error:authError?{code:'invalid'}:null})},
  rpc:async(name)=>{
   requests.push('rpc:'+name);
   if(name==='has_debts_unlock')return {data:unlocked,error:gateError};
   if(name==='inv_catalogo_articulos_admin')return {data:Array.from({length:items},(_,i)=>({id:i})),error:null};
   if(name==='inv_catalogo_vendedores')return {data:[],error:null};
   throw Error('Unexpected RPC: '+name);
  },
  from:table=>{
   requests.push('from:'+table);
   assert.equal(table,'debts','Only Deudas read can be tested; no writes');
   return {select:(columns,opts)=>{
    assert.equal(columns,'id');assert.equal(opts.head,true);assert.equal(opts.count,'exact');
    return Promise.resolve({count:visible,error:null});
   }}
  }
 };
 return {c,requests};
}
test('Locked authenticated session sees zero debts but all 190 catalog items',async()=>{
 const {c,requests}=client();
 const result=await probe({client:c});
 assert.equal(result.pass,true);
 assert.equal(result.debtState,'bloqueada');
 assert.equal(result.visibleDebtRows,0);
 assert.deepEqual(requests,[
 'rpc:has_debts_unlock','from:debts',
 'rpc:inv_catalogo_articulos_admin','rpc:inv_catalogo_vendedores'
 ]);
});
test('Unlocked authenticated session can see one original shared Deudas row',async()=>{
 const {c}=client({unlocked:true,visible:1});
 const r=await probe({client:c});
 assert.equal(r.debtState,'desbloqueada');assert.equal(r.visibleDebtRows,1);
});
test('Reject leaked Deudas data when password gate is locked',async()=>{
 const {c}=client({unlocked:false,visible:1});
 await assert.rejects(probe({client:c}),/CRÍTICO: Deudas visibles sin contraseña/);
});
test('Reject absent real HTTP auth and missing or failing Vault gate',async()=>{
 for(const opts of [{valid:false},{authError:true},{gateError:{code:'42501'}}]){
  const {c}=client(opts);
  await assert.rejects(probe({client:c}),/Sesión HTTP no autenticada|RPC de desbloqueo/);
 }
});
test('Reject truncated inventory and unexpected rows when gate unlocks',async()=>{
 await assert.rejects(probe({client:client({items:189}).c}),/Catálogo no coincide/);
 await assert.rejects(probe({client:client({unlocked:true,visible:0}).c}),/conteo distinto al respaldo/);
});
test('Diagnostic UI is only available inside gated logged-in CL Nexus candidate',()=>{
 assert.match(html,/id="clnHubHttpAudit"/);
 assert.match(html,/CLNHttpAuthProbe\.probe\(\{client:SB\}\)/);
 assert.match(html,/!DEBT_GATE_ENABLED\|\|!SB_UID\|\|!SB_WID/);
 assert.match(html,/HTTP NO APROBADO/);
});
