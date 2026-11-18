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
