import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {capture,validate,restoreEmpty}=require('../debt-legacy-backup.cjs');
function store(initial={}){
 const data={...initial};
 return {data,getItem:k=>Object.hasOwn(data,k)?data[k]:null,setItem:(k,v)=>{data[k]=v},removeItem:k=>{delete data[k]}};
}
test('respalda abonos pendientes y copias sin modificar origen',()=>{
 const s=store({cp_v2:'{"deudas":[]}',cp_v2_bak:'anterior',cp_pend:'1'});
 const before={...s.data},b=capture(s);
 assert.equal(b.entries.cp_pend,'1');assert.equal(b.entries.cp_v2_bak,'anterior');
 assert.deepEqual(s.data,before);assert.equal(validate(b),true);
});
test('restauración únicamente en almacenamiento vacío',()=>{
 const original=store({cp_v2:'datos',cp_pend:'1'}),backup=capture(original),target=store();
 assert.equal(restoreEmpty(target,backup),2);assert.deepEqual(target.data,original.data);
});
test('nunca sobrescribe datos locales existentes, ni parcialmente',()=>{
 const backup=capture(store({cp_v2:'viejo',cp_pend:'1'})),target=store({cp_pend:'nuevo'});
 assert.throws(()=>restoreEmpty(target,backup),/existen datos/);
 assert.deepEqual(target.data,{cp_pend:'nuevo'});
});
test('rechaza claves no permitidas y formatos desconocidos',()=>{
 assert.throws(()=>validate({format:'otro',entries:{}}));
 assert.throws(()=>validate({format:'debt-legacy-backup-v1',entries:{password:'secreto'}}));
});
test('un error de escritura no deja restauración parcial cuando hay removeItem',()=>{
 const target=store(),backup=capture(store({cp_v2:'datos',cp_pend:'1'}));
 const set=target.setItem;target.setItem=(k,v)=>{if(k==='cp_pend')throw Error('sin espacio');set(k,v)};
 assert.throws(()=>restoreEmpty(target,backup),/sin espacio/);
 assert.deepEqual(target.data,{});
});
