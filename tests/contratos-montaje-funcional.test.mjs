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

test('cerrar sesión desmonta, limpia y libera el contenedor',async()=>{
 let evento,destruidos=0,desuscritos=0,limpiezas=0;
 globalThis.__montajeContratosPrueba=()=>({destruir(){destruidos++}});
 const root={replaceChildren(){limpiezas++}};
 const supabase={auth:{
  getUser:async()=>usuario('u1'),
  onAuthStateChange:fn=>{evento=fn;return {data:{subscription:{unsubscribe(){desuscritos++}}}}}
 },rpc:async()=>({data:[],error:null})};
 await modulo.montarContratosEnStaging({supabase,contenedor:root});
 evento('SIGNED_OUT',null);
 assert.equal(destruidos,1);
 assert.equal(desuscritos,1);
 assert.equal(limpiezas,1);
 await modulo.montarContratosEnStaging({supabase,contenedor:root});
 assert.equal(modulo.desmontarContratosEnStaging(root),true);
 assert.equal(modulo.desmontarContratosEnStaging(root),false);
 assert.equal(destruidos,2);
});
test('cambiar usuario desmonta incluso con sesión autenticada',async()=>{
 let evento,limpiezas=0;
 globalThis.__montajeContratosPrueba=()=>({destruir(){}});
 const root={replaceChildren(){limpiezas++}};
 const supabase={auth:{
  getUser:async()=>usuario('u1'),
  onAuthStateChange:fn=>{evento=fn;return {data:{subscription:{unsubscribe(){}}}}}
 },rpc:async()=>({data:[],error:null})};
 await modulo.montarContratosEnStaging({supabase,contenedor:root});
 evento('SIGNED_IN',{user:{id:'u2'}});
 assert.equal(limpiezas,1);
 assert.equal(modulo.desmontarContratosEnStaging(root),false);
});

test('cancelar mientras se verifica permiso impide montar y permite otro intento',async()=>{
 let liberar,montados=0;
 const espera=new Promise(resolve=>{liberar=resolve});
 globalThis.__montajeContratosPrueba=()=>{montados++;return {destruir(){}}};
 const root=contenedor();
 const supabase={auth:{getUser:async()=>usuario('u1')},rpc:async()=>{await espera;return {data:[],error:null}}};
 const intento=modulo.montarContratosEnStaging({supabase,contenedor:root});
 assert.equal(modulo.desmontarContratosEnStaging(root),true);
 liberar();
 await assert.rejects(intento,/Montaje cancelado/);
 assert.equal(montados,0);
 await modulo.montarContratosEnStaging({supabase,contenedor:root});
 assert.equal(montados,1);
});
test('error de observador de sesión destruye controlador y libera contenedor',async()=>{
 let destruidos=0,limpiezas=0;
 globalThis.__montajeContratosPrueba=()=>({destruir(){destruidos++}});
 const root={replaceChildren(){limpiezas++}};
 const supabase={auth:{
  getUser:async()=>usuario('u1'),
  onAuthStateChange:()=>{throw new Error('Observador no disponible')}
 },rpc:async()=>({data:[],error:null})};
 await assert.rejects(modulo.montarContratosEnStaging({supabase,contenedor:root}),/Observador no disponible/);
 assert.equal(destruidos,1);
 assert.equal(limpiezas,1);
 assert.equal(modulo.desmontarContratosEnStaging(root),false);
});
