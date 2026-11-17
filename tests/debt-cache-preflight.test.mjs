import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {inspectDebtCache}=require('../debt-cache-preflight.cjs');
const storage=data=>({getItem:k=>Object.hasOwn(data,k)?data[k]:null});
test('caché limpia no requiere migración',()=>{
 const r=inspectDebtCache(storage({}));assert.equal(r.hasLegacyPlaintext,false);
 assert.equal(r.requiresMigration,false);assert.equal(r.safeToPurge,false);
});
test('detecta caché heredada sin inspeccionar su contenido',()=>{
 const r=inspectDebtCache(storage({cp_v2:'datos personales secretos',cp_v2_bak:'copia'}));
 assert.deepEqual(r.legacyPlaintextKeys,['cp_v2','cp_v2_bak']);
 assert.equal(JSON.stringify(r).includes('datos personales secretos'),false);
 assert.equal(r.requiresMigration,true);
});
test('marca abonos pendientes incluso sin cp_v2',()=>{
 const r=inspectDebtCache(storage({cp_pend:'1'}));
 assert.equal(r.hasPendingChanges,true);assert.equal(r.requiresMigration,true);
 assert.equal(r.safeToPurge,false);
});
test('errores de almacenamiento fallan cerrado',()=>{
 const r=inspectDebtCache({getItem(){throw Error('denegado')}});
 assert.equal(r.storageAccessible,false);assert.equal(r.requiresMigration,true);
});
test('inspección nunca elimina ni modifica almacenamiento',()=>{
 let reads=0;const store={getItem(){reads++;return null},removeItem(){throw Error('NO BORRAR')},setItem(){throw Error('NO ESCRIBIR')}};
 inspectDebtCache(store);assert.ok(reads>0);
});

test('indicadores offline desconocidos requieren migración y revisión',()=>{
 for(const marker of ['pendiente','true','2','']){
  const r=inspectDebtCache(storage({cp_pend:marker}));
  assert.equal(r.storageAccessible,false);
  assert.equal(r.requiresMigration,true);
  assert.equal(r.safeToPurge,false);
 }
});
test('indicador cero reconocido no implica por sí solo migración',()=>{
 const r=inspectDebtCache(storage({cp_pend:'0'}));
 assert.equal(r.storageAccessible,true);
 assert.equal(r.hasPendingChanges,false);
 assert.equal(r.requiresMigration,false);
});
