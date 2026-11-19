// Anonymous HTTP smoke test against the existing PUBLIC Supabase API only.
// No real users, JWTs, passwords, secret keys, writes to tables, or logs with business data.
// This verifies ANON denial, not real authenticated session enforcement.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
const origin=html.match(/const SUPABASE_URL="(https:\/\/[^"]+)"/)?.[1];
const key=html.match(/const SUPABASE_KEY="(sb_publishable_[^"]+)"/)?.[1];
assert.equal(origin,'https://josdmjjbnrugiwlwgjky.supabase.co','Do not probe an unreviewed target');
assert.ok(key?.startsWith('sb_publishable_'),'Only the public publishable key may be used');
const request=async(path,init={})=>{
 const ctrl=new AbortController();
 const timer=setTimeout(()=>ctrl.abort(),12000);
 try{
  const response=await fetch(origin+path,{
   ...init,
   headers:{apikey:key,'Content-Type':'application/json',Accept:'application/json',...init.headers},
   signal:ctrl.signal,redirect:'error'
  });
  const body=(await response.text()).slice(0,12000);
  return {status:response.status,body};
 }finally{clearTimeout(timer)}
};
function noRecordsOrPermissionDenied(endpoint,r){
 if([401,403].includes(r.status))return;
 assert.equal(r.status,200,endpoint+' unexpected HTTP status '+r.status);
 let data;try{data=JSON.parse(r.body)}catch{throw new Error(endpoint+' returned non-JSON result')}
 assert.ok(Array.isArray(data),endpoint+' must return an array');
 assert.equal(data.length,0,endpoint+' leaked private records to anonymous callers');
}
console.log('CLN anonymous HTTP pre-cutover security probe — read-only, publishable key only');
const [debt,transactions,workspace,gate]=await Promise.all([
 request('/rest/v1/debts?select=id&limit=1'),
 request('/rest/v1/transactions?select=id&limit=1'),
 request('/rest/v1/workspaces?select=id&limit=1'),
 // Function is STABLE and READ ONLY: NOT unlock_debts; no password guesses.
 request('/rest/v1/rpc/has_debts_unlock',{method:'POST',body:'{}'})
]);
noRecordsOrPermissionDenied('debts',debt);
noRecordsOrPermissionDenied('transactions',transactions);
noRecordsOrPermissionDenied('workspaces',workspace);
assert.ok([401,403].includes(gate.status),
 'has_debts_unlock must deny execution for anonymous HTTP (got '+gate.status+')');
console.log('PASS: anon cannot read Deudas/transactions/workspaces or run unlock-status RPC.');
console.log('NOT YET TESTED: JWT-authenticated PC/phone sessions, Vault disaster restore, post-cutover restrictive RLS.');
