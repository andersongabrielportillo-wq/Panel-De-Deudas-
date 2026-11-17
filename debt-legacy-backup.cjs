/* Explicit, non-destructive backup for legacy Deudas cache. No automatic migration or deletion. */
(function(root){'use strict';
const KEYS=Object.freeze(['cp_v2','cp_v2_bak','cp_v2_corrupt','cp_prev','cp_items','cp_pend']);
function capture(storage){
 if(!storage||typeof storage.getItem!=='function')throw Error('Almacenamiento inválido');
 const entries=Object.create(null);
 for(const key of KEYS){
  const value=storage.getItem(key);
  if(value!==null){if(typeof value!=='string')throw Error('Dato local inválido');entries[key]=value}
 }
 return {format:'debt-legacy-backup-v1',createdAt:new Date().toISOString(),entries};
}
function validate(backup){
 if(!backup||backup.format!=='debt-legacy-backup-v1'||!backup.entries||typeof backup.entries!=='object'||Array.isArray(backup.entries))throw Error('Respaldo inválido');
 for(const key of Object.keys(backup.entries)){
  if(!KEYS.includes(key)||!Object.prototype.hasOwnProperty.call(backup.entries,key)||typeof backup.entries[key]!=='string')throw Error('Entrada de respaldo inválida');
 }
 return true;
}
function restoreEmpty(storage,backup){
 validate(backup);
 if(!storage||typeof storage.getItem!=='function'||typeof storage.setItem!=='function')throw Error('Almacenamiento inválido');
 const keys=Object.keys(backup.entries);
 // Preflight ALL keys before writing ANY: never overwrite local edits.
 for(const key of keys)if(storage.getItem(key)!==null)throw Error('Restauración detenida: existen datos locales');
 const written=[];
 try{for(const key of keys){written.push(key);storage.setItem(key,backup.entries[key]);if(storage.getItem(key)!==backup.entries[key])throw Error('No se pudo verificar la restauración')}}
 catch(err){
  // Best effort rollback of newly created entries only. Never touch preexisting data.
  if(typeof storage.removeItem==='function')for(const key of written.reverse())try{if(storage.getItem(key)===backup.entries[key])storage.removeItem(key)}catch(_){}
  throw err;
 }
 return keys.length;
}
const api=Object.freeze({capture,validate,restoreEmpty,KEYS});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.DebtLegacyBackup=api;
})(typeof window!=='undefined'?window:null);
