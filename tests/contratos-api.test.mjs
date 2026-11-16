// Pruebas aisladas: node --experimental-default-type=module --test tests/contratos-api.test.mjs
// No necesitan Supabase ni credenciales; solo verifican argumentos y errores.
import test from 'node:test';
import assert from 'node:assert/strict';
import {crearServicioContratos} from '../prototipos/contratos-api.js';

function clienteMock(error=null){
 const calls=[];
 return {calls,client:{rpc:async(name,args)=>{calls.push({name,args});return {data:error?null:{ok:true},error}}}};
}
const base={
 numero:'TEST-001',clienteId:'cliente-uuid',vendedorId:'vendedor-uuid',
 fecha:'2026-11-15',comision:'0.30',prima:'0.20',
 articulos:[{itemId:'articulo-uuid',cantidad:2,precio:'0.30',comision:'0.10'}]
};
test('buscar clientes usa RPC y no tablas públicas',async()=>{
 const m=clienteMock();await crearServicioContratos(m.client).buscarClientes(' Ana ');
 assert.deepEqual(m.calls[0],{name:'inv_buscar_clientes',args:{p_busqueda:'Ana'}});
});
test('catálogos y ficha pasan por RPC',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 await api.catalogoVendedores();await api.catalogoArticulos();await api.fichaCliente('abc');
 assert.deepEqual(m.calls.map(c=>c.name),[
  'inv_catalogo_vendedores','inv_catalogo_articulos_contratos','inv_ficha_cliente']);
});
test('acepta importes válidos con decimales',async()=>{
 const m=clienteMock();await crearServicioContratos(m.client).crearContratoBorrador(base);
 assert.equal(m.calls[0].args.p_prima,0.2);
 assert.equal(m.calls[0].args.p_detalles[0].precio_credito_unitario,0.3);
});
test('rechaza cantidades fraccionarias o negativas',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 for(const cantidad of [0,-1,1.5,'abc']){
  assert.throws(()=>api.crearContratoBorrador({
   ...base,articulos:[{...base.articulos[0],cantidad}]
  }),/Cantidad/);
 }
 assert.equal(m.calls.length,0);
});
test('rechaza importes negativos y con más de dos decimales',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 for(const prima of ['-1','1.234']){
  assert.throws(()=>api.crearContratoBorrador({...base,prima}),/Importe/);
 }
 assert.equal(m.calls.length,0);
});
test('propaga errores del servidor',async()=>{
 const m=clienteMock({message:'No autorizado'});
 await assert.rejects(()=>crearServicioContratos(m.client).buscarClientes('Ana'),/No autorizado/);
});

test('confirmar contrato envía ubicaciones por línea y operación única',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 await api.confirmarContrato('contrato-uuid',[
  {detalleId:'detalle-a',ubicacionId:1},{detalleId:'detalle-b',ubicacionId:2}
 ],'operacion-uuid');
 assert.deepEqual(m.calls[0],{
  name:'inv_confirmar_contrato',
  args:{
   p_contrato_id:'contrato-uuid',
   p_ubicaciones:[
    {detalle_id:'detalle-a',location_id:1},
    {detalle_id:'detalle-b',location_id:2}
   ],
   p_client_op_id:'operacion-uuid'
  }
 });
});
test('rechaza líneas repetidas o ubicaciones no autorizadas',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.confirmarContrato('c',[
  {detalleId:'x',ubicacionId:1},{detalleId:'x',ubicacionId:2}
 ],'op'),/inválidas/);
 assert.throws(()=>api.confirmarContrato('c',[
  {detalleId:'x',ubicacionId:3}
 ],'op'),/inválidas/);
 assert.equal(m.calls.length,0);
});

test('crea cliente con vivienda, trabajo y dos referencias',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 await api.crearCliente({
  nombre:'Cliente de prueba',dui:'01234567-8',vivienda:'propia',
  lugarTrabajo:'Comercio',telefonoTrabajo:'2222-2222',
  referencias:[{nombre:'Referencia A',telefono:'1111-1111'},
              {nombre:'Referencia B',parentesco:'Familiar'}]
 });
 const llamada=m.calls[0];
 assert.equal(llamada.name,'inv_crear_cliente');
 assert.equal(llamada.args.p_dui,'012345678');
 assert.equal(llamada.args.p_vivienda,'propia');
 assert.equal(llamada.args.p_lugar_trabajo,'Comercio');
 assert.equal(llamada.args.p_referencias.length,2);
});
test('consulta historial y detalle de contrato por RPC',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 await api.historialCliente('cliente-1');
 await api.detalleContrato('contrato-1');
 assert.deepEqual(m.calls,[
  {name:'inv_historial_cliente',args:{p_cliente_id:'cliente-1'}},
  {name:'inv_detalle_contrato',args:{p_contrato_id:'contrato-1'}}
 ]);
});
test('confirmación requiere identificador de operación',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.confirmarContrato('c',[{detalleId:'d',ubicacionId:1}],null),/Faltan datos/);
 assert.equal(m.calls.length,0);
});

