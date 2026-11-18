import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
test('pantalla de Deudas está presente con campos y estado accesibles',()=>{
 for(const id of ['debtUnlockScreen','debtUnlockPassword','debtUnlockButton','debtUnlockError','debtUnlockLogout'])
  assert.match(html,new RegExp('id="'+id+'"'));
 assert.match(html,/aria-live="polite"/);
});
test('scripts de seguridad cargan antes del script principal de la PWA',()=>{
 const gate=html.indexOf('<script src="./debt-gate-client.cjs"></script>');
 const ctrl=html.indexOf('<script src="./debt-module-controller.cjs"></script>');
 const cache=html.indexOf('<script src="./debt-cache-preflight.cjs"></script>');
 const main=html.indexOf('<script>\n\/\/ Versión pública segura');
 assert.ok(gate>=0&&ctrl>gate&&cache>ctrl&&main>cache);
});
test('corte de seguridad está desactivado hasta RLS productivo',()=>{
 assert.match(html,/const DEBT_GATE_ENABLED=false;/);
 assert.match(html,/if\(!DEBT_GATE_ENABLED\)\{await connectDebtData\(\);return\}/);
});
test('rama de acceso gated no revela panel durante carga previa a segunda verificación',()=>{
 assert.match(html,/await connectDebtData\(false\)/);
 assert.match(html,/if\(reveal\)\{showPrivate\(\);gate\(false\);debtScreenVisible\(false\)\}/);
 assert.match(html,/show:\(\)=>\{showPrivate\(\);debtScreenVisible\(false\)/);
});
test('la contraseña adicional se limpia del campo después de enviarla',()=>{
 assert.match(html,/const password=input.value;input.value="";button.disabled=true/);
});
test('cierre de sesión cancela gate y revoca estado local',()=>{
 assert.match(html,/if\(debtController\)\{debtController.cancel\(\);debtController=null\}/);
});

test('pantalla incorpora botón de bloqueo explícito y lo oculta si el gate está apagado',()=>{
 assert.match(html,/id="debtLockButton" type="button" hidden/);
 assert.ok(html.includes('document.getElementById("debtLockButton").hidden=!DEBT_GATE_ENABLED||yes'));
 assert.ok(html.includes('await debtController.lock()'));
});
test('consultas y escrituras cloud requieren autorización al habilitar gate',()=>{
 assert.match(html,/async function cloudSnapshot\(\)\{\s*if\(DEBT_GATE_ENABLED/);
 assert.match(html,/async function cloudSet\(payload\)\{\s*if\(DEBT_GATE_ENABLED/);
 assert.ok(html.includes('debtGate.isUnlocked()'));
});

test('el flujo protegido verifica al servidor antes de cargar caché y después de recibir nube',()=>{
 const start=html.indexOf('async function connectDebtData(reveal=true)');
 const end=html.indexOf('async function connectCloud()',start);
 assert.ok(start>=0&&end>start);
 const flow=html.slice(start,end);
 const verify=flow.indexOf('await debtGate.verify()');
 const load=flow.indexOf('loadPrivate()');
 const snapshot=flow.indexOf('await cloudSnapshot()');
 const reverify=flow.indexOf('await debtGate.verify()',verify+1);
 const apply=flow.indexOf('onRemote(first)');
 assert.ok(verify>=0&&verify<load,'verificar antes de leer caché');
 assert.ok(snapshot>load&&reverify>snapshot&&reverify<apply,'revalidar antes de aplicar nube');
});

test('caché heredada y cambios offline se bloquean cuando Deudas exige autorización',()=>{
 assert.match(html,/function loadPrivate\(\)\{if\(DEBT_GATE_ENABLED&&\(!debtGate\|\|!debtGate\.isUnlocked\(\)\)\)throw Error/);
 assert.match(html,/async function push\(\)\{[\s\S]*?if\(DEBT_GATE_ENABLED&&\(!debtController\|\|!await debtController\.verify\(\)\)\)/);
 assert.match(html,/window\.addEventListener\("storage",e=>\{if\(!APP_READY\|\|\(DEBT_GATE_ENABLED&&\(!debtGate\|\|!debtGate\.isUnlocked\(\)\)\)/);
});

test('respaldo cifrado solo se ofrece en la vista de Deudas protegida',()=>{
 assert.ok(html.includes('<script src="./debt-legacy-backup.cjs"></script>'));
 assert.ok(html.includes('<script src="./debt-encrypted-backup.cjs"></script>'));
 assert.ok(html.includes('debtBackupButton.hidden=!DEBT_GATE_ENABLED'));
 assert.ok(html.includes('!await debtController.verify()'));
 assert.ok(html.includes('DebtLegacyBackup.capture(localStorage)'));
 assert.ok(html.includes('DebtEncryptedBackup.encryptBackup(backup,pass)'));
});

test('verificación de respaldo no modifica almacenamiento local',()=>{
 assert.ok(html.includes('debtRecoveryButton.textContent="Verificar respaldo cifrado (sin restaurar)"'));
 const start=html.indexOf('debtRecoveryInput.onchange=async()=>');
 const end=html.indexOf('document.getElementById("clnHubDebts").onclick',start);
 assert.ok(start>0&&end>start);
 const handler=html.slice(start,end);
 assert.ok(handler.includes('DebtEncryptedBackup.decryptBackup(envelope,pass)'));
 assert.ok(!handler.includes('restoreEmpty('));
 assert.ok(!handler.includes('localStorage.setItem('));
 assert.ok(!handler.includes('localStorage.removeItem('));
 assert.ok(handler.includes('file.size>20*1024*1024'));
});

test('fallo de carga protegida desconecta Realtime y limpia estado en memoria',()=>{
 const start=html.indexOf('async function connectDebtData(reveal=true)');
 const end=html.indexOf('async function connectCloud()',start);
 const flow=html.slice(start,end);
 assert.ok(flow.includes('}catch(error){'));
 assert.ok(flow.includes('if(DEBT_GATE_ENABLED){'));
 assert.ok(flow.includes('await disconnectDebtChannel()'));
 assert.ok(flow.includes('hidePrivate()'));
 assert.ok(flow.includes('debtScreenVisible(true,'));
 assert.ok(flow.includes('throw error;'));
});

test('respuesta tardía de sincronización no borra pendientes después de bloqueo',()=>{
 const start=html.indexOf('async function push()');
 const end=html.indexOf('function uiRefresh()',start);
 const flow=html.slice(start,end);
 assert.ok(flow.includes('const activeState=S,sg=sig(S),rev=S.rev'));
 assert.ok(flow.includes('if(DEBT_GATE_ENABLED&&(!APP_READY||S!==activeState||!debtGate||!debtGate.isUnlocked()))return'));
 assert.ok(flow.indexOf('S!==activeState')<flow.indexOf('lsDel("cp_pend")'));
});
