/**
 * FASE 15L — Adaptador de contratos para una sesión Supabase YA autenticada.
 * No crea cliente Supabase, no contiene claves y no modifica la PWA publicada.
 * Depende de migraciones 15I, 15J y 15K instaladas y probadas en un proyecto aislado.
 */
export function crearServicioContratos(supabase) {
  if (!supabase || typeof supabase.rpc !== 'function') {
    throw new TypeError('Se requiere un cliente Supabase autenticado');
  }
  async function rpc(nombre, parametros) {
    const {data,error}=await supabase.rpc(nombre,parametros);
    if(error) throw new Error(error.message || 'No se pudo completar la operación');
    return data;
  }
  const limpiarDui = valor => String(valor||'').replace(/\D/g,'');
  const dinero = valor => {
    if(valor===null || valor===undefined || (typeof valor==='string' && !valor.trim())) throw new Error('Importe monetario inválido');
    const n=Number(valor);
    if(!Number.isFinite(n)||n<0||n>999999999999.99||Math.abs(n*100-Math.round(n*100))>1e-7) throw new Error('Importe monetario inválido');
    return Math.round(n*100)/100;
  };
  return Object.freeze({
    buscarClientes: texto=>rpc('inv_buscar_clientes',{p_busqueda:String(texto||'').trim()}),
    catalogoVendedores:()=>rpc('inv_catalogo_vendedores',{}),
    catalogoArticulos:()=>rpc('inv_catalogo_articulos_contratos',{}),
    fichaCliente:clienteId=>rpc('inv_ficha_cliente',{p_cliente_id:clienteId}),
    historialCliente:clienteId=>rpc('inv_historial_cliente',{p_cliente_id:clienteId}),
    detalleContrato:contratoId=>rpc('inv_detalle_contrato',{p_contrato_id:contratoId}),
    crearCliente: c=>{
      if(!c||typeof c.nombre!=='string'||c.nombre.trim().length<2||c.nombre.trim().length>200)
        throw new Error('Nombre de cliente inválido');
      const referencias=c.referencias??[];
      if(!Array.isArray(referencias)||referencias.length>2||
         referencias.some(r=>!r||typeof r.nombre!=='string'||r.nombre.trim().length<2))
        throw new Error('Se admiten hasta dos referencias con nombre válido');
      const dui=c.dui?limpiarDui(c.dui):null;
      if(dui && dui.length!==9)throw new Error('DUI inválido');
      return rpc('inv_crear_cliente',{
      p_nombre:c.nombre,p_dui:dui,
      p_direccion:c.direccion||null,p_ubicacion:c.ubicacion||null,
      p_telefono:c.telefono||null,p_vivienda:c.vivienda||null,
      p_lugar_trabajo:c.lugarTrabajo||null,p_telefono_trabajo:c.telefonoTrabajo||null,
      p_referencias:referencias.map(r=>({
        nombre:r.nombre,telefono:r.telefono||null,
        direccion:r.direccion||null,parentesco:r.parentesco||null
      }))
      });
    },
    crearContratoBorrador: c=>{
      if(!Array.isArray(c.articulos)||c.articulos.length===0) throw new Error('Agrega artículos');
      if(c.articulos.length>100) throw new Error('Máximo 100 artículos por contrato');
      // Centavos enteros: evita errores acumulados de coma flotante.
      let totalCentavos=0;
      const maxCentavos=99999999999999;
      for(const a of c.articulos){
        if(!a || typeof a.itemId!=='string' || !a.itemId.trim())
          throw new Error('Selecciona un artículo válido');
        if(a.cantidad===null || a.cantidad===undefined || String(a.cantidad).trim()==='' || !Number.isSafeInteger(Number(a.cantidad)) || Number(a.cantidad)<=0 || Number(a.cantidad)>999999999)
          throw new Error('Cantidad de artículo inválida');
        const centavos=Math.round(dinero(a.precio)*100);
        totalCentavos+=Number(a.cantidad)*centavos;
        if(!Number.isSafeInteger(totalCentavos)||totalCentavos>maxCentavos)
          throw new Error('Total del contrato fuera de rango');
      }
      const prima=dinero(c.prima??0);
      const primaCentavos=Math.round(prima*100);
      if(primaCentavos>totalCentavos)throw new Error('La prima supera el total del contrato');
      if(c.saldoInicial!=null && Math.round(dinero(c.saldoInicial)*100)!==totalCentavos-primaCentavos)
        throw new Error('Saldo inicial no coincide con total menos prima');
      return rpc('inv_crear_contrato_borrador',{
        p_numero:c.numero,p_cliente_id:c.clienteId,p_vendedor_id:c.vendedorId,
        p_fecha:c.fecha,p_modalidad:c.modalidad||'credito',
        p_frecuencia:c.frecuencia||null,p_plan:c.plan||'normal',
        p_cuota:c.cuota==null?null:dinero(c.cuota),
        p_saldo_inicial:c.saldoInicial==null?null:dinero(c.saldoInicial),
        p_fecha_plan:c.fechaPlan||null,p_ruta:c.ruta||null,
        p_dia_cobro:c.diaCobro||null,p_receptor_alterno:c.receptorAlterno||null,
        p_comision:dinero(c.comision||0),p_prima:prima,
        p_prima_recibida:!!c.primaRecibida,
        p_detalles:c.articulos.map(a=>({
          item_id:a.itemId,cantidad:Number(a.cantidad),
          precio_credito_unitario:dinero(a.precio),
          comision_linea:dinero(a.comision||0)
        })),
        p_observaciones:c.observaciones||null
      });
    },
    confirmarContrato:(contratoId,ubicaciones,operacionId)=>{
      if(typeof contratoId!=='string'||!contratoId.trim()||typeof operacionId!=='string'||!operacionId.trim()||!Array.isArray(ubicaciones)||ubicaciones.length===0)
        throw new Error('Faltan datos para confirmar el contrato');
      const ids=new Set();
      for(const linea of ubicaciones){
        if(!linea||typeof linea.detalleId!=='string'||!linea.detalleId.trim()||ids.has(linea.detalleId)||![1,2].includes(linea.ubicacionId))
          throw new Error('Ubicaciones o líneas de contrato inválidas');
        ids.add(linea.detalleId);
      }
      return rpc('inv_confirmar_contrato',{
        p_contrato_id:contratoId,
        p_ubicaciones:ubicaciones.map(x=>({detalle_id:x.detalleId,location_id:x.ubicacionId})),
        p_client_op_id:operacionId
      });
    },
    marcarPrimaRecibida:(contratoId,observaciones)=>rpc('inv_marcar_prima_recibida',{
      p_contrato_id:contratoId,p_observaciones:observaciones
    }),
    historialVendedor:(vendedorId,desde=null,hasta=null)=>rpc('inv_historial_vendedor',{
      p_vendedor_id:vendedorId,p_desde:desde,p_hasta:hasta
    }),
    resumenVendedor:(vendedorId,desde=null,hasta=null)=>rpc('inv_resumen_vendedor',{
      p_vendedor_id:vendedorId,p_desde:desde,p_hasta:hasta
    })
  });
}
