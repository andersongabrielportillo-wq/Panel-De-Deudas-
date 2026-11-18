/* Synthetic encrypted backup tests. No real user data or secrets. */
'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {webcrypto}=require('node:crypto');
const {capture,restoreEmpty}=require('../debt-legacy-backup.cjs');
const {encryptBackup,decryptBackup}=require('../debt-encrypted-backup.cjs');
const pass='example-only-long-passphrase-for-tests';
function storage(initial={}){
 const map=new Map(Object.entries(initial));
 return {getItem:k=>map.has(k)?map.get(k):null,setItem:(k,v)=>map.set(k,String(v)),removeItem:k=>map.delete(k),snapshot:()=>Object.fromEntries(map)};
}
test('encrypted round trip preserves all keys including pending changes',async()=>{
 const original=storage({cp_v2:'{"saldo":123}',cp_v2_bak:'previous',cp_pend:'1'});
 const backup=capture(original);
 const encrypted=await encryptBackup(backup,pass,webcrypto);
 assert.equal(encrypted.format,'debt-encrypted-backup-v1');
 assert.equal(JSON.stringify(encrypted).includes('saldo'),false);
 const decrypted=await decryptBackup(encrypted,pass,webcrypto);
 assert.deepEqual(decrypted,backup);
 const target=storage();
 assert.equal(restoreEmpty(target,decrypted),3);
 assert.deepEqual(target.snapshot(),original.snapshot());
});
test('wrong passphrase cannot decrypt',async()=>{
 const encrypted=await encryptBackup(capture(storage({cp_v2:'synthetic'})),pass,webcrypto);
 await assert.rejects(decryptBackup(encrypted,'another-example-test-passphrase',webcrypto),/incorrecta|alterado/);
});
test('tampered ciphertext cannot decrypt',async()=>{
 const encrypted=await encryptBackup(capture(storage({cp_v2:'synthetic'})),pass,webcrypto);
 const raw=Buffer.from(encrypted.data,'base64');raw[0]^=1;
 await assert.rejects(decryptBackup({...encrypted,data:raw.toString('base64')},pass,webcrypto),/incorrecta|alterado/);
});
test('malformed encryption metadata is rejected',async()=>{
 const encrypted=await encryptBackup(capture(storage({cp_v2:'synthetic'})),pass,webcrypto);
 await assert.rejects(decryptBackup({...encrypted,iterations:1},pass,webcrypto),/Formato cifrado/);
});
test('short passphrase is rejected',async()=>{
 await assert.rejects(encryptBackup(capture(storage()),'short',webcrypto),/mínimo 12/);
});
test('different exports use distinct salts and IVs',async()=>{
 const backup=capture(storage({cp_v2:'synthetic'}));
 const a=await encryptBackup(backup,pass,webcrypto),b=await encryptBackup(backup,pass,webcrypto);
 assert.notEqual(a.salt,b.salt);
 assert.notEqual(a.iv,b.iv);
});
