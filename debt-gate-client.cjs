/* Debt module server-gate client. Never stores password or grants local-only access. */
(function(root){'use strict';
function createDebtGate({client,workspaceId}){
 if(!client||typeof client.rpc!=='function')throw Error('Cliente Supabase inválido');
 if(typeof workspaceId!=='string'||!/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(workspaceId))throw Error('Workspace inválido');
 let unlocked=false,epoch=0,expiresAt=0,lockPending=false,unlockPending=false;
 function reset(){epoch++;unlocked=false;expiresAt=0}
 async function unlock(password){
  if(typeof password!=='string'||!password)throw Error('Contraseña requerida');
  if(lockPending)throw Error('Bloqueo en curso');
  if(unlockPending)throw Error('Desbloqueo en curso');
  unlockPending=true;reset();const current=epoch;
  try {
   const {data,error}=await client.rpc('debt_unlock',{p_workspace_id:workspaceId,p_password:password});
   if(current!==epoch)throw Error('Sesión modificada durante desbloqueo');
   if(error)throw Error(error.message||'Acceso denegado');
   const expiry=data?Date.parse(data):NaN;
   if(!Number.isFinite(expiry)||expiry<=Date.now())throw Error('Contraseña incorrecta o acceso expirado');
   // Password is not retained; RLS must independently validate every read and write.
   unlocked=true;expiresAt=expiry;return expiry;
  } finally {unlockPending=false}
 }
 async function verify(){
  if(!unlocked||Date.now()>=expiresAt){reset();return false}
  const current=epoch;
  const {data,error}=await client.rpc('debt_access_valid',{p_workspace_id:workspaceId});
  if(current!==epoch)return false;
  if(error||data!==true){reset();return false}
  return true;
 }
 async function lock(){
  reset();lockPending=true;
  try {const {error}=await client.rpc('debt_lock',{p_workspace_id:workspaceId});
    if(error)throw Error(error.message||'No se pudo bloquear en el servidor');
  } finally {lockPending=false}
 }
 return Object.freeze({unlock,verify,lock,reset,isUnlocked:()=>unlocked&&Date.now()<expiresAt});
}
const api=Object.freeze({createDebtGate});
if(typeof module!=='undefined'&&module.exports)module.exports=api;
if(root)root.DebtGateClient=api;
})(typeof window!=='undefined'?window:null);
