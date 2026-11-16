/**
 * Fase 15M: controlador de interfaz de contratos, solo para entorno de pruebas.
 * Requiere contratos-api.js y un cliente Supabase autenticado inyectado.
 * No se conecta automáticamente a producción.
 */
import {crearServicioContratos} from './contratos-api.js';

export function iniciarContratosDemo({supabase,root}) {
  if (!root || !supabase) throw new Error('Faltan raíz o sesión Supabase');
  const api=crearServicioContratos(supabase);
  const state={clienteId:null,vendedorId:null,items:[],resultados:[]};
  const el=(tag,props={},text='')=>{
    const node=document.createElement(tag);
    Object.entries(props).forEach(([key,value])=>{
      if(key==='className')node.className=value;
      else if(key==='type')node.type=value;
      else node.setAttribute(key,value);
    });
    if(text)node.textContent=text;
    return node;
  };
  const section=(title)=>{
    const box=el('section',{className:'contratos-seccion'});
    box.append(el('h3',{},title));root.append(box);return box;
  };
  const campo=(parent,label,type='text')=>{
    const wrap=el('label');wrap.append(el('span',{},label));
    const input=el('input',{type});wrap.append(input);parent.append(wrap);return input;
  };
  const estado=el('p',{role:'status','aria-live':'polite'});
  const buscarBox=section('Buscar cliente');
  const busqueda=campo(buscarBox,'Nombre o DUI');
  const buscar=el('button',{type:'button'},'Buscar');
  const resultados=el('div');buscarBox.append(buscar,resultados);
  const perfilBox=section('Expediente del cliente seleccionado');
  const verPerfil=el('button',{type:'button'},'Ver ficha e historial');
  const perfilContenido=el('div');perfilBox.append(verPerfil,perfilContenido);
  const confirmarBox=section('Confirmar contrato y descontar existencias');
  confirmarBox.append(el('p',{},'Solo confirma contratos revisados. La operación registra la venta y descuenta existencias.'));
  const confirmarId=campo(confirmarBox,'ID del contrato a confirmar');
  const cargarDetalle=el('button',{type:'button'},'Revisar artículos y ubicaciones');
  const confirmacionLineas=el('div');
  const confirmarVenta=el('button',{type:'button'},'Confirmar venta y descontar inventario');
  confirmarVenta.disabled=true;
  confirmarBox.append(cargarDetalle,confirmacionLineas,confirmarVenta);
  let revision=null;
  let operacionConfirmacion=null;
  function invalidarRevision(){
    revision=null;operacionConfirmacion=null;confirmarVenta.disabled=true;
    confirmacionLineas.replaceChildren();
  }
  confirmarId.addEventListener('input',()=>{revisionSolicitud++;invalidarRevision();});
  let revisionSolicitud=0;
  let revisionEnCurso=false;
  cargarDetalle.onclick=()=>tarea(async()=>{
    if(revisionEnCurso)throw new Error('La revisión ya está en curso');
    revisionEnCurso=true;
    try {
    invalidarRevision();
    const solicitud=++revisionSolicitud;
    const contratoId=confirmarId.value.trim();
    if(!contratoId)throw new Error('Indica el identificador del contrato');
    cargarDetalle.disabled=true;
    let contrato;
    try {contrato=await api.detalleContrato(contratoId);}
    finally {cargarDetalle.disabled=false;}
    if(solicitud!==revisionSolicitud || confirmarId.value.trim()!==contratoId)
      throw new Error('El contrato cambió durante la revisión; vuelve a cargarlo');
    if(contrato.estado!=='borrador')throw new Error('Solo se pueden confirmar borradores');
    if(!contrato.articulos?.length)throw new Error('El contrato no tiene artículos');
    const centavosValidos=(valor)=>{
      if(valor===null||valor===undefined||String(valor).trim()==='')
        throw new Error('Importe ausente en el contrato');
      const n=Number(valor);
      if(!Number.isFinite(n)||n<0||n>999999999999.99||Math.abs(n*100-Math.round(n*100))>1e-7)
        throw new Error('Importe inválido en el contrato');
      return Math.round(n*100);
    };
    let totalCentavos=0;
    for(const articulo of contrato.articulos){
      const cantidad=Number(articulo.cantidad);
      if(!Number.isSafeInteger(cantidad)||cantidad<1||cantidad>999999999)
        throw new Error('Cantidad inválida en el contrato');
      totalCentavos+=centavosValidos(articulo.precio_credito_unitario)*cantidad;
    }
    const primaCentavos=centavosValidos(contrato.prima?.monto);
    if(!Number.isSafeInteger(totalCentavos)||totalCentavos>99999999999999||primaCentavos>totalCentavos)
      throw new Error('Importes de contrato inconsistentes; no se puede confirmar');
    if(contrato.saldo_inicial!==null&&contrato.saldo_inicial!==undefined&&
       centavosValidos(contrato.saldo_inicial)!==totalCentavos-primaCentavos)
      throw new Error('Saldo del contrato no coincide con el total menos la prima');
    const idsDetalles=new Set();
    for(const articulo of contrato.articulos){
      if(!articulo.detalle_id||idsDetalles.has(articulo.detalle_id))
        throw new Error('Identificadores de artículos ausentes o repetidos');
      idsDetalles.add(articulo.detalle_id);
    }
    confirmacionLineas.append(el('p',{},
      'Contrato: '+contrato.numero+' | Total: '+(totalCentavos/100).toFixed(2)+
      ' | Prima: '+(primaCentavos/100).toFixed(2)+
      ' | Saldo: '+((totalCentavos-primaCentavos)/100).toFixed(2)));
    revision={id:contrato.id,lineas:[]};
    for(const articulo of contrato.articulos){
      if(!articulo.detalle_id)throw new Error('Falta identificador de línea en la respuesta');
      const fila=el('label');
      fila.append(el('span',{},articulo.nombre+' × '+articulo.cantidad+' · ubicación de salida '));
      const ubicacion=el('select');
      ubicacion.append(el('option',{value:''},'Selecciona ubicación'),
        el('option',{value:'1'},'Ubicación 1'),el('option',{value:'2'},'Ubicación 2'));
      fila.append(ubicacion);confirmacionLineas.append(fila);
      revision.lineas.push({detalleId:articulo.detalle_id,ubicacion});
    }
    operacionConfirmacion=globalThis.crypto?.randomUUID?.();
    if(!operacionConfirmacion)throw new Error('Este navegador no admite identificadores seguros');
    confirmarVenta.disabled=false;
    return 'Revisa las ubicaciones antes de confirmar la venta';
    } finally {revisionEnCurso=false;}
  });
  let confirmacionEnCurso=false;
  confirmarVenta.onclick=()=>tarea(async()=>{
    if(confirmacionEnCurso)throw new Error('La confirmación ya está en curso');
    if(!revision||revision.id!==confirmarId.value.trim()||!operacionConfirmacion)
      throw new Error('Vuelve a revisar el contrato');
    const ubicaciones=revision.lineas.map(x=>({
      detalleId:x.detalleId,ubicacionId:Number(x.ubicacion.value)
    }));
    if(ubicaciones.some(x=>![1,2].includes(x.ubicacionId)))
      throw new Error('Selecciona la ubicación de cada artículo');
    if(!globalThis.confirm('¿Confirmar esta venta y descontar existencias? Esta acción afecta inventario.'))
      return 'Confirmación cancelada';
    confirmacionEnCurso=true;
    confirmarVenta.disabled=true;
    try{
      const ventaId=await api.confirmarContrato(revision.id,ubicaciones,operacionConfirmacion);
      invalidarRevision();
      return 'Venta confirmada: '+ventaId;
    }catch(e){
      confirmarVenta.disabled=false;
      throw e;
    }finally{
      confirmacionEnCurso=false;
    }
  });
  const clienteBox=section('Crear cliente');
  const nombre=campo(clienteBox,'Nombre completo');
  const dui=campo(clienteBox,'DUI');
  const telefono=campo(clienteBox,'Teléfono');
  const direccion=campo(clienteBox,'Dirección');
  const ubicacion=campo(clienteBox,'Ubicación');
  const vivienda=el('select',{'aria-label':'Tipo de vivienda'});
  vivienda.append(el('option',{value:''},'No indicado'),el('option',{value:'propia'},'Propia'),el('option',{value:'alquila'},'Alquila'));
  clienteBox.append(el('p',{},'Tipo de vivienda'),vivienda);
  const lugarTrabajo=campo(clienteBox,'Lugar de trabajo');
  const telefonoTrabajo=campo(clienteBox,'Teléfono del trabajo');
  const referencias=[1,2].map(n=>({
    nombre:campo(clienteBox,'Referencia '+n+' · Nombre'),
    telefono:campo(clienteBox,'Referencia '+n+' · Teléfono'),
    direccion:campo(clienteBox,'Referencia '+n+' · Dirección'),
    parentesco:campo(clienteBox,'Referencia '+n+' · Parentesco')
  }));
  const crearCliente=el('button',{type:'button'},'Crear cliente');
  clienteBox.append(crearCliente);
  const contratoBox=section('Crear contrato borrador');
  const numero=campo(contratoBox,'Número de contrato');
  const fecha=campo(contratoBox,'Fecha','date');
  const plan=el('select',{'aria-label':'Plan de pagos'});
  [['normal','Normal'],['6_pagos','6 pagos'],['3_pagos','3 pagos']].forEach(([v,t])=>plan.append(el('option',{value:v},t)));
  const frecuencia=el('select',{'aria-label':'Frecuencia de cobro'});
  [['semanal','Semanal'],['quincenal','Quincenal'],['mensual','Mensual']].forEach(([v,t])=>frecuencia.append(el('option',{value:v},t)));
  const ruta=campo(contratoBox,'Ruta');
  const diaCobro=campo(contratoBox,'Día de cobro');
  const cuota=campo(contratoBox,'Cuota','number');cuota.step='.01';
  const saldoInicial=campo(contratoBox,'Saldo inicial','number');saldoInicial.step='.01';
  const receptorAlterno=campo(contratoBox,'Persona que recibe la letra');
  const vendedor=el('select',{'aria-label':'Vendedor'});
  const item=el('select',{'aria-label':'Artículo'});
  const cantidad=campo(contratoBox,'Cantidad','number');cantidad.value='1';
  const precio=campo(contratoBox,'Precio al crédito','number');precio.step='.01';
  const comision=campo(contratoBox,'Comisión','number');comision.value='0';comision.step='.01';
  const prima=campo(contratoBox,'Prima','number');prima.value='0';prima.step='.01';
  const primaRecibida=el('input',{type:'checkbox'});
  const primaLabel=el('label');primaLabel.append(primaRecibida,el('span',{},' Prima entregada a caja y recibida por administración'));
  const agregar=el('button',{type:'button'},'Agregar artículo');
  const articulosLista=el('ul');
  const guardar=el('button',{type:'button'},'Guardar borrador');
  contratoBox.append(el('p',{},'Plan'),plan,el('p',{},'Frecuencia'),frecuencia,
    el('p',{},'Vendedor'),vendedor,el('p',{},'Artículo'),item,agregar,articulosLista,primaLabel,guardar);
  const histBox=section('Historial del vendedor');
  const verHistorial=el('button',{type:'button'},'Consultar historial');
  const histLista=el('div');histBox.append(verHistorial,histLista);
  root.append(estado);

  async function tarea(fn){
    estado.textContent='Procesando…';
    try{const mensaje=await fn();estado.textContent=mensaje||'Operación completada.'}
    catch(e){estado.textContent='Error: '+(e?.message||String(e))}
  }
  function opcion(select,value,label){select.append(el('option',{value},label))}
  async function cargarCatalogos(){
    // Solo campos mínimos: no mostrar DUI ni otros datos personales.
    const [v,i]=await Promise.all([
      supabase.rpc('inv_catalogo_vendedores'),
      supabase.rpc('inv_catalogo_articulos_contratos')
    ]);
    if(v.error)throw v.error;if(i.error)throw i.error;
    vendedor.replaceChildren();item.replaceChildren();
    for(const x of v.data||[])opcion(vendedor,x.id,x.nombre);
    for(const x of i.data||[])opcion(item,x.id,x.nombre);
  }
  let solicitudBusqueda=0;
  busqueda.addEventListener('input',()=>{solicitudBusqueda++;resultados.replaceChildren();});
  buscar.onclick=()=>tarea(async()=>{
    const solicitud=++solicitudBusqueda;
    const texto=busqueda.value.trim();
    if(texto.length<3||texto.length>100)throw new Error('Busca entre 3 y 100 caracteres');
    const rows=await api.buscarClientes(texto);
    if(solicitud!==solicitudBusqueda)return 'Búsqueda anterior descartada';
    resultados.replaceChildren();
    if(!rows?.length){resultados.append(el('p',{},'Sin resultados'));return}
    for(const r of rows){
      const b=el('button',{type:'button'},r.nombre+' · '+(r.dui_mostrado||'Sin DUI'));
      b.onclick=()=>{if(guardandoBorrador){estado.textContent='Espera a que termine el guardado';return;}state.clienteId=r.id;resultados.replaceChildren(el('p',{},'Cliente seleccionado: '+r.nombre))};
      resultados.append(b);
    }
  });
  verPerfil.onclick=()=>tarea(async()=>{
    if(!state.clienteId)throw new Error('Primero selecciona un cliente');
    const [ficha,contratos]=await Promise.all([
      api.fichaCliente(state.clienteId),api.historialCliente(state.clienteId)
    ]);
    perfilContenido.replaceChildren();
    perfilContenido.append(el('h4',{},ficha.nombre));
    perfilContenido.append(el('p',{},'Teléfono: '+(ficha.telefono||'No registrado')));
    perfilContenido.append(el('p',{},'Contratos registrados: '+contratos.length));
    for(const c of contratos){
      const linea=el('div');
      const boton=el('button',{type:'button'},'Ver '+c.numero+' · '+c.fecha);
      const detalle=el('div');
      boton.onclick=()=>tarea(async()=>{
        const x=await api.detalleContrato(c.contrato_id);
        detalle.replaceChildren();
        detalle.append(el('p',{},'Estado: '+x.estado+' · Plan: '+x.plan));
        for(const a of x.articulos||[]){
          detalle.append(el('p',{},a.nombre+' × '+a.cantidad+' · $'+a.precio_credito_unitario));
        }
      });
      linea.append(boton,detalle);perfilContenido.append(linea);
    }
  });
  let creandoCliente=false;
  crearCliente.onclick=()=>tarea(async()=>{
    if(creandoCliente)throw new Error('El cliente ya se está guardando');
    creandoCliente=true;crearCliente.disabled=true;
    try {
    const clienteNuevo=await api.crearCliente({
      nombre:nombre.value,dui:dui.value,telefono:telefono.value,
      direccion:direccion.value,ubicacion:ubicacion.value,vivienda:vivienda.value||null,
      lugarTrabajo:lugarTrabajo.value,telefonoTrabajo:telefonoTrabajo.value,
      referencias:referencias.filter(r=>r.nombre.value.trim()).map(r=>({
        nombre:r.nombre.value,telefono:r.telefono.value,direccion:r.direccion.value,
        parentesco:r.parentesco.value
      }))
    });
    if(!guardandoBorrador)state.clienteId=clienteNuevo;
    return 'Cliente creado: '+nombre.value.trim()+(guardandoBorrador?' · No se cambió el cliente del borrador en curso':' · Seleccionado');
    } finally {creandoCliente=false;crearCliente.disabled=false;}
  });
  agregar.onclick=()=>{
    if(guardandoBorrador){estado.textContent='Espera a que termine el guardado';return;}
    const q=Number(cantidad.value),p=Number(precio.value);
    if(state.items.length>=100){estado.textContent='Máximo 100 líneas por contrato';return;}
    if(!item.value||cantidad.value.trim()===''||precio.value.trim()===''||!Number.isSafeInteger(q)||q<=0||q>999999999||!Number.isFinite(p)||p<0||p>999999999999.99||Math.abs(p*100-Math.round(p*100))>1e-7){
      estado.textContent='Verifica artículo, cantidad entera y precio con hasta dos decimales.';return;
    }
    const selected=item.options[item.selectedIndex];
    if(!selected){estado.textContent='Selecciona un artículo del catálogo';return;}
    const line={itemId:item.value,nombre:selected.textContent,cantidad:Number(cantidad.value),precio:Number(precio.value)};
    state.items.push(line);
    const li=el('li',{},line.nombre+' × '+line.cantidad+' · $'+line.precio.toFixed(2));
    const quitar=el('button',{type:'button'},'Quitar');
    quitar.onclick=()=>{if(guardandoBorrador){estado.textContent='Espera a que termine el guardado';return;}const indice=state.items.indexOf(line);if(indice!==-1)state.items.splice(indice,1);li.remove()};
    li.append(quitar);articulosLista.append(li);
  };
  let guardandoBorrador=false;
  guardar.onclick=()=>tarea(async()=>{
    if(guardandoBorrador)throw new Error('El borrador ya se está guardando');
    guardandoBorrador=true;guardar.disabled=true;
    try{
    if(!state.clienteId)throw new Error('Selecciona o crea un cliente');
    if(!vendedor.value)throw new Error('Selecciona un vendedor');
    if(!numero.value.trim())throw new Error('Escribe el número del contrato');
    if(!fecha.value)throw new Error('Selecciona la fecha del contrato');
    if(!state.items.length)throw new Error('Agrega artículos');
    const clienteGuardado=state.clienteId;
    const articulosGuardados=state.items.map(linea=>({...linea}));
    const id=await api.crearContratoBorrador({
      numero:numero.value,clienteId:clienteGuardado,vendedorId:vendedor.value,
      fecha:fecha.value,modalidad:'credito',plan:plan.value,frecuencia:frecuencia.value,
      ruta:ruta.value,diaCobro:diaCobro.value,cuota:cuota.value||null,
      saldoInicial:saldoInicial.value||null,receptorAlterno:receptorAlterno.value,
      comision:comision.value,prima:prima.value,primaRecibida:primaRecibida.checked,
      articulos:articulosGuardados
    });
    state.items=[];articulosLista.replaceChildren();
    confirmarId.value=id;
    invalidarRevision();
    return 'Borrador creado: '+id+' · Puedes revisarlo para confirmar';
    } finally {guardandoBorrador=false;guardar.disabled=false;}
  });
  verHistorial.onclick=()=>tarea(async()=>{
    const rows=await api.historialVendedor(vendedor.value);
    histLista.replaceChildren();
    for(const r of rows||[]){
      histLista.append(el('p',{},[r.numero,r.fecha,r.cliente_nombre,r.estado,
        '$'+r.total_articulos,'Prima: '+r.prima_estado].join(' · ')));
    }
  });
  // El controlador se inicializa solo después de que el anfitrión haya autenticado al usuario.
  tarea(cargarCatalogos);
  return {api,state};
}
