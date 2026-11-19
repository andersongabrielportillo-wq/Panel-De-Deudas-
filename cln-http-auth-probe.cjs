// Read-only authenticated HTTP audit for CL Nexus cutover.
// Requires the real signed-in Supabase client already running in user's PWA.
// Does NOT log identities, emails, JWTs, passwords, raw debts, or inventory content.
// No writes, no password attempts, no lock/unlock side effects.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 else root.CLNHttpAuthProbe=Object.freeze(api);
})(typeof window!=='undefined'?window:globalThis,function(){
 'use strict';
 function fail(message){throw new Error(message)}
 async function probe({client,expectedDebts=1,expectedItems=190}){
  if(!client?.auth?.getUser||!client?.rpc||!client?.from)fail('Cliente de sesión incompleto');
  const userResult=await client.auth.getUser();
  if(userResult.error||!userResult.data?.user?.id)fail('Sesión HTTP no autenticada');
  const status=await client.rpc('has_debts_unlock');
  if(status.error)fail('RPC de desbloqueo no accesible por HTTP: '+String(status.error.code||'servidor'));
  if(typeof status.data!=='boolean')fail('Respuesta inesperada del estado de Deudas');
  const unlocked=status.data;
  const debtResult=await client.from('debts').select('id',{count:'exact',head:true});
  if(debtResult.error)fail('Lectura HTTP de Deudas fallida: '+String(debtResult.error.code||'servidor'));
  if(typeof debtResult.count!=='number')fail('Deudas no devolvió conteo HTTP');
  if(unlocked&&debtResult.count!==expectedDebts)fail('Deudas desbloqueadas: conteo distinto al respaldo; NO PUBLICAR');
  if(!unlocked&&debtResult.count!==0)fail('CRÍTICO: Deudas visibles sin contraseña adicional; NO PUBLICAR');
  const items=await client.rpc('inv_catalogo_articulos_admin');
  if(items.error)fail('CL Nexus catálogo no accesible con la sesión: '+String(items.error.code||'servidor'));
  if(!Array.isArray(items.data)||items.data.length!==expectedItems)
   fail('Catálogo no coincide con los 190 registros esperados; NO PUBLICAR');
  const sellers=await client.rpc('inv_catalogo_vendedores');
  if(sellers.error||!Array.isArray(sellers.data))fail('RPC de Vendedores no accesible con la sesión');
  return {
   authenticated:true,
   debtState:unlocked?'desbloqueada':'bloqueada',
   visibleDebtRows:debtResult.count,
   inventoryItems:items.data.length,
   vendorsRead:true,
   noWriteOperations:true,
   pass:true
  };
 }
 return {probe};
});
