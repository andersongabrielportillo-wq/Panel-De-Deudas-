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
  montajes.set(contenedor,true);
  try {
    const {data,error}=await supabase.auth.getUser();
    if(error || !data?.user?.id)throw new Error('Inicia sesión para acceder a contratos');
    const usuarioInicial=data.user.id;
    const permiso=await supabase.rpc('inv_catalogo_vendedores');
    if(permiso.error)throw new Error('Sin permiso para contratos: '+(permiso.error.message||'Acceso denegado'));
    // La sesión puede cambiar durante la RPC: nunca montar para un usuario distinto.
    const {data:sesionFinal,error:errorFinal}=await supabase.auth.getUser();
    if(errorFinal || !sesionFinal?.user?.id || sesionFinal.user.id!==usuarioInicial)
      throw new Error('La sesión cambió durante la verificación; vuelve a ingresar');
    // No crear interfaz si la comprobación de permisos falla.
    const controlador=iniciarContratosDemo({supabase,root:contenedor});
    montajes.set(contenedor,controlador);
    return controlador;
  }catch(e){
    montajes.delete(contenedor);
    throw e;
  }
}
