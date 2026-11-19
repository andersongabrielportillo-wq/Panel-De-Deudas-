/* Tests for legacy debt cache safety; synthetic data only. Run: node --test tests/debt-offline-safety.test.cjs */
'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {inspectDebtCache}=require('../debt-cache-preflight.cjs');
const {capture,validate,restoreEmpty}=require('../debt-legacy-backup.cjs');
function storage(initial={},failWrite=null){
 const data=new Map(Object.entries(initial));
 return {
  getItem:key=>data.has(key)?data.get(key):null,
  setItem:(key,value)=>{if(key===failWrite)throw Error('Quota exceeded');data.set(key,String(value))},
  removeItem:key=>data.delete(key),
  snapshot:()=>Object.fromEntries(data)
 };
}
test('empty cache is not purged automatically',()=>{
 const r=inspectDebtCache(storage());
 assert.equal(r.requiresMigration,false);
 assert.equal(r.safeToPurge,false);
});
test('all six legacy keys are preserved in capture',()=>{
 const source=storage({cp_v2:'{"a":1}',cp_v2_bak:'old',cp_v2_corrupt:'bad',cp_prev:'prev',cp_items:'[]',cp_pend:'1'});
 const backup=capture(source);
 assert.equal(validate(backup),true);
 assert.deepEqual({...backup.entries},source.snapshot());
 assert.equal(inspectDebtCache(source).hasPendingChanges,true);
 assert.equal(inspectDebtCache(source).safeToPurge,false);
});
test('unknown pending marker blocks safe migration',()=>{
 const r=inspectDebtCache(storage({cp_pend:'unexpected'}));
 assert.equal(r.hasUnknownPendingMarker,true);
 assert.equal(r.requiresMigration,true);
 assert.equal(r.storageAccessible,false);
});
test('restoreEmpty refuses overwrite without any mutation',()=>{
 const target=storage({cp_v2:'newer'});
 const backup=capture(storage({cp_v2:'older',cp_pend:'1'}));
 assert.throws(()=>restoreEmpty(target,backup),/existen datos locales/);
 assert.deepEqual(target.snapshot(),{cp_v2:'newer'});
});
test('restoreEmpty writes exact values into empty storage',()=>{
 const original=storage({cp_v2:'{"saldo":10}',cp_pend:'1'});
 const backup=capture(original),target=storage();
 assert.equal(restoreEmpty(target,backup),2);
 assert.deepEqual(target.snapshot(),original.snapshot());
});
test('partial write failure rolls back only new values',()=>{
 const target=storage({unrelated:'keep'},'cp_pend');
 const backup=capture(storage({cp_v2:'old',cp_pend:'1'}));
 assert.throws(()=>restoreEmpty(target,backup),/Quota exceeded/);
 assert.deepEqual(target.snapshot(),{unrelated:'keep'});
});
test('invalid pending marker is rejected by validator',()=>{
 const backup=capture(storage({cp_pend:'1'}));
 backup.entries.cp_pend='other';
 assert.throws(()=>validate(backup),/desconocido/);
});
test('backup validator rejects unexpected storage keys',()=>{
 const backup=capture(storage({cp_v2:'safe'}));
 backup.entries.token='unexpected';
 assert.throws(()=>validate(backup),/inválida/);
});
