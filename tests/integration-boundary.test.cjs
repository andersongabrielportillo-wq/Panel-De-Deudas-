'use strict';
// Deployment boundary regression checks; never connect to live accounts.
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const read=p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8');
const index=read('index.html');
const shell=read('cl-nexus-shell.js');
const lab=read('staging/index.html');
test('production debt gate stays off until coordinated server RLS cutover',()=>{
 assert.match(index,/const\s+DEBT_GATE_ENABLED\s*=\s*false\s*;/);
});
test('production and laboratory Supabase origins remain distinct',()=>{
 const prod=index.match(/const\s+SUPABASE_URL\s*=\s*["'](https:\/\/[^"']+)["']/);
 const staging=shell.match(/const\s+LAB_ORIGIN\s*=\s*["'](https:\/\/[^"']+)["']/);
 assert.ok(prod&&staging,'Both origins must be explicit');
 assert.notEqual(prod[1],staging[1]);
 assert.match(staging[1],/^https:\/\/dozcnytevqhoymzqlxah\.supabase\.co$/);
});
test('CL Nexus refuses laboratory RPCs from production origin',()=>{
 assert.match(shell,/window\.CLNexusRuntime\.origin\s*!==\s*LAB_ORIGIN/);
 assert.match(shell,/return\s+null/);
});
test('staging has a warning against real production credentials',()=>{
 assert.match(lab,/SOLO DATOS FICTICIOS/);
 assert.match(lab,/No uses credenciales ni claves de producci[oó]n/);
});
test('production debt reads and writes have server-gate checks ready for cutover',()=>{
 assert.match(index,/async function cloudSnapshot\(\)[\s\S]*?DEBT_GATE_ENABLED\s*&&\s*\(!debtGate\|\|!debtGate\.isUnlocked\(\)\)/);
 assert.match(index,/async function cloudSet\(payload\)[\s\S]*?DEBT_GATE_ENABLED\s*&&\s*\(!debtController\|\|!await debtController\.verify\(\)\)/);
});

test('actual PWA logout revokes server grant before Supabase signout',()=>{
 const start=index.indexOf('document.getElementById("logoutBtn").onclick=async()=>');
 const end=index.indexOf('SB.auth.onAuthStateChange',start);
 assert.ok(start>=0&&end>start,'Logout handler must be present');
 const handler=index.slice(start,end);
 const revoke=handler.indexOf('await debtController.logout()');
 const signout=handler.indexOf('await SB.auth.signOut()');
 assert.ok(revoke>=0&&signout>revoke,'Revoke before ending authenticated session');
 assert.match(handler,/debtRevokeFailed\s*=\s*true/);
});

test('laboratory logout invalidates local session before server revocation',()=>{
 const handler=lab.slice(lab.indexOf('$("logout").onclick=async()=>'));
 const clear=handler.indexOf('session=null');
 const remote=handler.indexOf('"/auth/v1/logout"');
 assert.ok(clear>=0&&remote>clear,'Clear local credentials before remote logout');
 assert.match(handler,/authEpoch\+\+;stop\(\);seq\+\+/);
});
test('laboratory logout revokes the Supabase Auth session on its own origin',()=>{
 assert.match(lab,/oldSession\.origin\+"\/auth\/v1\/logout"/);
 assert.match(lab,/"Authorization":"Bearer "\+oldSession\.token/);
 assert.match(lab,/cache:"no-store"/);
});
test('laboratory logout clears results and password inputs even if network fails',()=>{
 const handler=lab.slice(lab.indexOf('$("logout").onclick=async()=>'));
 for(const name of ['output','clientResults','detailResults','permissionsResult','concurrencyResult','password','key']){
  assert.ok(handler.includes('$("'+name+'")'),'Missing cleanup for '+name);
 }
 assert.match(handler,/no se pudo confirmar el cierre remoto/);
});

test('staging debt permission probe uses only server-side lab validation',()=>{
 assert.match(lab,/id="checkDebtAccess"/);
 assert.match(lab,/id="debtWorkspace"/);
 assert.match(lab,/\/rest\/v1\/rpc\/debt_lab_access_valid/);
 assert.match(lab,/p_workspace_id:id/);
});
test('staging debt permission probe cannot unlock or mutate debt records',()=>{
 const start=lab.indexOf('$("checkDebtAccess").onclick=async()=>');
 const end=lab.indexOf('$("runConcurrency").onclick=async()=>',start);
 assert.ok(start>=0&&end>start);
 const probe=lab.slice(start,end);
 assert.doesNotMatch(probe,/debt_lab_unlock|debt_lab_lock|\/rest\/v1\/debts|\.insert\(|\.update\(|\.delete\(/);
 assert.match(probe,/session!==s\|\|authEpoch!==epoch/);
});
