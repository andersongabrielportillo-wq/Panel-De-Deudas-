'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {webcrypto}=require('node:crypto');
const {inspectDebtCache}=require('../debt-cache-preflight.cjs');
const {capture,validate,restoreEmpty}=require('../debt-legacy-backup.cjs');
const {encryptBackup,decryptBackup}=require('../debt-encrypted-backup.cjs');
function storage(seed={}){
 const m=new Map(Object.entries(seed));
 return {getItem:k=>m.has(k)?m.get(k):null,setItem:(k,v)=>m.set(k,String(v)),removeItem:k=>m.delete(k),entries:()=>Object.fromEntries(m)};
}
test('preflight never approves deleting legacy plaintext, even with no pending marker',()=>{
 const report=inspectDebtCache(storage({cp_v2:'{"debts":[]}',cp_pend:'0'}));
 assert.equal(report.hasLegacyPlaintext,true);
 assert.equal(report.safeToPurge,false);
 assert.equal(report.requiresMigration,true);
});
test('unknown pending marker blocks migration and cleanup',()=>{
 const report=inspectDebtCache(storage({cp_pend:'unexpected'}));
 assert.equal(report.storageAccessible,false);
 assert.equal(report.hasUnknownPendingMarker,true);
});
test('capture preserves pending marker and all legacy keys without deleting anything',()=>{
 const local=storage({cp_v2:'{"tx":[1]}',cp_v2_bak:'backup',cp_pend:'1'});
 const original=local.entries(),backup=capture(local);
 assert.equal(validate(backup),true);
 assert.deepEqual(local.entries(),original);
 assert.equal(backup.entries.cp_pend,'1');
 assert.equal(backup.entries.cp_v2_bak,'backup');
});
test('restore refuses to overwrite even one existing local value',()=>{
 const local=storage({cp_v2:'live'});
 const backup=capture(storage({cp_v2:'older',cp_prev:'history'}));
 assert.throws(()=>restoreEmpty(local,backup),/existen datos locales/);
 assert.deepEqual(local.entries(),{cp_v2:'live'});
});
test('restore to empty storage verifies complete recovery',()=>{
 const original=storage({cp_v2:'payload',cp_pend:'1',cp_items:'[]'});
 const backup=capture(original),target=storage();
 assert.equal(restoreEmpty(target,backup),3);
 assert.deepEqual(target.entries(),original.entries());
});
test('encrypted backup roundtrip preserves exact pending debt data',async()=>{
 const backup=capture(storage({cp_v2:'{"deudas":"ñ","pagos":[12,13]}',cp_pend:'1'}));
 const envelope=await encryptBackup(backup,'frase segura de prueba 2026',webcrypto);
 assert.equal(envelope.format,'debt-encrypted-backup-v1');
 assert.ok(!JSON.stringify(envelope).includes('pagos'));
 assert.deepEqual(await decryptBackup(envelope,'frase segura de prueba 2026',webcrypto),JSON.parse(JSON.stringify(backup)));
});
test('incorrect password and tampered ciphertext fail closed',async()=>{
 const backup=capture(storage({cp_v2:'sensitive'}));
 const envelope=await encryptBackup(backup,'frase segura de prueba 2026',webcrypto);
 await assert.rejects(decryptBackup(envelope,'frase equivocada 2026',webcrypto),/incorrecta|alterado/);
 const tampered={...envelope,data:envelope.data.slice(0,-4)+'AAAA'};
 await assert.rejects(decryptBackup(tampered,'frase segura de prueba 2026',webcrypto));
});
