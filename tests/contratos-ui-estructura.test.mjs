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
 assert.match(ui,/return 'Cliente creado: '/);
 assert.match(ui,/No se cambió el cliente del borrador en curso/);
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
 assert.match(ui,/if\(valor===null\|\|valor===undefined\|\|typeof valor==='boolean'/);
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

test('revisión exige saldo inicial consistente con total y prima',()=>{
 assert.match(ui,/centavosValidos\(contrato\.saldo_inicial\)!==totalCentavos-primaCentavos/);
 assert.match(ui,/Saldo del contrato no coincide/);
});
test('revisión impide IDs de detalles duplicados',()=>{
 assert.match(ui,/const idsDetalles=new Set\(\)/);
 assert.match(ui,/idsDetalles\.has\(articulo\.detalle_id\)/);
 assert.match(ui,/Identificadores de artículos ausentes o repetidos/);
});

test('no permite dos confirmaciones simultáneas',()=>{
 assert.match(ui,/let confirmacionEnCurso=false/);
 assert.match(ui,/if\(confirmacionEnCurso\)throw new Error/);
 assert.match(ui,/confirmacionEnCurso=true/);
 assert.match(ui,/finally\{\s*confirmacionEnCurso=false/);
});

test('búsquedas anteriores no reemplazan resultados nuevos',()=>{
 assert.match(ui,/let solicitudBusqueda=0/);
 assert.match(ui,/busqueda\.addEventListener\('input',\(\)=>\{solicitudBusqueda\+\+/);
 assert.match(ui,/if\(solicitud!==solicitudBusqueda\)return 'Búsqueda anterior descartada'/);
});
test('no se modifica el cliente seleccionado mientras se guarda',()=>{
 assert.match(ui,/if\(guardandoBorrador\)\{estado\.textContent='Espera a que termine el guardado';return;\}state\.clienteId=r\.id/);
 assert.match(ui,/if\(!guardandoBorrador\)\{state\.clienteId=clienteNuevo/);
});
test('el guardado utiliza copia de artículos y bloquea cambios concurrentes',()=>{
 assert.match(ui,/const articulosGuardados=state\.items\.map\(linea=>\(\{\.\.\.linea\}\)\)/);
 assert.match(ui,/articulos:articulosGuardados/);
 assert.match(ui,/agregar\.onclick=\(\)=>\{\s*if\(guardandoBorrador\)/);
 assert.match(ui,/quitar\.onclick=\(\)=>\{if\(guardandoBorrador\)/);
});

test('ficha de cliente descarta resultados obsoletos',()=>{
 assert.match(ui,/let solicitudPerfil=0/);
 assert.match(ui,/const clienteConsultado=state\.clienteId/);
 assert.match(ui,/if\(solicitud!==solicitudPerfil\|\|clienteConsultado!==state\.clienteId\)/);
});
test('cambiar de cliente limpia ficha e invalida consultas pendientes',()=>{
 assert.match(ui,/state\.clienteId=r\.id;solicitudPerfil\+\+;perfilContenido\.replaceChildren\(\)/);
 assert.match(ui,/state\.clienteId=clienteNuevo;solicitudPerfil\+\+;perfilContenido\.replaceChildren\(\)/);
});
test('guardar borrador invalida revisiones anteriores de confirmación',()=>{
 assert.match(ui,/confirmarId\.value=id;\s*revisionSolicitud\+\+;\s*invalidarRevision\(\)/);
});

test('revisión de contrato rechaza booleanos en dinero y cantidades',()=>{
 assert.match(ui,/typeof valor==='boolean'/);
 assert.match(ui,/typeof articulo\.cantidad==='boolean'/);
});

test('confirmación tardía no borra revisión de otro contrato',()=>{
 assert.match(ui,/const revisionEnviada=revision/);
 assert.match(ui,/const operacionEnviada=operacionConfirmacion/);
 assert.match(ui,/if\(revision===revisionEnviada && operacionConfirmacion===operacionEnviada\)\s*invalidarRevision\(\)/);
});
test('fallo tardío no reactiva confirmación de otra revisión',()=>{
 assert.match(ui,/catch\(e\)\{\s*\/\/ Solo permitir reintento si seguimos viendo la misma revisión/);
 assert.match(ui,/if\(revision===revisionEnviada && operacionConfirmacion===operacionEnviada\)\s*confirmarVenta\.disabled=false/);
});
