// Pruebas aisladas: node --test tests/contratos-api.test.mjs
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
  await assert.rejects(()=>api.crearContratoBorrador({
   ...base,articulos:[{...base.articulos[0],cantidad}]
  }),/Cantidad/);
 }
 assert.equal(m.calls.length,0);
});
test('rechaza importes negativos y con más de dos decimales',async()=>{
 const m=clienteMock(),api=crearServicioContratos(m.client);
 for(const prima of ['-1','1.234']){
  await assert.rejects(()=>api.crearContratoBorrador({...base,prima}),/Importe/);
 }
 assert.equal(m.calls.length,0);
});
test('propaga errores del servidor',async()=>{
 const m=clienteMock({message:'No autorizado'});
 await assert.rejects(()=>crearServicioContratos(m.client).buscarClientes('Ana'),/No autorizado/);
});
