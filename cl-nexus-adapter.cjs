/* CL Nexus RPC adapter — read/write operations gated to authorized lab. No credentials embedded. */
(function(root){'use strict';
const METHODS=Object.freeze({inventario:'cl2_sandbox_list',vendedores:'inv_catalogo_vendedores',articulos:'inv_catalogo_articulos_contratos',clientes:'inv_buscar_clientes',ficha:'inv_ficha_cliente',historial:'inv_historial_cliente',detalleContrato:'inv_detalle_contrato'});
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function makeAdapter({client,enabled=false}={}){
  if(!client||typeof client.rpc!=='function')throw Error('Cliente RPC no disponible');
  let live=true,epoch=0;
  const requiredText=x=>{if(typeof x!=='string'||!x.trim())throw Error('Campo obligatorio');return x.trim()};
  const validId=x=>{if(typeof x!=='string'||!uuid.test(x))throw Error('ID inválido');return x};
  const qty=x=>{if(!Number.isSafeInteger(x)||x<=0)throw Error('Cantidad inválida');return x};
  const jsonArray=x=>{if(!Array.isArray(x)||!x.length||x.length>100)throw Error('Detalle JSON debe ser una lista no vacía de máximo 100 registros');return x};
  const oneOf=(x,values,label)=>{if(!values.includes(x))throw Error(label+' inválido');return x};
  const contractDetails=x=>{jsonArray(x);for(const line of x){if(!line||!uuid.test(line.item_id)||!Number.isSafeInteger(line.cantidad)||line.cantidad<1||typeof line.precio_credito_unitario!=='number'||!Number.isFinite(line.precio_credito_unitario)||line.precio_credito_unitario<0||Math.abs(Math.round(line.precio_credito_unitario*100)-line.precio_credito_unitario*100)>1e-7)throw Error('Línea de contrato inválida');if(line.comision_linea!==undefined)money(line.comision_linea)}return x};
  const money=x=>{if(typeof x!=='number'||!Number.isFinite(x)||x<0||Math.abs(Math.round(x*100)-x*100)>1e-7)throw Error('Importe inválido');return x};
  const receiptDetails=x=>{jsonArray(x);for(const line of x){if(!line||!uuid.test(line.item_id)||![1,2].includes(line.location_id)||!Number.isSafeInteger(line.cantidad)||line.cantidad<1)throw Error('Línea de recepción inválida')}return x};
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
    clientes:q=>{if(typeof q!=='string'||q.trim().length<3||q.length>80)throw Error('Búsqueda: entre 3 y 80 caracteres');return query('clientes',{p_busqueda:q.trim()})},
    ficha:id=>{if(!uuid.test(id))throw Error('ID de cliente inválido');return query('ficha',{p_cliente_id:id})},
    historial:id=>{if(!uuid.test(id))throw Error('ID de cliente inválido');return query('historial',{p_cliente_id:id})},
    movimiento:({itemId,tipo,origen,destino,cantidad,observaciones,opId})=>{validId(itemId);validId(opId);qty(cantidad);location(origen);requiredText(observaciones);if(!['salida','traslado'].includes(tipo))throw Error('Tipo inválido');if(tipo==='traslado'){location(destino);if(origen===destino)throw Error('Origen y destino iguales')}else if(destino!=null)throw Error('Salida sin destino');return operation('inv_registrar_movimiento',{p_item_id:itemId,p_tipo:tipo,p_origen:origen,p_destino:tipo==='salida'?null:destino,p_cantidad:cantidad,p_vendedor:null,p_observaciones:observaciones.trim(),p_client_op_id:opId})},
    solicitarEntrada:({itemId,ubicacion,cantidad,observaciones})=>{validId(itemId);location(ubicacion);qty(cantidad);return operation('inv_solicitar_entrada',{p_item_id:itemId,p_location_id:ubicacion,p_cantidad:cantidad,p_observaciones:requiredText(observaciones)})},
    revisarEntrada:({solicitudId,aprobar})=>{validId(solicitudId);if(typeof aprobar!=='boolean')throw Error('Decisión inválida');return operation('inv_revisar_entrada',{p_solicitud_id:solicitudId,p_aprobar:aprobar})},
    solicitarDevolucion:({itemId,cantidad,motivo})=>{validId(itemId);qty(cantidad);return operation('inv_solicitar_devolucion',{p_item_id:itemId,p_cantidad:cantidad,p_motivo:requiredText(motivo)})},
    revisarDevolucion:({solicitudId,aprobar})=>{validId(solicitudId);if(typeof aprobar!=='boolean')throw Error('Decisión inválida');return operation('inv_revisar_devolucion',{p_solicitud_id:solicitudId,p_aprobar:aprobar})},
    liberarGarantia:({itemId,destino,cantidad,observaciones})=>{validId(itemId);if(![1,2].includes(destino))throw Error('Destino de garantía inválido');qty(cantidad);return operation('inv_liberar_garantia',{p_item_id:itemId,p_destino:destino,p_cantidad:cantidad,p_observaciones:requiredText(observaciones)})},
    crearVendedor:nombre=>operation('inv_crear_vendedor',{p_nombre:requiredText(nombre)}),
    crearVendedorManual:nombre=>operation('inv_crear_vendedor_manual',{p_nombre:requiredText(nombre)}),
    anularVenta:({ventaId,motivo})=>operation('inv_anular_venta',{p_venta_id:validId(ventaId),p_motivo:requiredText(motivo)}),
    detalleContrato:id=>query('detalleContrato',{p_contrato_id:validId(id)}),
    crearReparacion:({itemId,cantidad,destinoTipo,destinoNombre,motivo,observaciones})=>{validId(itemId);qty(cantidad);return operation('inv_crear_reparacion',{p_item_id:itemId,p_cantidad:cantidad,p_destino_tipo:oneOf(destinoTipo,['proveedor','taller'],'Tipo de destino'),p_destino_nombre:requiredText(destinoNombre),p_motivo:requiredText(motivo),p_observaciones:requiredText(observaciones)})},
    enviarReparacion:({reparacionId})=>operation('inv_enviar_reparacion',{p_reparacion_id:validId(reparacionId)}),
    resolverReparacion:({reparacionId,operacion,cantidad,observaciones})=>{validId(reparacionId);qty(cantidad);return operation('inv_resolver_reparacion',{p_reparacion_id:reparacionId,p_operacion:requiredText(operacion),p_cantidad:cantidad,p_observaciones:requiredText(observaciones)})},
    crearRecepcion:({proveedor,referencia,fecha,observaciones,detalles})=>operation('inv_crear_recepcion',{p_proveedor:requiredText(proveedor),p_referencia:requiredText(referencia),p_fecha:requiredText(fecha),p_observaciones:requiredText(observaciones),p_detalles:receiptDetails(detalles)}),
    revisarRecepcion:({recepcionId,aprobar})=>{validId(recepcionId);if(typeof aprobar!=='boolean')throw Error('Decisión inválida');return operation('inv_revisar_recepcion',{p_recepcion_id:recepcionId,p_aprobar:aprobar})},
    crearCliente:({nombre,dui,direccion,ubicacion,telefono,vivienda,lugarTrabajo,telefonoTrabajo,referencias})=>operation('inv_crear_cliente',{p_nombre:requiredText(nombre),p_dui:requiredText(dui),p_direccion:requiredText(direccion),p_ubicacion:requiredText(ubicacion),p_telefono:requiredText(telefono),p_vivienda:requiredText(vivienda),p_lugar_trabajo:lugarTrabajo||'',p_telefono_trabajo:telefonoTrabajo||'',p_referencias:referencias||[]}),
    crearContratoBorrador:v=>{validId(v.clienteId);validId(v.vendedorId);money(v.cuota);money(v.saldoInicial);money(v.comision);money(v.prima);contractDetails(v.detalles);oneOf(v.modalidad,['credito','contado'],'Modalidad');oneOf(v.plan,['normal','3_pagos','6_pagos'],'Plan');oneOf(v.frecuencia,['semanal','quincenal','mensual'],'Frecuencia');return operation('inv_crear_contrato_borrador',{p_numero:requiredText(v.numero),p_cliente_id:v.clienteId,p_vendedor_id:v.vendedorId,p_fecha:requiredText(v.fecha),p_modalidad:requiredText(v.modalidad),p_frecuencia:requiredText(v.frecuencia),p_plan:requiredText(v.plan),p_cuota:v.cuota,p_saldo_inicial:v.saldoInicial,p_fecha_plan:requiredText(v.fechaPlan),p_ruta:requiredText(v.ruta),p_dia_cobro:requiredText(v.diaCobro),p_receptor_alterno:v.receptorAlterno||'',p_comision:v.comision,p_prima:v.prima,p_prima_recibida:v.primaRecibida===true,p_detalles:v.detalles,p_observaciones:requiredText(v.observaciones)})},
    confirmarContrato:({contratoId,ubicaciones,opId})=>{validId(contratoId);validId(opId);if(!Array.isArray(ubicaciones)||!ubicaciones.length||ubicaciones.length>100||ubicaciones.some(x=>!x||!uuid.test(x.detalle_id)||![1,2].includes(x.location_id)))throw Error('Ubicaciones inválidas: lista de detalle_id y location_id (1 o 2)');return operation('inv_confirmar_contrato',{p_contrato_id:contratoId,p_ubicaciones:ubicaciones,p_client_op_id:opId})},
    marcarPrima:({contratoId,observaciones})=>operation('inv_marcar_prima_recibida',{p_contrato_id:validId(contratoId),p_observaciones:requiredText(observaciones)})
  });
}
const api=Object.freeze({makeAdapter,METHODS});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.CLNexusAdapter=api;
})(typeof window!=='undefined'?window:null);
