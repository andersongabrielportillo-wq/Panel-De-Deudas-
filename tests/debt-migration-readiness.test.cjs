'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {assess,captureForReview}=require('../debt-migration-readiness.cjs');
const storage=(obj={})=>({getItem:k=>Object.prototype.hasOwnProperty.call(obj,k)?obj[k]:null});
test('no local data: no migration and no deletion',()=>{const x=assess(storage());assert.equal(x.canStartAssistedMigration,false);assert.equal(x.canDeleteLegacyData,false)});
test('plaintext requires encrypted backup and server sync proof',()=>{const x=assess(storage({cp_v2:'fiction'}));assert.deepEqual(x.blockers,['ENCRYPTED_BACKUP_UNVERIFIED','SERVER_SYNC_UNCONFIRMED']);assert.equal(x.canStartAssistedMigration,false)});
test('pending changes block even with backup and server sync flags',()=>{const x=assess(storage({cp_v2:'fiction',cp_pend:'1'}),{encryptedBackupVerified:true,serverSyncConfirmed:true});assert.equal(x.blockers.includes('UNSYNCED_LOCAL_CHANGES'),true);assert.equal(x.canDeleteLegacyData,false)});
test('unknown pending marker fails closed',()=>{const x=assess(storage({cp_pend:'?'}));assert.equal(x.blockers.includes('PENDING_MARKER_UNKNOWN'),true);assert.throws(()=>captureForReview(storage({cp_pend:'?'})))});
test('unreadable storage fails closed',()=>{const x=assess({getItem:()=>{throw Error('blocked')}});assert.equal(x.blockers.includes('STORAGE_UNREADABLE'),true);assert.equal(x.canStartAssistedMigration,false)});
test('verified clean state allows only assisted migration, never deletion',()=>{const x=assess(storage({cp_v2:'fiction',cp_pend:'0'}),{encryptedBackupVerified:true,serverSyncConfirmed:true});assert.equal(x.canStartAssistedMigration,true);assert.equal(x.canDeleteLegacyData,false);assert.equal(x.requiresExplicitHumanApproval,true)});
test('capture for review preserves pending marker without modifying source',()=>{const data={cp_v2:'fiction',cp_pend:'1'};const x=captureForReview(storage(data));assert.equal(x.entries.cp_pend,'1');assert.deepEqual(data,{cp_v2:'fiction',cp_pend:'1'})});

test('pending-only cache blocks migration and keeps pending marker',()=>{const x=assess(storage({cp_pend:'1'}));assert.equal(x.hasPendingChanges,true);assert.equal(x.canStartAssistedMigration,false);assert.equal(x.canDeleteLegacyData,false)});
test('backup verified without server sync still blocks migration',()=>{const x=assess(storage({cp_v2:'fiction'}),{encryptedBackupVerified:true});assert.deepEqual(x.blockers,['SERVER_SYNC_UNCONFIRMED'])});
test('server sync flag without encrypted backup still blocks migration',()=>{const x=assess(storage({cp_v2:'fiction'}),{serverSyncConfirmed:true});assert.deepEqual(x.blockers,['ENCRYPTED_BACKUP_UNVERIFIED'])});
test('review capture does not invoke writes or deletes',()=>{let writes=0;const s={getItem:k=>k==='cp_v2'?'fiction':null,setItem:()=>{writes++},removeItem:()=>{writes++}};const b=captureForReview(s);assert.equal(b.entries.cp_v2,'fiction');assert.equal(writes,0)});
