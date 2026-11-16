import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {createDebtModuleController}=require('../debt-module-controller.cjs');
function fixture({valid=true,pending=false,confirm=true,remoteLockError=false}={}){
 const events=[];
 const gate={unlock:async()=>{events.push('unlock')},verify:async()=>{events.push('verify');return valid},reset:()=>events.push('reset'),lock:async()=>{events.push('remoteLock');if(remoteLockError)throw Error('sin red')}};
 const controller=createDebtModuleController({gate,load:async()=>events.push('load'),show:()=>events.push('show'),hide:()=>events.push('hide'),disconnect:async()=>events.push('disconnect'),hasPending:()=>pending,confirmPending:async()=>confirm});
 return {events,controller};
}
test('la caché solo se lee tras desbloqueo y verificación del servidor',async()=>{
 const {events,controller}=fixture();await controller.open('temporal');
 assert.ok(events.indexOf('verify')<events.indexOf('load'));assert.ok(events.indexOf('load')<events.indexOf('show'));assert.equal(controller.state(),'open');
});
test('sin permiso del servidor jamás carga ni muestra datos',async()=>{
 const {events,controller}=fixture({valid:false});
 await assert.rejects(controller.open('temporal'),/Autorización/);
 assert.equal(events.includes('load'),false);assert.equal(events.includes('show'),false);assert.equal(controller.state(),'locked');
});
test('pendientes offline impiden bloqueo no confirmado',async()=>{
 const {events,controller}=fixture({pending:true,confirm:false});await controller.open('temporal');
 assert.equal(await controller.lock(),false);assert.equal(controller.state(),'open');assert.equal(events.includes('remoteLock'),false);
});
test('bloqueo primero oculta y desconecta, luego revoca servidor',async()=>{
 const {events,controller}=fixture();await controller.open('temporal');await controller.lock();
 assert.ok(events.lastIndexOf('hide')<events.lastIndexOf('remoteLock'));
 assert.ok(events.indexOf('disconnect')<events.lastIndexOf('remoteLock'));
 assert.equal(controller.state(),'locked');
});
test('error de bloqueo remoto se informa y datos permanecen ocultos',async()=>{
 const {controller}=fixture({remoteLockError:true});await controller.open('temporal');
 await assert.rejects(controller.lock(),/sin red/);assert.equal(controller.state(),'locked');
});
test('logout cancela desbloqueo tardío y nunca muestra datos',async()=>{
 let resolveUnlock;const events=[];
 const gate={unlock:()=>new Promise(r=>resolveUnlock=r),verify:async()=>true,lock:async()=>{},reset:()=>{}};
 const controller=createDebtModuleController({gate,load:async()=>events.push('load'),show:()=>events.push('show'),hide:()=>events.push('hide'),disconnect:async()=>events.push('disconnect'),hasPending:()=>false,confirmPending:async()=>true});
 const opening=controller.open('temporal');await controller.logout();resolveUnlock();
 await assert.rejects(opening,/cancelado/);assert.equal(events.includes('load'),false);assert.equal(events.includes('show'),false);
});
test('verificación caducada oculta y desconecta el módulo',async()=>{
 let valid=true;const events=[];
 const gate={unlock:async()=>{},verify:async()=>valid,lock:async()=>{},reset:()=>{}};
 const controller=createDebtModuleController({gate,load:async()=>{},show:()=>{},hide:()=>events.push('hide'),disconnect:async()=>events.push('disconnect'),hasPending:()=>false,confirmPending:async()=>true});
 await controller.open('temporal');valid=false;assert.equal(await controller.verify(),false);
 assert.equal(controller.state(),'locked');assert.ok(events.includes('disconnect'));
});

test('carga larga que pierde autorización no muestra deudas',async()=>{
 const events=[];let checks=0;
 const gate={unlock:async()=>{},verify:async()=>++checks===1,lock:async()=>{},reset:()=>events.push('reset')};
 const controller=createDebtModuleController({gate,load:async()=>events.push('load'),show:()=>events.push('show'),hide:()=>events.push('hide'),disconnect:async()=>events.push('disconnect'),hasPending:()=>false,confirmPending:async()=>true});
 await assert.rejects(controller.open('temporal'),/caducada/);
 assert.equal(events.includes('load'),true);assert.equal(events.includes('show'),false);
 assert.equal(controller.state(),'locked');assert.ok(events.includes('disconnect'));
});
test('desconexión fallida no omite revocación del servidor',async()=>{
 let revoked=0;const gate={unlock:async()=>{},verify:async()=>true,lock:async()=>{revoked++},reset:()=>{}};
 const controller=createDebtModuleController({gate,load:async()=>{},show:()=>{},hide:()=>{},disconnect:async()=>{throw Error('canal caído')},hasPending:()=>false,confirmPending:async()=>true});
 await controller.open('temporal');
 await assert.rejects(controller.lock(),/canal caído/);
 assert.equal(revoked,1);assert.equal(controller.state(),'locked');
});
test('dos solicitudes de bloqueo no pueden superponerse',async()=>{
 let release;const gate={unlock:async()=>{},verify:async()=>true,lock:()=>new Promise(r=>release=r),reset:()=>{}};
 const controller=createDebtModuleController({gate,load:async()=>{},show:()=>{},hide:()=>{},disconnect:async()=>{},hasPending:()=>false,confirmPending:async()=>true});
 await controller.open('temporal');
 const first=controller.lock();await assert.rejects(controller.lock(),/Bloqueo en curso/);
 release();await first;assert.equal(controller.state(),'locked');
});
test('un bloqueo no confirmado por cambios offline no revoca ni oculta el módulo',async()=>{
 let revoked=0;const events=[];const gate={unlock:async()=>{},verify:async()=>true,lock:async()=>{revoked++},reset:()=>{}};
 const controller=createDebtModuleController({gate,load:async()=>{},show:()=>{},hide:()=>events.push('hide'),disconnect:async()=>{},hasPending:()=>true,confirmPending:async()=>false});
 await controller.open('temporal');const count=events.length;
 assert.equal(await controller.lock(),false);assert.equal(controller.state(),'open');assert.equal(revoked,0);assert.equal(events.length,count);
});
