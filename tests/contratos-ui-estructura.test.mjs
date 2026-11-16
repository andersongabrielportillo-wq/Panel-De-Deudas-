import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const ui=readFileSync(new URL('../prototipos/contratos-ui-conectada.js',import.meta.url),'utf8');
const count=(pattern)=>(ui.match(pattern)||[]).length;

test('el controlador de contratos no está duplicado',()=>{
 assert.equal(count(/export function iniciarContratosDemo\(/g),1);
 assert.equal(count(/crearCliente\.onclick\s*=/g),1);
 assert.equal(count(/guardar\.onclick\s*=/g),1);
 assert.equal(count(/verHistorial\.onclick\s*=/g),1);
 assert.equal(count(/return \{api,state\};/g),1);
});
test('la ficha del cliente conserva su cierre de evento',()=>{
 assert.match(ui,/for\(const a of x\.articulos\|\|\[\]\)\{[\s\S]*?detalle\.append\([\s\S]*?\}\);[\s\S]*?linea\.append\(boton,detalle\)/);
 assert.doesNotMatch(ui,/^\+a\.precio_credito_unitario/m);
});
test('el borrador queda seleccionado para confirmación',()=>{
 assert.match(ui,/confirmarId\.value=id;/);
 assert.match(ui,/invalidarRevision\(\);\s*return 'Borrador creado:/);
});
test('confirmar venta exige revisión y confirmación explícita',()=>{
 assert.match(ui,/revision\.id!==confirmarId\.value\.trim\(\)/);
 assert.match(ui,/globalThis\.confirm\(/);
 assert.match(ui,/confirmarVenta\.disabled=true;/);
});
test('la interfaz no contiene claves ni crea clientes Supabase',()=>{
 assert.doesNotMatch(ui,/createClient\s*\(/);
 assert.doesNotMatch(ui,/service_role|supabase_service_role|eyJhbGciOi/i);
});
