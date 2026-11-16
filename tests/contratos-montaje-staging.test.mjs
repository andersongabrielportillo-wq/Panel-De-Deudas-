import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const codigo=readFileSync(new URL('../prototipos/contratos-montaje-staging.js',import.meta.url),'utf8');

test('montaje exige sesión del anfitrión',()=>{
 assert.match(codigo,/supabase\.auth\.getUser\(\)/);
 assert.match(codigo,/data\?\.user\?\.id/);
});
test('montaje comprueba permiso RPC antes de crear interfaz',()=>{
 const permiso=codigo.indexOf("supabase.rpc('inv_catalogo_vendedores')");
 const montar=codigo.indexOf('iniciarContratosDemo({supabase,root:contenedor})');
 assert.ok(permiso>=0 && montar>permiso);
});
test('montaje evita dobles clics y limpia reserva en caso de error',()=>{
 assert.match(codigo,/const montajes=new WeakMap\(\)/);
 assert.match(codigo,/montajes\.set\(contenedor,pendiente\)/);
 assert.match(codigo,/montajes\.delete\(contenedor\)/);
});
test('montaje no contiene credenciales incrustadas',()=>{
 assert.doesNotMatch(codigo,/\b(?:createClient|supabaseUrl|supabaseKey)\s*\(|https:\/\/[^\s]+\.supabase\.co/);
});

test('montaje revalida que no cambió el usuario durante el permiso',()=>{
 assert.match(codigo,/const usuarioInicial=data\.user\.id/);
 assert.match(codigo,/const \{data:sesionFinal,error:errorFinal\}=await supabase\.auth\.getUser\(\)/);
 assert.match(codigo,/sesionFinal\.user\.id!==usuarioInicial/);
});
