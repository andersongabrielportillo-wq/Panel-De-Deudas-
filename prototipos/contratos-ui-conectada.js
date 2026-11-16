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
  const clienteBox=section('Crear cliente');
  const nombre=campo(clienteBox,'Nombre completo');
  const dui=campo(clienteBox,'DUI');
  const telefono=campo(clienteBox,'Teléfono');
  const direccion=campo(clienteBox,'Dirección');
  const crearCliente=el('button',{type:'button'},'Crear cliente');
  clienteBox.append(crearCliente);
  const contratoBox=section('Crear contrato borrador');
  const numero=campo(contratoBox,'Número de contrato');
  const fecha=campo(contratoBox,'Fecha','date');
  const vendedor=el('select',{'aria-label':'Vendedor'});
  const item=el('select',{'aria-label':'Artículo'});
  const cantidad=campo(contratoBox,'Cantidad','number');cantidad.value='1';
  const precio=campo(contratoBox,'Precio al crédito','number');precio.step='.01';
  const comision=campo(contratoBox,'Comisión','number');comision.value='0';comision.step='.01';
  const prima=campo(contratoBox,'Prima','number');prima.value='0';prima.step='.01';
  const primaRecibida=el('input',{type:'checkbox'});
  const primaLabel=el('label');primaLabel.append(primaRecibida,el('span',{},' Prima recibida por vendedor'));
  const agregar=el('button',{type:'button'},'Agregar artículo');
  const articulosLista=el('ul');
  const guardar=el('button',{type:'button'},'Guardar borrador');
  contratoBox.append(el('p',{},'Vendedor'),vendedor,el('p',{},'Artículo'),item,agregar,articulosLista,primaLabel,guardar);
  const histBox=section('Historial del vendedor');
  const verHistorial=el('button',{type:'button'},'Consultar historial');
  const histLista=el('div');histBox.append(verHistorial,histLista);
  root.append(estado);

  async function tarea(fn){
    estado.textContent='Procesando…';
    try{await fn();estado.textContent='Operación completada.'}
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
  buscar.onclick=()=>tarea(async()=>{
    const rows=await api.buscarClientes(busqueda.value);
    resultados.replaceChildren();
    if(!rows?.length){resultados.append(el('p',{},'Sin resultados'));return}
    for(const r of rows){
      const b=el('button',{type:'button'},r.nombre+' · '+(r.dui_mostrado||'Sin DUI'));
      b.onclick=()=>{state.clienteId=r.id;resultados.append(el('p',{},'Cliente seleccionado: '+r.nombre))};
      resultados.append(b);
    }
  });
  crearCliente.onclick=()=>tarea(async()=>{
    state.clienteId=await api.crearCliente({
      nombre:nombre.value,dui:dui.value,telefono:telefono.value,
      direccion:direccion.value,referencias:[]
    });
  });
  agregar.onclick=()=>{
    if(!item.value||Number(cantidad.value)<=0||Number(precio.value)<0)return;
    const selected=item.options[item.selectedIndex];
    const line={itemId:item.value,nombre:selected.textContent,cantidad:Number(cantidad.value),precio:Number(precio.value)};
    state.items.push(line);
    const li=el('li',{},line.nombre+' × '+line.cantidad+' · $'+line.precio.toFixed(2));
    const quitar=el('button',{type:'button'},'Quitar');
    quitar.onclick=()=>{state.items.splice(state.items.indexOf(line),1);li.remove()};
    li.append(quitar);articulosLista.append(li);
  };
  guardar.onclick=()=>tarea(async()=>{
    if(!state.clienteId)throw new Error('Selecciona o crea un cliente');
    if(!vendedor.value)throw new Error('Selecciona un vendedor');
    if(!state.items.length)throw new Error('Agrega artículos');
    const id=await api.crearContratoBorrador({
      numero:numero.value,clienteId:state.clienteId,vendedorId:vendedor.value,
      fecha:fecha.value,modalidad:'credito',plan:'normal',frecuencia:'semanal',
      comision:comision.value,prima:prima.value,primaRecibida:primaRecibida.checked,
      articulos:state.items
    });
    state.items=[];articulosLista.replaceChildren();
    estado.textContent='Borrador creado: '+id;
  });
  verHistorial.onclick=()=>tarea(async()=>{
    const rows=await api.historialVendedor(vendedor.value);
    histLista.replaceChildren();
    for(const r of rows||[]){
      histLista.append(el('p',{},[r.numero,r.fecha,r.cliente_nombre,r.estado,
        '$'+r.total_articulos,'Prima: '+r.prima_estado].join(' · ')));
    }
  });
  // No cargar catálogos sin que el usuario inicialice la pantalla autenticada.
  tarea(cargarCatalogos);
  return {api,state};
}
