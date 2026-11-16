/* Fail-closed controller for mounting the Deudas module. No DOM or storage reads here. */
(function(root){'use strict';
function createDebtModuleController({gate,load,show,hide,disconnect,hasPending,confirmPending}){
 if(!gate||!['unlock','verify','lock','reset'].every(k=>typeof gate[k]==='function'))throw Error('Gate inválido');
 for(const [name,fn] of Object.entries({load,show,hide,disconnect,hasPending,confirmPending}))
  if(typeof fn!=='function')throw Error('Callback inválido: '+name);
 let epoch=0,phase='locked',busy=false;
 function invalidate(){epoch++;phase='locked';hide()}
 async function open(password){
  if(busy)throw Error('Operación de acceso en curso');
  busy=true;const token=++epoch;phase='unlocking';hide();
  try{
   await gate.unlock(password);
   if(token!==epoch)throw Error('Acceso cancelado');
   if(!await gate.verify())throw Error('Autorización no confirmada por el servidor');
   if(token!==epoch)throw Error('Acceso cancelado');
   // Must only read localStorage and render AFTER server authorization.
   await load();
   if(token!==epoch)throw Error('Acceso cancelado');
   phase='open';show();return true;
  }catch(err){if(token===epoch){phase='locked';hide();gate.reset()}throw err}
  finally{busy=false}
 }
 async function verify(){
  if(phase!=='open')return false;
  const token=epoch;
  try{
   const ok=await gate.verify();
   if(token!==epoch)return false;
   if(!ok){invalidate();await disconnect();return false}
   return true;
  }catch(_){if(token===epoch){invalidate();await disconnect()}return false}
 }
 async function lock(){
  if(hasPending()&&!await confirmPending())return false;
  invalidate();gate.reset();
  await disconnect();
  // Remote lock failure must surface; never claim remote revocation.
  await gate.lock();return true;
 }
 async function logout(){invalidate();gate.reset();await disconnect()}
 // A new login may begin while a stale unlock promise is unresolved; old replies
 // are ignored by epoch checks, but cannot be allowed to reopen the module.
 function cancel(){invalidate();gate.reset()}
 return Object.freeze({open,verify,lock,logout,cancel,state:()=>phase});
}
const api=Object.freeze({createDebtModuleController});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.DebtModuleController=api;
})(typeof window!=='undefined'?window:null);
