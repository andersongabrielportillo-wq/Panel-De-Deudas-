/* CL Nexus read-only RPC adapter. No credentials or backend URL embedded. */
(function(root){'use strict';
const METHODS=Object.freeze({inventario:'cl2_sandbox_list',vendedores:'inv_catalogo_vendedores',articulos:'inv_catalogo_articulos_contratos',clientes:'inv_buscar_clientes',ficha:'inv_ficha_cliente',historial:'inv_historial_cliente'});
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function makeAdapter({client,enabled=false}={}){
  if(!client||typeof client.rpc!=='function')throw Error('Cliente RPC no disponible');
  let live=true,epoch=0;
  const requiredText=x=>{if(typeof x!=='string'||!x.trim())throw Error('Observaciones obligatorias');return x.trim()};
  const validId=x=>{if(typeof x!=='string'||!uuid.test(x))throw Error('ID inválido');return x};
  const qty=x=>{if(!Number.isSafeInteger(x)||x<=0)throw Error('Cantidad inválida');return x};
  const location=x=>{if(!Number.isInteger(x)||x<1||x>3)throw Error('Ubicación inválida');return x};
  async function operation(name,args){if(!enabled||!live)throw Error('Operaciones deshabilitadas');const serial=epoch;const {data,error}=await client.rpc(name,args);if(!live||epoch!==serial)throw Error('Sesión cerrada durante operación: verificar resultado en servidor antes de repetir');if(error)throw Error(error.message||'Operación rechazada por el servidor');return data}

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
    historial:id=>{if(!uuid.test(id))throw Error('ID de cliente inválido');return query('historial',{p_cliente_id:id})},
    movimiento:({itemId,tipo,origen,destino,cantidad,observaciones,opId})=>{validId(itemId);validId(opId);qty(cantidad);location(origen);requiredText(observaciones);if(!['salida','traslado'].includes(tipo))throw Error('Tipo inválido');if(tipo==='traslado'){location(destino);if(origen===destino)throw Error('Origen y destino iguales')}else if(destino!=null)throw Error('Salida sin destino');return operation('inv_registrar_movimiento',{p_item_id:itemId,p_tipo:tipo,p_origen:origen,p_destino:tipo==='salida'?null:destino,p_cantidad:cantidad,p_vendedor:null,p_observaciones:observaciones.trim(),p_client_op_id:opId})},
    solicitarEntrada:({itemId,ubicacion,cantidad,observaciones})=>{validId(itemId);location(ubicacion);qty(cantidad);return operation('inv_solicitar_entrada',{p_item_id:itemId,p_location_id:ubicacion,p_cantidad:cantidad,p_observaciones:requiredText(observaciones)})},
    revisarEntrada:({solicitudId,aprobar})=>{validId(solicitudId);if(typeof aprobar!=='boolean')throw Error('Decisión inválida');return operation('inv_revisar_entrada',{p_solicitud_id:solicitudId,p_aprobar:aprobar})},
    solicitarDevolucion:({itemId,cantidad,motivo})=>{validId(itemId);qty(cantidad);return operation('inv_solicitar_devolucion',{p_item_id:itemId,p_cantidad:cantidad,p_motivo:requiredText(motivo)})},
    revisarDevolucion:({solicitudId,aprobar})=>{validId(solicitudId);if(typeof aprobar!=='boolean')throw Error('Decisión inválida');return operation('inv_revisar_devolucion',{p_solicitud_id:solicitudId,p_aprobar:aprobar})},
    liberarGarantia:({itemId,destino,cantidad,observaciones})=>{validId(itemId);if(![1,2].includes(destino))throw Error('Destino de garantía inválido');qty(cantidad);return operation('inv_liberar_garantia',{p_item_id:itemId,p_destino:destino,p_cantidad:cantidad,p_observaciones:requiredText(observaciones)})},
    crearVendedor:nombre=>operation('inv_crear_vendedor',{p_nombre:requiredText(nombre)})
  });
}
const api=Object.freeze({makeAdapter,METHODS});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.CLNexusAdapter=api;
})(typeof window!=='undefined'?window:null);
