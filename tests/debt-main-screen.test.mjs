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
