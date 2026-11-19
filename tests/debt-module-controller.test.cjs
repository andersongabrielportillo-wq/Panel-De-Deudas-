'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {createDebtModuleController}=require('../debt-module-controller.cjs');
function fixture({approved=true,pending=false,confirm=true,load=async()=>{}}={}){
 const events=[];
 const gate={unlock:async()=>{events.push('unlock')},verify:async()=>{events.push('verify');return approved},lock:async()=>{events.push('revoke')},reset:()=>events.push('reset')};
 const controller=createDebtModuleController({gate,load,show:()=>events.push('show'),hide:()=>events.push('hide'),disconnect:async()=>events.push('disconnect'),hasPending:()=>pending,confirmPending:async()=>confirm});
 return {controller,events};
}
test('server authorization is checked before and after local data load',async()=>{const x=fixture();await x.controller.open('synthetic');assert.deepEqual(x.events.slice(0,5),['hide','unlock','verify','verify','show']);assert.equal(x.controller.state(),'open')});
test('server denial never exposes Deudas',async()=>{const x=fixture({approved:false});await assert.rejects(x.controller.open('synthetic'),/Autorización/);assert.equal(x.events.includes('show'),false);assert.equal(x.controller.state(),'locked')});
test('pending unsynced changes can cancel lock',async()=>{const x=fixture({pending:true,confirm:false});await x.controller.open('synthetic');assert.equal(await x.controller.lock(),false);assert.equal(x.controller.state(),'open');assert.equal(x.events.includes('revoke'),false)});
test('approved lock hides module and revokes server grant',async()=>{const x=fixture();await x.controller.open('synthetic');assert.equal(await x.controller.lock(),true);assert.equal(x.controller.state(),'locked');assert.equal(x.events.at(-1),'revoke')});
test('logout hides module, disconnects and revokes server grant',async()=>{const x=fixture();await x.controller.open('synthetic');await x.controller.logout();assert.equal(x.controller.state(),'locked');assert.deepEqual(x.events.slice(-4),['hide','reset','disconnect','revoke'])});
test('cancel during in-flight load prevents module exposure',async()=>{let release;const wait=new Promise(r=>release=r);let loading;const started=new Promise(r=>loading=r);const x=fixture({load:async()=>{loading();await wait}});const attempt=x.controller.open('synthetic');await started;x.controller.cancel();release();await assert.rejects(attempt,/cancelado/);assert.equal(x.controller.state(),'locked');assert.equal(x.events.includes('show'),false)});

test('logout still revokes server grant when disconnect fails',async()=>{
 const events=[];
 const gate={unlock:async()=>{},verify:async()=>true,reset:()=>events.push('reset'),lock:async()=>events.push('revoke')};
 const controller=createDebtModuleController({gate,load:async()=>{},show:()=>{},hide:()=>events.push('hide'),disconnect:async()=>{events.push('disconnect');throw Error('channel failure')},hasPending:()=>false,confirmPending:async()=>true});
 await controller.open('synthetic');
 await assert.rejects(controller.logout(),/channel failure/);
 assert.equal(controller.state(),'locked');
 assert.equal(events.at(-1),'revoke');
});
test('failed server revocation leaves local UI locked',async()=>{
 const gate={unlock:async()=>{},verify:async()=>true,reset:()=>{},lock:async()=>{throw Error('server unreachable')}};
 let visible=false;
 const controller=createDebtModuleController({gate,load:async()=>{},show:()=>{visible=true},hide:()=>{visible=false},disconnect:async()=>{},hasPending:()=>false,confirmPending:async()=>true});
 await controller.open('synthetic');
 await assert.rejects(controller.logout(),/server unreachable/);
 assert.equal(controller.state(),'locked');
 assert.equal(visible,false);
});
