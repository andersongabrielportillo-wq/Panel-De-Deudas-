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
 fecha:'2026-11-15',comision:'0.30',prima:'1.20',
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
 assert.equal(m.calls[0].args.p_prima,1.2);
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
