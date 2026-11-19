import test from 'node:test';
import assert from 'node:assert/strict';
const origin='https://dozcnytevqhoymzqlxah.supabase.co';
const key=process.env.CL_TEST_PUBLISHABLE_KEY;
if(!key)throw Error('Falta secreto CL_TEST_PUBLISHABLE_KEY');
async function call(path,body,token){
 const c=new AbortController(),timeout=setTimeout(()=>c.abort(),15000);
 try{
  const response=await fetch(origin+path,{method:'POST',signal:c.signal,headers:{apikey:key,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(body)});
  const raw=await response.text();let data;try{data=JSON.parse(raw)}catch{data=null}
  return {status:response.status,data};
 }finally{clearTimeout(timeout)}
}
async function login(email,password){
 if(!email||!password)throw Error('Faltan secretos de cuenta de laboratorio');
 const r=await call('/auth/v1/token?grant_type=password',{email,password});
 assert.equal(r.status,200,'Login de laboratorio falló con HTTP '+r.status);
 assert.ok(r.data?.access_token,'No llegó access_token');
 return r.data.access_token;
}
const memberAccounts=[
 ['admin',process.env.CL_TEST_ADMIN_EMAIL,process.env.CL_TEST_ADMIN_PASSWORD],
 ['secretaria',process.env.CL_TEST_SECRETARIA_EMAIL,process.env.CL_TEST_SECRETARIA_PASSWORD]
];
for(const [role,email,password] of memberAccounts){
 test('HTTP autenticado: '+role+' puede consultar catálogos',async()=>{
  const token=await login(email,password);
  for(const rpc of ['inv_catalogo_vendedores','inv_catalogo_articulos_contratos']){
   const r=await call('/rest/v1/rpc/'+rpc,{},token);
   assert.equal(r.status,200,role+' '+rpc+' HTTP '+r.status);
  }
 });
 test('HTTP autenticado: '+role+' puede buscar clientes sin escribir',async()=>{
  const token=await login(email,password);
  const r=await call('/rest/v1/rpc/inv_buscar_clientes',{p_busqueda:'zzzxxyy_no_existe'},token);
  assert.equal(r.status,200,role+' buscar clientes HTTP '+r.status);
  assert.ok(Array.isArray(r.data));
 });
 test('HTTP autenticado: '+role+' no puede leer tabla inv_clientes directamente',async()=>{
  const token=await login(email,password);
  const c=new AbortController(),timeout=setTimeout(()=>c.abort(),15000);
  try{
   const r=await fetch(origin+'/rest/v1/inv_clientes?select=id&limit=1',{headers:{apikey:key,Authorization:'Bearer '+token},signal:c.signal});
   assert.ok([401,403,404].includes(r.status),role+' tabla inv_clientes HTTP '+r.status);
  }finally{clearTimeout(timeout)}
 });
}
test('HTTP: credenciales de tercero sin membresía no acceden a RPC protegidas', {skip:!process.env.CL_TEST_OUTSIDER_EMAIL||!process.env.CL_TEST_OUTSIDER_PASSWORD},async()=>{
 const token=await login(process.env.CL_TEST_OUTSIDER_EMAIL,process.env.CL_TEST_OUTSIDER_PASSWORD);
 for(const rpc of ['inv_catalogo_vendedores','inv_buscar_clientes']){
  const r=await call('/rest/v1/rpc/'+rpc,rpc==='inv_buscar_clientes'?{p_busqueda:'prueba'}:{},token);
  assert.ok([400,401,403].includes(r.status),'tercero '+rpc+' HTTP '+r.status);
 }
});
