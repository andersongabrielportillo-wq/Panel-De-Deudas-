import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const html=readFileSync(new URL('../laboratorio/conectado-lectura.html',import.meta.url),'utf8');
test('el laboratorio apunta solo al proyecto de pruebas',()=>{
 assert.match(html,/const allowedProject="dozcnytevqhoymzqlxah"/);
 assert.match(html,/u\.hostname!==allowedProject\+"\.supabase\.co"/);
 assert.doesNotMatch(html,/josdmjjbnrugiwlwgjky/);
});
test('no contiene claves incrustadas ni escritura de negocio',()=>{
 assert.doesNotMatch(html,/sb_secret_[A-Za-z0-9]+/);
 assert.doesNotMatch(html,/service_role\s*[:=]\s*["'][^"']+["']/);
 assert.match(html,/cl2_sandbox_list/);
 assert.doesNotMatch(html,/rpc\/cl2_sandbox_(delete|test_sale|warranty_release|review_request)/);
});
test('el cliente cierra y detiene la consulta al cerrar sesión',()=>{
 assert.match(html,/setInterval\(refresh,5000\)/);
 assert.match(html,/clearInterval\(poll\)/);
 assert.match(html,/session=null/);
});
