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
    const n=Number(valor);
    if(!Number.isFinite(n)||n<0||Math.round(n*100)!==n*100) throw new Error('Importe monetario inválido');
    return n;
  };
  return Object.freeze({
    buscarClientes: texto=>rpc('inv_buscar_clientes',{p_busqueda:String(texto||'').trim()}),
    crearCliente: c=>rpc('inv_crear_cliente',{
      p_nombre:c.nombre,p_dui:c.dui?limpiarDui(c.dui):null,
      p_direccion:c.direccion||null,p_ubicacion:c.ubicacion||null,
      p_telefono:c.telefono||null,p_vivienda:c.vivienda||null,
      p_lugar_trabajo:c.lugarTrabajo||null,p_telefono_trabajo:c.telefonoTrabajo||null,
      p_referencias:(c.referencias||[]).map(r=>({
        nombre:r.nombre,telefono:r.telefono||null,
        direccion:r.direccion||null,parentesco:r.parentesco||null
      }))
    }),
    crearContratoBorrador: c=>{
      if(!Array.isArray(c.articulos)||c.articulos.length===0) throw new Error('Agrega artículos');
      return rpc('inv_crear_contrato_borrador',{
        p_numero:c.numero,p_cliente_id:c.clienteId,p_vendedor_id:c.vendedorId,
        p_fecha:c.fecha,p_modalidad:c.modalidad||'credito',
        p_frecuencia:c.frecuencia||null,p_plan:c.plan||'normal',
        p_cuota:c.cuota==null?null:dinero(c.cuota),
        p_saldo_inicial:c.saldoInicial==null?null:dinero(c.saldoInicial),
        p_fecha_plan:c.fechaPlan||null,p_ruta:c.ruta||null,
        p_dia_cobro:c.diaCobro||null,p_receptor_alterno:c.receptorAlterno||null,
        p_comision:dinero(c.comision||0),p_prima:dinero(c.prima||0),
        p_prima_recibida:!!c.primaRecibida,
        p_detalles:c.articulos.map(a=>({
          item_id:a.itemId,cantidad:Number(a.cantidad),
          precio_credito_unitario:dinero(a.precio),
          comision_linea:dinero(a.comision||0)
        })),
        p_observaciones:c.observaciones||null
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
