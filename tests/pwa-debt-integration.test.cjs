'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
test('debt gate remains disabled pending coordinated production migration',()=>{assert.match(html,/const DEBT_GATE_ENABLED=false;/)});
test('main PWA wires exact production debt RPC set',()=>{assert.match(html,/createDebtGate\(\{client:SB,workspaceId:SB_WID,rpcNames:\{unlock:'unlock_debts',verify:'has_debts_unlock',lock:'lock_debts'\}\}\)/)});
test('gate verifies server before opening debt data',()=>{assert.match(html,/async function connectDebtData\(reveal=true\)\{/);assert.match(html,/if\(DEBT_GATE_ENABLED&&\(!debtGate\|\|!await debtGate\.verify\(\)\)\)throw Error\("Acceso a Deudas no confirmado por el servidor"\)/)});
test('gate prevents pending cloud writes without authorization',()=>{assert.match(html,/async function cloudSet\(payload\)\{\s*if\(DEBT_GATE_ENABLED&&\(!debtController\|\|!await debtController\.verify\(\)\)\)/)});
test('main PWA retains inventory and debt module hub',()=>{assert.match(html,/clnModuleHub/);assert.match(html,/debtUnlockScreen/)});

test('realtime snapshot rechecks server gate after network read before applying',()=>{
 const callback=html.match(/SB_CH=SB\.channel\("panel-deudas-"\+SB_WID\)[\s\S]*?\.subscribe\(status=>/);
 assert.ok(callback,'Realtime subscription not found');
 const body=callback[0];
 const fetchAt=body.indexOf('const snapshot=await cloudSnapshot()');
 const verifyAt=body.indexOf('await debtController.verify()',fetchAt);
 const applyAt=body.indexOf('onRemote(snapshot)',fetchAt);
 assert.ok(fetchAt>=0&&verifyAt>fetchAt&&applyAt>verifyAt,'Post-read authorization must precede onRemote');
 assert.match(body,/if\(!APP_READY\)return;/);
});

test('initial cloud read cannot repaint debt module after lock or logout',()=>{
 const start=html.indexOf('async function connectDebtData(reveal=true)');
 const end=html.indexOf('async function connectCloud()',start);
 assert.ok(start>=0&&end>start);
 const body=html.slice(start,end);
 const fetchAt=body.indexOf('const first=await cloudSnapshot()');
 const checkAt=body.indexOf('!await debtGate.verify()||!APP_READY',fetchAt);
 const applyAt=body.indexOf('onRemote(first)',fetchAt);
 assert.ok(fetchAt>=0&&checkAt>fetchAt&&applyAt>checkAt);
});
test('production gate cannot be enabled before cache migration is ready',()=>{
 assert.match(html,/const DEBT_GATE_ENABLED=false;/);
 assert.match(html,/inspectDebtCache\(localStorage\)/);
 assert.match(html,/safeToPurge===true/);
});

test('cloud write revalidates authorization after the preliminary read',()=>{
 const start=html.indexOf('async function cloudSet(payload)');
 const end=html.indexOf('// Corte de Deudas requiere migración',start);
 assert.ok(start>=0&&end>start);
 const body=html.slice(start,end);
 const readAt=body.indexOf('.select("id")');
 const verifyAt=body.indexOf('await debtController.verify()',readAt);
 const updateAt=body.indexOf('.update({data:state',readAt);
 const insertAt=body.indexOf('.insert({id:"__shared_state__"',readAt);
 assert.ok(readAt>=0&&verifyAt>readAt&&updateAt>verifyAt&&insertAt>verifyAt);
 assert.match(body,/!APP_READY/);
});

test('encrypted pre-cutover backup is available to signed-in users without enabling the debt gate',()=>{
 assert.match(html,/debtBackupButton\.hidden=false/);
 assert.match(html,/debtRecoveryButton\.hidden=false/);
 assert.match(html,/if\(!APP_READY\|\|!SB_UID\|\|\(DEBT_GATE_ENABLED&&\(!debtController\|\|!await debtController\.verify\(\)\)\)\)/);
 assert.match(html,/const backup=window\.DebtLegacyBackup\.capture\(localStorage\)/);
 assert.match(html,/window\.DebtEncryptedBackup\.encryptBackup\(backup,pass\)/);
 assert.match(html,/Verificar respaldo cifrado \(sin restaurar\)/);
});

test('pre-cutover encrypted backup verification does not require an uninitialized gate controller',()=>{
 const start=html.indexOf('debtRecoveryInput.onchange=async()=>');
 const end=html.indexOf('document.getElementById("clnHubDebts").onclick',start);
 assert.ok(start>=0&&end>start);
 const body=html.slice(start,end);
 assert.match(body,/DebtEncryptedBackup\.decryptBackup\(envelope,pass\)/);
 assert.match(body,/if\(!APP_READY\|\|!SB_UID\|\|\(DEBT_GATE_ENABLED&&\(!debtController\|\|!await debtController\.verify\(\)\)\)\)throw Error\("Autorización caducada"\)/);
 assert.doesNotMatch(body,/if\(!await debtController\.verify\(\)\)throw Error\("Autorización caducada"\)/);
});

test('pre-cutover export explicitly warns that a browser backup is not a cloud backup',()=>{
 assert.match(html,/Respaldo SOLO de los datos locales de este navegador; NO sustituye una copia de la nube/);
 assert.match(html,/Respaldo LOCAL cifrado preparado/);
 assert.match(html,/conserva otra copia de la nube/);
});

test('backup export verifies encrypted roundtrip before creating downloadable file',()=>{
 const start=html.indexOf('debtBackupButton.onclick=async()=>');
 const end=html.indexOf('const debtRecoveryInput=',start);
 assert.ok(start>=0&&end>start);
 const body=html.slice(start,end);
 const encrypted=body.indexOf('DebtEncryptedBackup.encryptBackup(backup,pass)');
 const verified=body.indexOf('DebtEncryptedBackup.decryptBackup(encrypted,pass)');
 const compared=body.indexOf('JSON.stringify(verified)!==JSON.stringify(backup)');
 const downloaded=body.indexOf('new Blob([JSON.stringify(encrypted)]');
 assert.ok(encrypted>=0&&verified>encrypted&&compared>verified&&downloaded>compared);
});

test('pre-cutover backup refuses empty local data and warns on unsynced debt edits',()=>{
 const start=html.indexOf('debtBackupButton.onclick=async()=>');
 const end=html.indexOf('const debtRecoveryInput=',start);
 assert.ok(start>=0&&end>start);
 const body=html.slice(start,end);
 assert.match(body,/Object\.keys\(backup\.entries\)\.some\(key=>key!=="cp_pend"\)/);
 assert.match(body,/backup\.entries\.cp_pend==="1"/);
 assert.match(body,/no migres ni borres la caché/);
 assert.ok(body.indexOf('Object.keys(backup.entries).some(key=>key!=="cp_pend")')<body.indexOf('DebtEncryptedBackup.encryptBackup(backup,pass)'));
});

test('backup export detects local changes while encryption is running',()=>{
 const start=html.indexOf('debtBackupButton.onclick=async()=>');
 const end=html.indexOf('const debtRecoveryInput=',start);
 assert.ok(start>=0&&end>start);
 const body=html.slice(start,end);
 assert.match(body,/const current=window\.DebtLegacyBackup\.capture\(localStorage\)/);
 assert.match(body,/JSON\.stringify\(current\.entries\)!==JSON\.stringify\(backup\.entries\)/);
 assert.ok(body.indexOf('const current=window.DebtLegacyBackup.capture(localStorage)')<body.indexOf('new Blob([JSON.stringify(encrypted)]'));
});

test('remote SIGNED_OUT invalidates all module state and private views',()=>{
 const start=html.indexOf('SB.auth.onAuthStateChange((event,session)=>');
 const end=html.indexOf('startAuth();',start);
 assert.ok(start>=0&&end>start);
 const body=html.slice(start,end);
 for(const marker of [
   'authSessionGeneration++','nexusViewEpoch++','nexusReader.reset()',
   'debtController.cancel()','debtGate.reset()',
   'SB_UID=null;SB_WID=null;SY.doc=null',
   'SB.removeChannel(old)','clnHubDetail").replaceChildren()',
   'debtUnlockPassword").value=""','showModuleHub(false)','hidePrivate()'
 ])assert.ok(body.includes(marker),'Expected SIGNED_OUT cleanup: '+marker);
 assert.doesNotMatch(body,/localStorage\.clear\(|\["cp_v2"/);
});
test('stale membership and cloud reads are rejected after logout',()=>{
 const member=html.slice(html.indexOf('async function connectCloud()'),html.indexOf('// Manual encrypted backup'));
 const reader=html.slice(html.indexOf('async function connectDebtData(reveal=true)'),html.indexOf('async function connectCloud()'));
 assert.match(member,/const startingUser=SB_UID,startingGeneration=authSessionGeneration/);
 assert.match(member,/SB_UID!==startingUser\|\|startingGeneration!==authSessionGeneration/);
 const fetched=reader.indexOf('const first=await cloudSnapshot()');
 const stale=reader.indexOf('authSessionGeneration!==startingGeneration',fetched);
 const applied=reader.indexOf('onRemote(first)',fetched);
 assert.ok(fetched>=0&&stale>fetched&&applied>stale,'Must reject stale read before applying data');
 assert.match(reader,/DEBT_GATE_ENABLED&&SB_UID===startingUser&&authSessionGeneration===startingGeneration/);
});
