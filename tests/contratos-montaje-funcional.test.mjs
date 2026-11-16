import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

// Ejecuta el código real de montaje en un módulo aislado; sustituye solo el
// controlador visual para no requerir DOM ni tocar servicios reales.
const fuente=readFileSync(new URL('../prototipos/contratos-montaje-staging.js',import.meta.url),'utf8')
  .replace("import {iniciarContratosDemo} from './contratos-ui-conectada.js';",
    "const iniciarContratosDemo=(args)=>globalThis.__montajeContratosPrueba(args);");
const modulo=await import('data:text/javascript;base64,'+Buffer.from(fuente).toString('base64'));
const contenedor=()=>({replaceChildren(){}});
const usuario=id=>({data:{user:{id}},error:null});

test('montaje real rechaza sesión no autenticada sin mostrar UI',async()=>{
 let llamados=0;
 globalThis.__montajeContratosPrueba=()=>{llamados++};
 const supabase={auth:{getUser:async()=>({data:{user:null},error:null})},rpc:async()=>({data:[],error:null})};
 await assert.rejects(modulo.montarContratosEnStaging({supabase,contenedor:contenedor()}),/Inicia sesión/);
 assert.equal(llamados,0);
});
test('montaje real bloquea rol sin permiso RPC',async()=>{
 let llamados=0;
 globalThis.__montajeContratosPrueba=()=>{llamados++};
 const supabase={auth:{getUser:async()=>usuario('u1')},rpc:async()=>({error:{message:'No autorizado'}})};
 await assert.rejects(modulo.montarContratosEnStaging({supabase,contenedor:contenedor()}),/Sin permiso/);
 assert.equal(llamados,0);
});
test('montaje real detecta cambio de identidad durante consulta',async()=>{
 let n=0,llamados=0;
 globalThis.__montajeContratosPrueba=()=>{llamados++};
 const supabase={auth:{getUser:async()=>usuario(++n===1?'u1':'u2')},rpc:async()=>({data:[],error:null})};
 await assert.rejects(modulo.montarContratosEnStaging({supabase,contenedor:contenedor()}),/sesión cambió/);
 assert.equal(llamados,0);
});
test('montaje real impide doble clic mientras verifica permisos',async()=>{
 let liberar;
 const espera=new Promise(resolve=>{liberar=resolve});
 globalThis.__montajeContratosPrueba=()=>({ok:true});
 const supabase={auth:{getUser:async()=>usuario('u1')},rpc:async()=>{await espera;return {data:[],error:null}}};
 const root=contenedor();
 const primera=modulo.montarContratosEnStaging({supabase,contenedor:root});
 await assert.rejects(modulo.montarContratosEnStaging({supabase,contenedor:root}),/ya montados/);
 liberar();
 assert.deepEqual(await primera,{ok:true});
});
test('montaje real permite reintentar después de error',async()=>{
 let permitir=false;
 globalThis.__montajeContratosPrueba=()=>({listo:true});
 const supabase={auth:{getUser:async()=>usuario('u1')},rpc:async()=>permitir?{data:[],error:null}:{error:{message:'No autorizado'}}};
 const root=contenedor();
 await assert.rejects(modulo.montarContratosEnStaging({supabase,contenedor:root}),/Sin permiso/);
 permitir=true;
 assert.deepEqual(await modulo.montarContratosEnStaging({supabase,contenedor:root}),{listo:true});
});
