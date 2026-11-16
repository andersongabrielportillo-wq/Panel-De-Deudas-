import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const fuente=readFileSync(new URL('../prototipos/contratos-montaje-staging.js',import.meta.url),'utf8')
 .replace("import {iniciarContratosDemo} from './contratos-ui-conectada.js';",
 "const iniciarContratosDemo=(args)=>globalThis.__montajeContratosPrueba(args);");
const modulo=await import('data:text/javascript;base64,'+Buffer.from(fuente).toString('base64'));
const usuario=id=>({data:{user:{id}},error:null});

test('dos contenedores independientes no comparten estado de montaje',async()=>{
 const eventos=[],destruidos=[];
 globalThis.__montajeContratosPrueba=({root})=>({destruir(){destruidos.push(root.id)}});
 const crear=(id)=>{const root={id,replaceChildren(){}};
  const supabase={auth:{getUser:async()=>usuario(id),
   onAuthStateChange:fn=>{eventos.push({id,fn});return {data:{subscription:{unsubscribe(){}}}}}},
   rpc:async()=>({data:[],error:null})};
  return {root,supabase};};
 const a=crear('admin'),b=crear('secretaria');
 await Promise.all([modulo.montarContratosEnStaging({supabase:a.supabase,contenedor:a.root}),
 modulo.montarContratosEnStaging({supabase:b.supabase,contenedor:b.root})]);
 eventos.find(x=>x.id==='admin').fn('SIGNED_OUT',null);
 assert.deepEqual(destruidos,['admin']);
 assert.equal(modulo.desmontarContratosEnStaging(a.root),false);
 assert.equal(modulo.desmontarContratosEnStaging(b.root),true);
 assert.deepEqual(destruidos,['admin','secretaria']);
});

test('evento TOKEN_REFRESHED de misma identidad conserva montaje',async()=>{
 let fn,destruidos=0;
 globalThis.__montajeContratosPrueba=()=>({destruir(){destruidos++}});
 const root={replaceChildren(){}};
 const supabase={auth:{getUser:async()=>usuario('u1'),
  onAuthStateChange:callback=>{fn=callback;return {data:{subscription:{unsubscribe(){}}}}}},
  rpc:async()=>({data:[],error:null})};
 await modulo.montarContratosEnStaging({supabase,contenedor:root});
 fn('TOKEN_REFRESHED',{user:{id:'u1'}});
 assert.equal(destruidos,0);
 assert.equal(modulo.desmontarContratosEnStaging(root),true);
 assert.equal(destruidos,1);
});

test('desmontaje de un contenedor no cierra la sesion global ni otro modulo',async()=>{
 let signOut=0,destruidos=0;
 globalThis.__montajeContratosPrueba=()=>({destruir(){destruidos++}});
 const root={replaceChildren(){}};
 const supabase={auth:{getUser:async()=>usuario('u1'),signOut:async()=>{signOut++}},
 rpc:async()=>({data:[],error:null})};
 await modulo.montarContratosEnStaging({supabase,contenedor:root});
 assert.equal(modulo.desmontarContratosEnStaging(root),true);
 assert.equal(signOut,0);
 assert.equal(destruidos,1);
});

test('no montar contratos si se revoca permiso durante la RPC',async()=>{
 let montajes=0;
 globalThis.__montajeContratosPrueba=()=>{montajes++;return {}};
 const supabase={auth:{getUser:async()=>usuario('u1'),
 },rpc:async()=>({data:null,error:{message:'Permiso revocado'}})};
 await assert.rejects(modulo.montarContratosEnStaging({supabase,contenedor:{replaceChildren(){}}}),/Permiso revocado/);
 assert.equal(montajes,0);
});

test('el selector de modulos sigue marcado como prototipo sin navegacion operativa',()=>{
 const html=readFileSync(new URL('../prototipos/selector-modulos.html',import.meta.url),'utf8');
 assert.match(html,/PROTOTIPO · NO PUBLICADO/);
 assert.match(html,/Solo vista previa visual/);
 assert.match(html,/Integración pendiente/);
 assert.match(html,/protección funcional/);
});
