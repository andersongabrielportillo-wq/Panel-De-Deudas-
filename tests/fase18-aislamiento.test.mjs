import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const app=readFileSync(new URL('../index.html',import.meta.url),'utf8');
const lab=readFileSync(new URL('../laboratorio/conectado-lectura.html',import.meta.url),'utf8');

test('PWA principal conserva login y cierre de sesión',()=>{
 assert.match(app,/id="authGate"/);
 assert.match(app,/signInWithPassword/);
 assert.match(app,/auth\.signOut\(/);
});
test('PWA principal no se conecta accidentalmente al sandbox',()=>{
 assert.doesNotMatch(app,/dozcnytevqhoymzqlxah/);
});
test('laboratorio no se conecta accidentalmente a producción',()=>{
 assert.match(lab,/dozcnytevqhoymzqlxah/);
 assert.doesNotMatch(lab,/josdmjjbnrugiwlwgjky/);
});
test('laboratorio conserva lectura exclusivamente y no incorpora escritura de inventario',()=>{
 assert.match(lab,/rpc\/cl2_sandbox_list/);
 assert.doesNotMatch(lab,/rpc\/cl2_sandbox_(test_sale|delete|review_request|warranty_release)/);
});
test('no declarar montaje CL Nexus antes de existir integración verificable',()=>{
 // Esta prueba sirve como guardia documental; NO acredita integración.
 assert.match(app,/const SUPABASE_URL=/);
 assert.match(lab,/SOLO PRUEBAS/);
});
