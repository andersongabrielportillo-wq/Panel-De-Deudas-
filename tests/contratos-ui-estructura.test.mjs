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

test('no admite precio o cantidad vacíos al agregar artículos',()=>{
 assert.match(ui,/cantidad\.value\.trim\(\)===''\|\|precio\.value\.trim\(\)===''/);
 assert.match(ui,/q>999999999/);
 assert.match(ui,/p>999999999999\.99/);
});
test('el formulario exige número y fecha antes de crear borrador',()=>{
 assert.match(ui,/if\(!numero\.value\.trim\(\)\)/);
 assert.match(ui,/if\(!fecha\.value\)/);
});

test('evita guardados concurrentes y restaura botón',()=>{
 assert.match(ui,/let guardandoBorrador=false/);
 assert.match(ui,/if\(guardandoBorrador\)throw new Error/);
 assert.match(ui,/guardandoBorrador=true;guardar\.disabled=true/);
 assert.match(ui,/finally \{guardandoBorrador=false;guardar\.disabled=false;\}/);
});
test('limita el formulario a cien líneas',()=>{
 assert.match(ui,/state\.items\.length>=100/);
});

test('confirma visualmente el cliente creado y seleccionado',()=>{
 assert.match(ui,/state\.clienteId=clienteNuevo/);
 assert.match(ui,/return 'Cliente creado y seleccionado: '/);
});

test('invalida revisiones de contratos cambiados durante la consulta',()=>{
 assert.match(ui,/let revisionSolicitud=0/);
 assert.match(ui,/revisionSolicitud\+\+;invalidarRevision\(\)/);
 assert.match(ui,/solicitud!==revisionSolicitud \|\| confirmarId\.value\.trim\(\)!==contratoId/);
 assert.match(ui,/cargarDetalle\.disabled=true/);
 assert.match(ui,/finally \{cargarDetalle\.disabled=false;\}/);
});
test('evita dar de alta dos veces al mismo cliente por doble clic',()=>{
 assert.match(ui,/let creandoCliente=false/);
 assert.match(ui,/if\(creandoCliente\)throw new Error/);
 assert.match(ui,/creandoCliente=true;crearCliente\.disabled=true/);
 assert.match(ui,/finally \{creandoCliente=false;crearCliente\.disabled=false;\}/);
});

test('la prima recibida corresponde a caja y no solo al vendedor',()=>{
 assert.match(ui,/Prima entregada a caja y recibida por administración/);
 assert.doesNotMatch(ui,/Prima recibida por vendedor/);
});
test('muestra total prima y saldo antes de confirmar la venta',()=>{
 assert.match(ui,/let totalCentavos=0/);
 assert.match(ui,/primaCentavos=centavosValidos/);
 assert.match(ui,/Importes de contrato inconsistentes/);
 assert.match(ui,/Saldo: '/);
});

test('no permite confirmar contratos sin prima o con precios ausentes',()=>{
 assert.match(ui,/if\(valor===null\|\|valor===undefined\|\|String\(valor\)\.trim\(\)===''\)/);
 assert.match(ui,/centavosValidos\(articulo\.precio_credito_unitario\)/);
 assert.match(ui,/centavosValidos\(contrato\.prima\?\.monto\)/);
});
test('valida cantidad y límite de importes al revisar contrato',()=>{
 assert.match(ui,/Number\.isSafeInteger\(cantidad\)/);
 assert.match(ui,/cantidad>999999999/);
 assert.match(ui,/totalCentavos>99999999999999/);
});

test('impide revisiones concurrentes del mismo formulario',()=>{
 assert.match(ui,/let revisionEnCurso=false/);
 assert.match(ui,/if\(revisionEnCurso\)throw new Error/);
 assert.match(ui,/revisionEnCurso=true/);
 assert.match(ui,/finally \{revisionEnCurso=false;\}/);
});

test('catalogo vacio no rompe la pantalla al agregar articulo',()=>{
 assert.match(ui,/if\(!selected\)\{estado\.textContent='Selecciona un artículo del catálogo';return;\}/);
});
test('quitar articulo no elimina otra linea si ya fue removido',()=>{
 assert.match(ui,/const indice=state\.items\.indexOf\(line\)/);
 assert.match(ui,/if\(indice!==-1\)state\.items\.splice\(indice,1\)/);
});
