/* CL Nexus: read-only RPC adapter. No debt table access; fail closed on missing authorization. */
(function(root){
'use strict';
const definitions=Object.freeze({
 inventory:Object.freeze({rpc:'inv_catalogo_articulos_admin',args:Object.freeze({}),columns:Object.freeze(['id','nombre','categoria','codigo','oficina','bodega'])}),
 entryRequests:Object.freeze({rpc:'inv_solicitudes_entrada_pendientes',args:Object.freeze({}),columns:Object.freeze(['id','nombre','cantidad','ubicacion','creado_en','observaciones'])}),
 contractInventory:Object.freeze({rpc:'inv_catalogo_articulos_contratos',args:Object.freeze({}),columns:Object.freeze(['id','nombre','categoria'])}),
 contracts:Object.freeze({rpc:'inv_buscar_clientes',args:Object.freeze({p_busqueda:''}),columns:Object.freeze(['id','nombre','dui_mostrado','telefono'])}),
 sellers:Object.freeze({rpc:'inv_catalogo_vendedores',args:Object.freeze({}),columns:Object.freeze(['id','nombre'])}),
 contractSellers:Object.freeze({rpc:'inv_catalogo_vendedores_manual',args:Object.freeze({}),columns:Object.freeze(['id','nombre'])})
});
function createNexusReader({client,authorized}={}){
 if(!client||typeof client.rpc!=='function')throw Error('Cliente Supabase requerido');
 if(typeof authorized!=='function')throw Error('Verificación de sesión requerida');
 let epoch=0;
 function reset(){epoch++}
 async function list(kind,query=''){
  const config=definitions[kind];
  if(!config)throw Error('Módulo desconocido');
  if(!authorized())throw Error('Sesión no autorizada');
  const token=epoch;
  const term=kind==='contracts'?String(query).trim():'';
  if(kind==='contracts'&&(term.length<3||term.length>100))throw Error('Busca clientes con 3 a 100 caracteres');
  const args=kind==='contracts'?{p_busqueda:term}:{};
  const {data,error}=await client.rpc(config.rpc,args);
  if(token!==epoch||!authorized())throw Error('Sesión cerrada durante consulta');
  if(error)throw Error(error.message||'Consulta no autorizada');
  if(!Array.isArray(data))throw Error('Respuesta inesperada');
  return data.map(row=>Object.freeze(Object.fromEntries(config.columns.map(col=>[col,String(row[col]??'')]))));
 }
 return Object.freeze({list,reset});
}
const api=Object.freeze({createNexusReader});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.CLNexusReader=api;
})(typeof window!=='undefined'?window:null);
