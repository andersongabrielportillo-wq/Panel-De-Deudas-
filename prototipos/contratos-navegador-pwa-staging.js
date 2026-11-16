/**
 * Adaptador de navegación de contratos para el anfitrión PWA (solo staging).
 * Recibe el mismo cliente Supabase autenticado de la PWA; NO crea otro login.
 * El anfitrión sigue siendo dueño de Inventario, Deudas y signOut global.
 */
import {montarContratosEnStaging,desmontarContratosEnStaging} from './contratos-montaje-staging.js';

export function crearNavegadorContratosPWA({supabase,contenedor,mostrarModuloExterno}={}){
 if(!supabase?.auth?.getUser||typeof supabase.rpc!=='function')
  throw new Error('Falta el cliente Supabase autenticado del anfitrión');
 if(!contenedor||typeof contenedor.replaceChildren!=='function')
  throw new Error('Falta contenedor de contratos');
 if(typeof mostrarModuloExterno!=='function')
  throw new Error('El anfitrión debe implementar navegación externa');
 let actual=null,revision=0,destruido=false;
 const limpiar=()=>{desmontarContratosEnStaging(contenedor);contenedor.replaceChildren();};
 async function navegar(modulo){
  if(destruido)throw new Error('Navegador destruido');
  if(!['contratos','inventario','deudas'].includes(modulo))throw new Error('Módulo desconocido');
  const solicitud=++revision;
  limpiar();
  actual=null;
  if(modulo==='contratos'){
   try{
    await montarContratosEnStaging({supabase,contenedor});
    if(destruido||solicitud!==revision)return false;
    actual='contratos';
    return true;
   }catch(e){
    if(solicitud===revision)limpiar();
    if(destruido||solicitud!==revision)return false;
    throw e;
   }
  }
  // La ruta externa no se abre sin sesión. El anfitrión aplica sus propios permisos backend.
  const {data:inicio,error:errorInicio}=await supabase.auth.getUser();
  if(destruido||solicitud!==revision)return false;
  if(errorInicio||!inicio?.user?.id)throw new Error('Inicia sesión antes de abrir el módulo');
  const usuario=inicio.user.id;
  await mostrarModuloExterno(modulo,{supabase});
  if(destruido||solicitud!==revision)return false;
  const {data:final,error:errorFinal}=await supabase.auth.getUser();
  if(destruido||solicitud!==revision)return false;
  if(errorFinal||final?.user?.id!==usuario){
   // El anfitrión debe limpiar su módulo externo al cambiar de usuario.
   throw new Error('La sesión cambió durante la navegación; vuelve a ingresar');
  }
  actual=modulo;
  return true;
 }
 function destruir(){
  if(destruido)return;
  destruido=true;revision++;
  limpiar();
 }
 return Object.freeze({navegar,destruir,get moduloActual(){return actual;}});
}