test('rechaza prima superior al total y saldo inicial inconsistente',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.crearContratoBorrador({...base,prima:'0.61'}),/prima supera/);
 assert.throws(()=>api.crearContratoBorrador({...base,saldoInicial:'0.50'}),/Saldo inicial/);
 assert.equal(m.calls.length,0);
});
test('acepta saldo igual al total menos prima',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 await api.crearContratoBorrador({...base,saldoInicial:'0.40'});
 assert.equal(m.calls[0].args.p_saldo_inicial,0.4);
});
test('rechaza montos superiores a numeric 14,2',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.crearContratoBorrador({...base,comision:'1000000000000'}),/Importe/);
 assert.equal(m.calls.length,0);
});
test('rechaza más de cien líneas y cantidades fuera del límite SQL',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.crearContratoBorrador({...base,articulos:Array(101).fill(base.articulos[0])}),/Máximo 100/);
 assert.throws(()=>api.crearContratoBorrador({...base,articulos:[{...base.articulos[0],cantidad:1000000000}]}),/Cantidad/);
 assert.equal(m.calls.length,0);
});

test('no transforma precio vacío en venta gratis',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 for(const precio of ['', ' ', null, undefined]){
  assert.throws(()=>api.crearContratoBorrador({...base,articulos:[{...base.articulos[0],precio}]}),/Importe/);
 }
 assert.equal(m.calls.length,0);
});
test('no convierte cantidad vacía a cero',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 for(const cantidad of ['', ' ', null, undefined]){
  assert.throws(()=>api.crearContratoBorrador({...base,articulos:[{...base.articulos[0],cantidad}]}),/Cantidad/);
 }
 assert.equal(m.calls.length,0);
});
test('rechaza prima vacía y mantiene prima cero explícita',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.crearContratoBorrador({...base,prima:''}),/Importe/);
 await api.crearContratoBorrador({...base,prima:0});
 assert.equal(m.calls[0].args.p_prima,0);
});

test('suma diez precios de diez centavos sin error de coma flotante',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 await api.crearContratoBorrador({...base,prima:0.1,saldoInicial:0.9,
  articulos:Array.from({length:10},()=>({...base.articulos[0],cantidad:1,precio:0.1}))});
 assert.equal(m.calls.length,1);
 assert.equal(m.calls[0].args.p_saldo_inicial,0.9);
});
test('rechaza saldo inconsistente por un centavo',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.crearContratoBorrador({...base,prima:0.1,saldoInicial:0.8,
  articulos:Array.from({length:10},()=>({...base.articulos[0],cantidad:1,precio:0.1}))}),/Saldo inicial/);
 assert.equal(m.calls.length,0);
});

test('rechaza artículos sin identificador antes de llamar al servidor',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 for(const itemId of ['', ' ', null, undefined]){
  assert.throws(()=>api.crearContratoBorrador({...base,articulos:[{...base.articulos[0],itemId}]}),/artículo válido/);
 }
 assert.equal(m.calls.length,0);
});
test('rechaza saldo vacío en vez de convertirlo a cero',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.crearContratoBorrador({...base,saldoInicial:''}),/Importe/);
 assert.equal(m.calls.length,0);
});
test('rechaza identificadores y líneas de confirmación mal formados',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 for(const contrato of ['', ' ']){
  assert.throws(()=>api.confirmarContrato(contrato,[{detalleId:'d',ubicacionId:1}],'op'),/Faltan datos/);
 }
 assert.throws(()=>api.confirmarContrato('c',[null],'op'),/inválidas/);
 assert.throws(()=>api.confirmarContrato('c',[{detalleId:' ',ubicacionId:1}],'op'),/inválidas/);
 assert.equal(m.calls.length,0);
});

test('ubicaciones requieren números estrictos, no cadenas ni booleanos',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 for(const ubicacionId of ['1','2',true,false,null,1.5]){
  assert.throws(()=>api.confirmarContrato('c',[{detalleId:'d',ubicacionId}],'op'),/inválidas/);
 }
 assert.equal(m.calls.length,0);
});

test('rechaza nombres de cliente inválidos antes de RPC',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 for(const nombre of ['', ' ', 'A', 'A'.repeat(201),null]){
  assert.throws(()=>api.crearCliente({nombre}),/Nombre de cliente/);
 }
 assert.equal(m.calls.length,0);
});
test('rechaza más de dos referencias y nombres vacíos',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.crearCliente({nombre:'Cliente válido',referencias:[{nombre:'A'},{nombre:'B'},{nombre:'C'}]}),/referencias/);
 assert.throws(()=>api.crearCliente({nombre:'Cliente válido',referencias:[{nombre:' ' }]}),/referencias/);
 assert.equal(m.calls.length,0);
});
test('rechaza DUI con longitud distinta de nueve dígitos',()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 assert.throws(()=>api.crearCliente({nombre:'Cliente válido',dui:'123-45'}),/DUI/);
 assert.equal(m.calls.length,0);
});
