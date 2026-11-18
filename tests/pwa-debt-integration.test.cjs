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
