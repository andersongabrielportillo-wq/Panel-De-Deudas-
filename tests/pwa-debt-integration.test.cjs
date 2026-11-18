'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'..','index.html'),'utf8');
test('debt gate remains disabled pending coordinated production migration',()=>{assert.match(html,/const DEBT_GATE_ENABLED=false;/)});
test('main PWA wires exact production debt RPC set',()=>{assert.match(html,/createDebtGate\(\{client:SB,workspaceId:SB_WID,rpcNames:\{unlock:'debt_unlock',verify:'debt_access_valid',lock:'debt_lock'\}\}\)/)});
test('gate verifies server before opening debt data',()=>{assert.match(html,/async function connectDebtData\(reveal=true\)\{\s*if\(DEBT_GATE_ENABLED&&\(!debtGate\|\|!await debtGate\.verify\(\)\)\)/)});
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
