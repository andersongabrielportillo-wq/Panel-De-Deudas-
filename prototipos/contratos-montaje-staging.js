/**
 * Entrada de montaje para staging: el anfitrión entrega su cliente Supabase YA autenticado.
 * No contiene URL, anon key, service_role ni contraseñas.
 * Nunca montar sin comprobar sesión y acceso real a RPCs.
 */
import {iniciarContratosDemo} from './contratos-ui-conectada.js';

const montajes=new WeakMap();

export async function montarContratosEnStaging({supabase,contenedor}={}) {
  if(!contenedor || typeof contenedor.replaceChildren!=='function')
    throw new Error('Falta el contenedor de contratos');
  if(!supabase?.auth?.getUser || typeof supabase.rpc!=='function')
    throw new Error('Se requiere la sesión Supabase del anfitrión');
  if(montajes.has(contenedor))throw new Error('Contratos ya montados en este contenedor');
  // Se reserva antes de cualquier await para impedir doble montaje por clics rápidos.
  const pendiente={cancelado:false};
  montajes.set(contenedor,pendiente);
  let cancelado=false;
  let registroCreado=null;
  try {
    const {data,error}=await supabase.auth.getUser();
    if(pendiente.cancelado)throw new Error('Montaje cancelado');
    if(error || !data?.user?.id)throw new Error('Inicia sesión para acceder a contratos');
    const usuarioInicial=data.user.id;
    const permiso=await supabase.rpc('inv_catalogo_vendedores_manual');
    if(pendiente.cancelado)throw new Error('Montaje cancelado');
    if(permiso.error)throw new Error('Sin permiso para contratos: '+(permiso.error.message||'Acceso denegado'));
    // La sesión puede cambiar durante la RPC: nunca montar para un usuario distinto.
    const {data:sesionFinal,error:errorFinal}=await supabase.auth.getUser();
    if(errorFinal || !sesionFinal?.user?.id || sesionFinal.user.id!==usuarioInicial)
      throw new Error('La sesión cambió durante la verificación; vuelve a ingresar');
    if(cancelado||pendiente.cancelado)throw new Error('Montaje cancelado');
    // No crear interfaz si la comprobación de permisos falla.
    const controlador=iniciarContratosDemo({supabase,root:contenedor});
    const registro={controlador,supabase,usuarioInicial,cancelar:null};
    const cancelar=()=>{
      if(cancelado)return;
      cancelado=true;
      registro.suscripcion?.unsubscribe?.();
      controlador.destruir?.();
      contenedor.replaceChildren();
      if(montajes.get(contenedor)===registro)montajes.delete(contenedor);
    };
    registro.cancelar=cancelar;
    registroCreado=registro;
    montajes.set(contenedor,registro);
    if(typeof supabase.auth.onAuthStateChange==='function'){
      const {data:escucha,error:errorEscucha}=supabase.auth.onAuthStateChange((_evento,sesion)=>{
        if(!sesion?.user?.id || sesion.user.id!==usuarioInicial)cancelar();
      });
      if(errorEscucha){cancelar();throw errorEscucha;}
      registro.suscripcion=escucha?.subscription;
      if(cancelado)registro.suscripcion?.unsubscribe?.();
    }
    return controlador;
  }catch(e){
    if(registroCreado)registroCreado.cancelar();
    if(montajes.get(contenedor)===pendiente)montajes.delete(contenedor);
    throw e;
  }
}

/** Desmonta la interfaz sin cerrar la sesión global del anfitrión. */
export function desmontarContratosEnStaging(contenedor){
 const registro=montajes.get(contenedor);
 if(!registro)return false;
 if(!registro.cancelar){
   registro.cancelado=true;
   montajes.delete(contenedor);
   return true;
 }
 registro.cancelar();
 return true;
}
