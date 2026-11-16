import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const fuente=readFileSync(new URL('../prototipos/contratos-navegador-pwa-staging.js',import.meta.url),'utf8')
 .replace("import {montarContratosEnStaging,desmontarContratosEnStaging} from './contratos-montaje-staging.js';",
 "const montarContratosEnStaging=(x)=>globalThis.__montarPWA(x); const desmontarContratosEnStaging=(x)=>globalThis.__desmontarPWA(x);");
const {crearNavegadorContratosPWA}=await import('data:text/javascript;base64,'+Buffer.from(fuente).toString('base64'));
const sb={auth:{getUser:async()=>({data:{user:{id:'u1'}}})},rpc:async()=>({data:[],error:null})};
const root=()=>({replaceChildren(){}});
test('contratos usa cliente compartido y no hace login independiente',async()=>{
 let visto=null,desmontajes=0;
 globalThis.__montarPWA=async x=>{visto=x.supabase;};
 globalThis.__desmontarPWA=()=>{desmontajes++};
 const n=crearNavegadorContratosPWA({supabase:sb,contenedor:root(),mostrarModuloExterno:async()=>{}});
 assert.equal(await n.navegar('contratos'),true);
 assert.equal(visto,sb);
 assert.equal(n.moduloActual,'contratos');
 n.destruir();
 assert.ok(desmontajes>=2);
});
test('Deudas se delega al anfitrion sin desbloqueo simulado',async()=>{
 let llamado=null;
 globalThis.__desmontarPWA=()=>{};
 const n=crearNavegadorContratosPWA({supabase:sb,contenedor:root(),mostrarModuloExterno:async(modulo,args)=>{llamado=[modulo,args.supabase];}});
 assert.equal(await n.navegar('deudas'),true);
 assert.deepEqual(llamado,['deudas',sb]);
 n.destruir();
});
test('rechazo del anfitrion de Deudas no habilita modulo',async()=>{
 globalThis.__desmontarPWA=()=>{};
 const n=crearNavegadorContratosPWA({supabase:sb,contenedor:root(),mostrarModuloExterno:async()=>{throw new Error('Acceso a Deudas denegado');}});
 await assert.rejects(n.navegar('deudas'),/denegado/);
 assert.equal(n.moduloActual,null);
 n.destruir();
});
test('cambio rapido de modulo cancela montaje tardio de contratos',async()=>{
 let liberar;
 const espera=new Promise(resolve=>{liberar=resolve});
 globalThis.__montarPWA=async()=>{await espera};
 globalThis.__desmontarPWA=()=>{};
 const n=crearNavegadorContratosPWA({supabase:sb,contenedor:root(),mostrarModuloExterno:async()=>{}});
 const primero=n.navegar('contratos');
 assert.equal(await n.navegar('inventario'),true);
 liberar();
 assert.equal(await primero,false);
 assert.equal(n.moduloActual,'inventario');
 n.destruir();
});
test('destruccion invalida montaje pendiente y rechaza nuevas rutas',async()=>{
 let liberar;
 const espera=new Promise(resolve=>{liberar=resolve});
 globalThis.__montarPWA=async()=>{await espera};
 globalThis.__desmontarPWA=()=>{};
 const n=crearNavegadorContratosPWA({supabase:sb,contenedor:root(),mostrarModuloExterno:async()=>{}});
 const pendiente=n.navegar('contratos');
 n.destruir();
 liberar();
 assert.equal(await pendiente,false);
 await assert.rejects(n.navegar('inventario'),/destruido/);
});

test('ruta externa exige sesion autenticada antes de mostrar datos',async()=>{
 let llamados=0;
 const sinSesion={auth:{getUser:async()=>({data:{user:null},error:null})},rpc:sb.rpc};
 globalThis.__desmontarPWA=()=>{};
 const n=crearNavegadorContratosPWA({supabase:sinSesion,contenedor:root(),mostrarModuloExterno:async()=>{llamados++}});
 await assert.rejects(n.navegar('deudas'),/Inicia sesión/);
 assert.equal(llamados,0);
 n.destruir();
});
test('cambio de identidad durante apertura externa limpia pantalla',async()=>{
 let lecturas=0,limpiezas=0;
 const cambio={auth:{getUser:async()=>({data:{user:{id:++lecturas===1?'u1':'u2'}},error:null})},rpc:sb.rpc};
 globalThis.__desmontarPWA=()=>{};
 const n=crearNavegadorContratosPWA({supabase:cambio,contenedor:root(),mostrarModuloExterno:async()=>()=>{limpiezas++}});
 await assert.rejects(n.navegar('inventario'),/sesión cambió/);
 assert.equal(limpiezas,1);
 assert.equal(n.moduloActual,null);
 n.destruir();
});
test('navegacion tardia de Deudas no sustituye Inventario ni deja datos visibles',async()=>{
 let liberar,limpiezas=0;
 const espera=new Promise(resolve=>{liberar=resolve});
 globalThis.__desmontarPWA=()=>{};
 const n=crearNavegadorContratosPWA({supabase:sb,contenedor:root(),mostrarModuloExterno:async modulo=>{
  if(modulo==='deudas'){await espera;return ()=>{limpiezas++}}
  return ()=>{};
 }});
 const viejo=n.navegar('deudas');
 await Promise.resolve();
 assert.equal(await n.navegar('inventario'),true);
 liberar();
 assert.equal(await viejo,false);
 assert.equal(limpiezas,1);
 assert.equal(n.moduloActual,'inventario');
 n.destruir();
});
test('cambiar modulo y destruir ejecuta limpieza externa exactamente una vez',async()=>{
 let limpiezas=0;
 globalThis.__desmontarPWA=()=>{};
 globalThis.__montarPWA=async()=>{};
 const n=crearNavegadorContratosPWA({supabase:sb,contenedor:root(),mostrarModuloExterno:async()=>()=>{limpiezas++}});
 await n.navegar('inventario');
 await n.navegar('contratos');
 assert.equal(limpiezas,1);
 await n.navegar('deudas');
 n.destruir();
 assert.equal(limpiezas,2);
});
