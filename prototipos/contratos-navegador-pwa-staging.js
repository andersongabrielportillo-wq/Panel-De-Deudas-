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
    if(destruido||solicitud!==revision){
     limpiar();
     return false;
    }
    actual='contratos';
    return true;
   }catch(e){
    if(solicitud===revision)limpiar();
    if(destruido||solicitud!==revision)return false;
    throw e;
   }
  }
  // Nunca concede acceso a Deudas: el anfitrión debe verificarlo en backend.
  await mostrarModuloExterno(modulo,{supabase});
  if(destruido||solicitud!==revision)return false;
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
