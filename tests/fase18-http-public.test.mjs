import test from 'node:test';
import assert from 'node:assert/strict';
const base='https://dozcnytevqhoymzqlxah.supabase.co';
async function request(path,options={}){
 const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),12000);
 try{return await fetch(base+path,{...options,signal:controller.signal,redirect:'manual'});}finally{clearTimeout(timer)}
}
test('HTTP real: RPC de clientes rechaza petición sin apikey/JWT',async()=>{
 const r=await request('/rest/v1/rpc/inv_buscar_clientes',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({p_busqueda:'prueba'})});
 assert.ok([401,403].includes(r.status),'se esperaba rechazo 401/403; recibido '+r.status);
});
test('HTTP real: RPC de contratos rechaza petición sin apikey/JWT',async()=>{
 const r=await request('/rest/v1/rpc/inv_confirmar_contrato',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});
 assert.ok([401,403].includes(r.status),'se esperaba rechazo 401/403; recibido '+r.status);
});
test('HTTP real: tablas de clientes rechazan petición sin apikey/JWT',async()=>{
 const r=await request('/rest/v1/inv_clientes?select=id&limit=1');
 assert.ok([401,403].includes(r.status),'se esperaba rechazo 401/403; recibido '+r.status);
});
