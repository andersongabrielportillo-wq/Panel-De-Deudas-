/* Read-only preflight for legacy Deudas offline cache. Never logs or deletes payloads. */
(function(root){'use strict';
const KEYS=Object.freeze(['cp_v2','cp_v2_bak','cp_v2_corrupt','cp_prev','cp_items']);
function inspectDebtCache(storage){
 if(!storage||typeof storage.getItem!=='function')throw Error('Almacenamiento inválido');
 const present=[],errors=[];
 for(const key of KEYS){
  try{if(storage.getItem(key)!==null)present.push(key)}
  catch(_){errors.push(key)}
 }
 let pending=false,unknown=false;
 try{const marker=storage.getItem('cp_pend');pending=marker==='1';if(marker!==null&&marker!=='0'&&marker!=='1')unknown=true}catch(_){unknown=true}
 return Object.freeze({
  legacyPlaintextKeys:Object.freeze(present),
  hasLegacyPlaintext:present.length>0,
  hasPendingChanges:pending,
  hasUnknownPendingMarker:unknown,
  inaccessibleKeys:Object.freeze(errors),
  storageAccessible:errors.length===0&&!unknown,
  safeToPurge:false, // Never infer that sync completed from cp_pend alone.
  requiresMigration:present.length>0||pending||errors.length>0||unknown
 });
}
const api=Object.freeze({inspectDebtCache,LEGACY_KEYS:KEYS});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.DebtCachePreflight=api;
})(typeof window!=='undefined'?window:null);
