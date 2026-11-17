import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
test('hub de módulos está fuera del contenedor privado de Deudas',()=>{
 const hub=html.indexOf('id="clnModuleHub"');
 const debts=html.indexOf('id="debtUnlockScreen"');
 const privateApp=html.indexOf('id="privateApp"');
 assert.ok(hub>0&&hub<debts&&debts<privateApp);
});
test('hub ofrece módulos independientes con botón de acceso a Deudas',()=>{
 for(const id of ['clnHubDebts','clnHubInventory','clnHubWarranties','clnHubContracts','clnHubLogout','clnHubStatus'])
  assert.ok(html.includes('id="'+id+'"'));
 assert.ok(html.includes('document.getElementById("clnHubDebts").onclick=()=>debtScreenVisible(true)'));
});
test('hub no accede a caché ni realiza consultas de deudas',()=>{
 const start=html.indexOf('function openIndependentModule(id)');
 const end=html.indexOf('document.getElementById("debtUnlockButton")',start);
 const handler=html.slice(start,end);
 assert.ok(start>0&&end>start);
 for(const forbidden of ['loadPrivate(','cloudSnapshot(','cloudSet(','localStorage','SB.from(','SB.rpc('])
  assert.equal(handler.includes(forbidden),false,forbidden);
});
test('hub solo se habilitará al activar gate con migración coordinada',()=>{
 assert.ok(html.includes('const DEBT_GATE_ENABLED=false'));
 assert.ok(html.includes('if(!DEBT_GATE_ENABLED){await connectDebtData();return}'));
 assert.ok(html.includes('showModuleHub(true)'));
});

test('vistas independientes tienen secciones reales de interfaz sin consultar Deudas',()=>{
 assert.ok(html.includes('id="clnHubDetail"'));
 assert.ok(html.includes('function openIndependentModule(id)'));
 const start=html.indexOf('function openIndependentModule(id)');
 const end=html.indexOf('document.getElementById("debtUnlockButton")',start);
 const code=html.slice(start,end);
 for(const forbidden of ['loadPrivate(', 'cloudSnapshot(', 'cloudSet(', 'localStorage', 'SB.from(', 'SB.rpc('])
  assert.equal(code.includes(forbidden),false,forbidden);
 assert.ok(code.includes('if(!config||!SB_UID||!DEBT_GATE_ENABLED)return'));
});
test('vistas de hub solo muestran interfaz informativa sin operaciones reales',()=>{
 assert.ok(html.includes('Consultas y operaciones desactivadas hasta verificar los permisos'));
 assert.ok(html.includes('clnHubDetail.replaceChildren()'));
});

test('volver a módulos limpia contraseña sin leer Deudas',()=>{
 assert.ok(html.includes('id="debtUnlockBack"'));
 assert.ok(html.includes('document.getElementById("debtUnlockPassword").value="";showModuleHub(true)'));
});
test('logout desde hub respeta marca persistente de cambios offline',()=>{
 assert.ok(html.includes('cacheAudit=window.DebtCachePreflight?.inspectDebtCache(localStorage)||null'));
 assert.ok(html.includes('catch(_){cacheAudit=null}'));
 assert.ok(html.includes('const offlinePending=SY.pend||!cacheAudit||!cacheAudit.storageAccessible||cacheAudit.hasPendingChanges'));
 assert.ok(html.includes('if(offlinePending&&!confirm('));
 assert.ok(html.includes('const pending=offlinePending;'));
 assert.ok(html.includes('if(!pending&&cacheAudit?.safeToPurge===true){["cp_v2"'));
});

test('la caché heredada no se purga por cp_pend=0 ni por ausencia de error',()=>{
 assert.ok(html.includes('cacheAudit?.safeToPurge===true'));
 assert.ok(!html.includes('if(!pending&&cacheAudit&&cacheAudit.storageAccessible){'));
});
