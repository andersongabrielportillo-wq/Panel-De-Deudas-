import test from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {capture,restoreEmpty}=require('../debt-legacy-backup.cjs');
const {encryptBackup,decryptBackup}=require('../debt-encrypted-backup.cjs');
function storage(initial={}){
 const values={...initial};
 return {values,getItem:k=>Object.hasOwn(values,k)?values[k]:null,setItem:(k,v)=>{values[k]=v},removeItem:k=>{delete values[k]}};
}
test('flujo aislado: respaldo cifrado y recuperación conserva deuda y pago pendiente',async()=>{
 const original=storage({
  cp_v2:JSON.stringify({debts:[{id:'ficticia-01',balance:100}],tx:[{id:'abono-01',amount:20}],rev:5}),
  cp_v2_bak:'copia-ficticia-anterior',cp_pend:'1'
 });
 const originalSnapshot={...original.values};
 const envelope=await encryptBackup(capture(original),'frase-larga-para-pruebas-2026',webcrypto);
 assert.ok(!JSON.stringify(envelope).includes('abono-01'));
 const restored=await decryptBackup(envelope,'frase-larga-para-pruebas-2026',webcrypto);
 const isolated=storage();
 assert.equal(restoreEmpty(isolated,restored),3);
 assert.deepEqual(isolated.values,originalSnapshot);
 assert.deepEqual(original.values,originalSnapshot);
 assert.equal(isolated.getItem('cp_pend'),'1');
});
test('flujo aislado: recuperación rechazada si ya existe abono local',async()=>{
 const backup=capture(storage({cp_v2:'respaldo',cp_pend:'1'}));
 const destination=storage({cp_v2:'movimiento-nuevo'});
 assert.throws(()=>restoreEmpty(destination,backup),/existen datos/);
 assert.deepEqual(destination.values,{cp_v2:'movimiento-nuevo'});
});
