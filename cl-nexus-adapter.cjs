/* CL Nexus read-only RPC adapter. No credentials or backend URL embedded. */
(function(root){'use strict';
const METHODS=Object.freeze({inventario:'cl2_sandbox_list',vendedores:'inv_catalogo_vendedores',articulos:'inv_catalogo_articulos_contratos',clientes:'inv_buscar_clientes',ficha:'inv_ficha_cliente',historial:'inv_historial_cliente'});
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function makeAdapter({client,enabled=false}={}){
  if(!client||typeof client.rpc!=='function')throw Error('Cliente RPC no disponible');
  let live=true,epoch=0;
  function disable(){live=false;epoch++}
  function enable(){live=true;epoch++}
  async function query(name,args={}){
    if(!enabled)throw Error('Conexión CL Nexus no habilitada para este entorno');
    if(!live)throw Error('Sesión de módulo cerrada');
    if(!Object.hasOwn(METHODS,name))throw Error('Consulta no autorizada');
    const serial=epoch;
    const {data,error}=await client.rpc(METHODS[name],args);
    if(!live||serial!==epoch)throw Error('Resultado descartado por cambio de sesión');
    if(error)throw Error(error.message||'Consulta CL Nexus fallida');
    return data;
  }
  return Object.freeze({disable,enable,
    inventario:()=>query('inventario',{p_module:'inventario'}),
    vendedores:()=>query('vendedores'),articulos:()=>query('articulos'),
    clientes:q=>{if(typeof q!=='string'||q.trim().length<3||q.length>80)throw Error('Búsqueda: entre 3 y 80 caracteres');return query('clientes',{p_query:q.trim()})},
    ficha:id=>{if(!uuid.test(id))throw Error('ID de cliente inválido');return query('ficha',{p_cliente_id:id})},
    historial:id=>{if(!uuid.test(id))throw Error('ID de cliente inválido');return query('historial',{p_cliente_id:id})}
  });
}
const api=Object.freeze({makeAdapter,METHODS});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.CLNexusAdapter=api;
})(typeof window!=='undefined'?window:null);
