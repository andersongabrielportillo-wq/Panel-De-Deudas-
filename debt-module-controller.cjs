/* Fail-closed controller for Deudas; no direct DOM, storage or network access. */
(function(root){'use strict';
function createDebtModuleController({gate,load,show,hide,disconnect,hasPending,confirmPending}){
 if(!gate||!['unlock','verify','lock','reset'].every(k=>typeof gate[k]==='function'))throw Error('Gate inválido');
 for(const [name,fn] of Object.entries({load,show,hide,disconnect,hasPending,confirmPending}))
  if(typeof fn!=='function')throw Error('Callback inválido: '+name);
 let epoch=0,phase='locked',busy=false,locking=false;
 function invalidate(){epoch++;phase='locked';hide()}
 async function open(password){
  if(busy||locking)throw Error('Operación de acceso en curso');
  busy=true;const token=++epoch;phase='unlocking';hide();
  try{
   await gate.unlock(password);
   if(token!==epoch)throw Error('Acceso cancelado');
   if(!await gate.verify())throw Error('Autorización no confirmada por el servidor');
   if(token!==epoch)throw Error('Acceso cancelado');
   // Only read the local cache after server approval.
   await load();
   if(token!==epoch)throw Error('Acceso cancelado');
   // Long-running loads may outlive the server authorization window.
   if(!await gate.verify())throw Error('Autorización caducada durante la carga');
   if(token!==epoch)throw Error('Acceso cancelado');
   phase='open';show();return true;
  }catch(err){if(token===epoch){invalidate();gate.reset();await disconnect()}throw err}
  finally{busy=false}
 }
 async function verify(){
  if(phase!=='open')return false;
  const token=epoch;
  try{
   const ok=await gate.verify();
   if(token!==epoch)return false;
   if(!ok){invalidate();gate.reset();await disconnect();return false}
   return true;
  }catch(_){if(token===epoch){invalidate();gate.reset();await disconnect()}return false}
 }
 async function lock(){
  if(locking)throw Error('Bloqueo en curso');
  locking=true;
  try{
   if(hasPending()&&!await confirmPending())return false;
   invalidate();gate.reset();
   try{await disconnect()}finally{
    // Even if channel teardown fails, attempt server revocation.
    await gate.lock();
   }
   return true;
  }finally{locking=false}
 }
 async function logout(){invalidate();gate.reset();await disconnect()}
 function cancel(){invalidate();gate.reset()}
 return Object.freeze({open,verify,lock,logout,cancel,state:()=>phase});
}
const api=Object.freeze({createDebtModuleController});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.DebtModuleController=api;
})(typeof window!=='undefined'?window:null);
