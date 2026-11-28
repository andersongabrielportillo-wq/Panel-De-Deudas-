/* Encrypted export of legacy Deudas backup. Never persist passphrase or plaintext export. */
(function(root){'use strict';
const te=new TextEncoder(),td=new TextDecoder();
const b64=bytes=>{if(typeof Buffer!=='undefined')return Buffer.from(bytes).toString('base64');let s='';for(const b of bytes)s+=String.fromCharCode(b);return btoa(s)};
const un64=s=>{if(typeof s!=='string'||!/^[A-Za-z0-9+/]*={0,2}$/.test(s)||s.length%4)throw Error('Base64 inválido');if(typeof Buffer!=='undefined')return new Uint8Array(Buffer.from(s,'base64'));return Uint8Array.from(atob(s),c=>c.charCodeAt(0))};
function engine(cryptoImpl){const c=cryptoImpl||(typeof crypto!=='undefined'?crypto:null);if(!c||!c.subtle||!c.getRandomValues)throw Error('Web Crypto no disponible');return c}
async function derive(c,pass,salt){const material=await c.subtle.importKey('raw',te.encode(pass),'PBKDF2',false,['deriveKey']);return c.subtle.deriveKey({name:'PBKDF2',salt,iterations:310000,hash:'SHA-256'},material,{name:'AES-GCM',length:256},false,['encrypt','decrypt'])}
function checkPass(pass){if(typeof pass!=='string'||pass.length<12)throw Error('Frase de respaldo demasiado corta (mínimo 12 caracteres)')}
async function encryptBackup(backup,pass,cryptoImpl){
 checkPass(pass);
 if(!root?.DebtLegacyBackup&&typeof module==='undefined')throw Error('Validador no disponible');
 const validator=typeof module!=='undefined'&&module.exports?require('./debt-legacy-backup.cjs'):root.DebtLegacyBackup;
 validator.validate(backup);
 const c=engine(cryptoImpl),salt=c.getRandomValues(new Uint8Array(16)),iv=c.getRandomValues(new Uint8Array(12));
 const key=await derive(c,pass,salt);
 const cipher=await c.subtle.encrypt({name:'AES-GCM',iv},key,te.encode(JSON.stringify(backup)));
 return {format:'debt-encrypted-backup-v1',kdf:'PBKDF2-SHA256',iterations:310000,cipher:'AES-256-GCM',salt:b64(salt),iv:b64(iv),data:b64(new Uint8Array(cipher))};
}
async function decryptBackup(envelope,pass,cryptoImpl){
 checkPass(pass);
 if(!envelope||envelope.format!=='debt-encrypted-backup-v1'||envelope.kdf!=='PBKDF2-SHA256'||envelope.iterations!==310000||envelope.cipher!=='AES-256-GCM')throw Error('Formato cifrado no admitido');
 const salt=un64(envelope.salt),iv=un64(envelope.iv),data=un64(envelope.data);
 if(salt.length!==16||iv.length!==12||data.length<16)throw Error('Respaldo cifrado inválido');
 const c=engine(cryptoImpl),key=await derive(c,pass,salt);
 let plaintext;try{plaintext=await c.subtle.decrypt({name:'AES-GCM',iv},key,data)}catch(_){throw Error('Frase incorrecta o respaldo alterado')}
 const backup=JSON.parse(td.decode(plaintext));
 const validator=typeof module!=='undefined'&&module.exports?require('./debt-legacy-backup.cjs'):root.DebtLegacyBackup;
 validator.validate(backup);
 return backup;
}
const api=Object.freeze({encryptBackup,decryptBackup});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.DebtEncryptedBackup=api;
})(typeof window!=='undefined'?window:null);
