/* CL Nexus transactional RPC adapter. Server is the authority for roles, stock and idempotency. */
(function(root){
'use strict';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const specs=Object.freeze({
 move:{rpc:'inv_registrar_movimiento',required:['p_item_id','p_tipo','p_cantidad','p_observaciones','p_client_op_id'],optional:['p_origen','p_destino','p_vendedor']},
 sale:{rpc:'inv_registrar_venta',required:['p_vendedor_id','p_modalidad','p_articulos','p_descuento','p_observaciones','p_client_op_id'],optional:[]},
 voidSale:{rpc:'inv_anular_venta',required:['p_venta_id','p_motivo'],optional:[]},
 warrantyRelease:{rpc:'inv_liberar_garantia',required:['p_item_id','p_destino','p_cantidad','p_observaciones'],optional:[]},
 requestEntry:{rpc:'inv_solicitar_entrada',required:['p_item_id','p_location_id','p_cantidad','p_observaciones'],optional:[]},
 reviewEntry:{rpc:'inv_revisar_entrada',required:['p_solicitud_id','p_aprobar'],optional:[]},
 requestReturn:{rpc:'inv_solicitar_devolucion',required:['p_item_id','p_cantidad','p_motivo'],optional:[]},
 reviewReturn:{rpc:'inv_revisar_devolucion',required:['p_solicitud_id','p_aprobar'],optional:[]},
 createRepair:{rpc:'inv_crear_reparacion',required:['p_item_id','p_cantidad','p_destino_tipo','p_destino_nombre','p_motivo','p_observaciones'],optional:[]},
 sendRepair:{rpc:'inv_enviar_reparacion',required:['p_reparacion_id'],optional:[]},
 resolveRepair:{rpc:'inv_resolver_reparacion',required:['p_reparacion_id','p_operacion','p_cantidad','p_observaciones'],optional:[]},
 createSeller:{rpc:'inv_crear_vendedor_manual',required:['p_nombre'],optional:[]},
 createClient:{rpc:'inv_crear_cliente',required:['p_nombre','p_dui','p_direccion','p_ubicacion','p_telefono','p_vivienda','p_lugar_trabajo','p_telefono_trabajo','p_referencias'],optional:[]},
 createContract:{rpc:'inv_crear_contrato_borrador',required:['p_numero','p_cliente_id','p_vendedor_id','p_fecha','p_modalidad','p_frecuencia','p_plan','p_cuota','p_saldo_inicial','p_fecha_plan','p_ruta','p_dia_cobro','p_receptor_alterno','p_comision','p_prima','p_prima_recibida','p_detalles','p_observaciones'],optional:[]},

 confirmContract:{rpc:'inv_confirmar_contrato',required:['p_contrato_id','p_ubicaciones','p_client_op_id'],optional:[]},
 markDeposit:{rpc:'inv_marcar_prima_recibida',required:['p_contrato_id','p_observaciones'],optional:[]}
});
function createNexusActions({client,authorized}={}){
 if(!client||typeof client.rpc!=='function'||typeof authorized!=='function')throw Error('Cliente y sesión requeridos');
 let generation=0;
 function reset(){generation++}
 async function execute(action,params){
  const spec=specs[action];
  if(!spec)throw Error('Operación no permitida');
  if(!authorized())throw Error('Sesión no autorizada');
  if(!params||typeof params!=='object'||Array.isArray(params))throw Error('Parámetros inválidos');
  const keys=[...spec.required,...spec.optional];
  if(Object.keys(params).some(k=>!keys.includes(k)))throw Error('Parámetro inesperado');
  for(const key of spec.required){
   const nullableContract=action==='createContract'&&['p_cuota','p_saldo_inicial','p_fecha_plan'].includes(key);
   const blankCustomer=action==='createClient'&&key!=='p_nombre'&&key!=='p_dui';
   if(!(key in params)||params[key]===undefined||(params[key]===null&&!nullableContract)||(typeof params[key]==='string'&&!params[key].trim()&&!blankCustomer))throw Error('Falta '+key);
  }
  for(const [key,value] of Object.entries(params)){
   if(key.endsWith('_id')&&value!==null&&!uuid.test(String(value)))throw Error('ID inválido');
   if((key==='p_cantidad'||key==='p_location_id')&&(!Number.isInteger(value)||value<=0))throw Error('Cantidad o ubicación inválida');
   if(key==='p_client_op_id'&&!uuid.test(String(value)))throw Error('Identificador de operación inválido');
  }
  const at=generation;
  const {data,error}=await client.rpc(spec.rpc,params);
  if(at!==generation||!authorized())throw Error('Sesión cerrada durante la operación; comprobar resultado antes de reintentar');
  if(error)throw Error(error.message||'Operación rechazada por el servidor');
  return data;
 }
 return Object.freeze({execute,reset});
}
const api=Object.freeze({createNexusActions});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.CLNexusActions=api;
})(typeof window!=='undefined'?window:null);
