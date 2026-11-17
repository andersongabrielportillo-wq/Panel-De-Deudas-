import test from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {capture}=require('../debt-legacy-backup.cjs');
const {encryptBackup,decryptBackup}=require('../debt-encrypted-backup.cjs');
const pass='frase-de-respaldo-larga-y-privada';
const original=capture({getItem:k=>({cp_v2:'{"clientes":["prueba"]}',cp_pend:'1'})[k]??null});
test('cifrar y descifrar conserva los movimientos offline',async()=>{
 const encrypted=await encryptBackup(original,pass,webcrypto);
 assert.equal(encrypted.format,'debt-encrypted-backup-v1');
 assert.ok(!JSON.stringify(encrypted).includes('clientes'));
 assert.deepEqual(await decryptBackup(encrypted,pass,webcrypto),original);
});
test('frase incorrecta y datos alterados no permiten recuperación',async()=>{
 const encrypted=await encryptBackup(original,pass,webcrypto);
 await assert.rejects(decryptBackup(encrypted,'otra-frase-larga-segura',webcrypto));
 const tampered={...encrypted,data:encrypted.data.slice(0,-4)+'AAAA'};
 await assert.rejects(decryptBackup(tampered,pass,webcrypto));
});
test('cifrados sucesivos usan sal e IV distintos',async()=>{
 const a=await encryptBackup(original,pass,webcrypto),b=await encryptBackup(original,pass,webcrypto);
 assert.notEqual(a.salt,b.salt);assert.notEqual(a.iv,b.iv);assert.notEqual(a.data,b.data);
});
test('no acepta frase corta ni parámetros de cifrado modificados',async()=>{
 await assert.rejects(encryptBackup(original,'corta',webcrypto));
 const encrypted=await encryptBackup(original,pass,webcrypto);
 await assert.rejects(decryptBackup({...encrypted,iterations:1},pass,webcrypto));
});
