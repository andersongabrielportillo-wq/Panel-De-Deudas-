/* Read-only migration readiness assessment. Never delete, overwrite or sync debt records. */
(function(root){'use strict';
const preflight=typeof module!=='undefined'&&module.exports?require('./debt-cache-preflight.cjs'):root.DebtCachePreflight;
const legacy=typeof module!=='undefined'&&module.exports?require('./debt-legacy-backup.cjs'):root.DebtLegacyBackup;
function assess(storage,{encryptedBackupVerified=false,serverSyncConfirmed=false}={}){
 const state=preflight.inspectDebtCache(storage);
 const blockers=[];
 if(!state.storageAccessible)blockers.push('STORAGE_UNREADABLE');
 if(state.hasUnknownPendingMarker)blockers.push('PENDING_MARKER_UNKNOWN');
 if(state.hasPendingChanges)blockers.push('UNSYNCED_LOCAL_CHANGES');
 if(state.hasLegacyPlaintext&&!encryptedBackupVerified)blockers.push('ENCRYPTED_BACKUP_UNVERIFIED');
 if(state.hasLegacyPlaintext&&!serverSyncConfirmed)blockers.push('SERVER_SYNC_UNCONFIRMED');
 // No automatic deletion is permitted even after all prerequisites are satisfied.
 return Object.freeze({
  ...state,
  blockers:Object.freeze([...new Set(blockers)]),
  canStartAssistedMigration:blockers.length===0&&state.hasLegacyPlaintext,
  canDeleteLegacyData:false,
  requiresExplicitHumanApproval:state.hasLegacyPlaintext
 });
}
function captureForReview(storage){
 const state=preflight.inspectDebtCache(storage);
 if(!state.storageAccessible)throw Error('Almacenamiento inaccesible o marcador inválido');
 // Capture is read-only; this object contains sensitive plaintext and must be encrypted immediately.
 const backup=legacy.capture(storage);
 legacy.validate(backup);
 return backup;
}
const api=Object.freeze({assess,captureForReview});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.DebtMigrationReadiness=api;
})(typeof window!=='undefined'?window:null);
