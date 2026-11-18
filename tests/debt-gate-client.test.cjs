'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {createDebtGate}=require('../debt-gate-client.cjs');
const workspaceId='11111111-1111-4111-8111-111111111111';
const expiry=()=>new Date(Date.now()+60000).toISOString();
function setup(handler){const calls=[];const client={rpc:async(name,args)=>{calls.push({name,args});return handler(name,args)}};return {gate:createDebtGate({client,workspaceId}),calls}}
test('password is only sent to unlock RPC, never retained in gate API',async()=>{const x=setup(async name=>({data:name==='debt_unlock'?expiry():true,error:null}));await x.gate.unlock('synthetic-secret');assert.equal(x.gate.isUnlocked(),true);assert.equal(x.calls[0].name,'debt_unlock');assert.equal(x.calls[0].args.p_password,'synthetic-secret');assert.equal(Object.keys(x.gate).includes('password'),false)});
test('server verification is required after unlock',async()=>{const x=setup(async name=>({data:name==='debt_unlock'?expiry():false,error:null}));await x.gate.unlock('synthetic');assert.equal(await x.gate.verify(),false);assert.equal(x.gate.isUnlocked(),false)});
test('invalid expiry cannot unlock locally',async()=>{const x=setup(async()=>({data:'invalid-date',error:null}));await assert.rejects(x.gate.unlock('synthetic'),/expirado/);assert.equal(x.gate.isUnlocked(),false)});
test('server error denies access',async()=>{const x=setup(async()=>({data:null,error:{message:'denied'}}));await assert.rejects(x.gate.unlock('synthetic'),/denied/);assert.equal(x.gate.isUnlocked(),false)});
test('reset invalidates an in-flight unlock',async()=>{let resolve;const response=new Promise(r=>resolve=r);const x=setup(async()=>response);const pending=x.gate.unlock('synthetic');x.gate.reset();resolve({data:expiry(),error:null});await assert.rejects(pending,/modificada/);assert.equal(x.gate.isUnlocked(),false)});
test('lock clears local access and calls server revocation',async()=>{const x=setup(async name=>({data:name==='debt_unlock'?expiry():null,error:null}));await x.gate.unlock('synthetic');await x.gate.lock();assert.equal(x.gate.isUnlocked(),false);assert.equal(x.calls.at(-1).name,'debt_lock')});
test('server revocation failure still leaves local gate locked',async()=>{const x=setup(async name=>name==='debt_lock'?{data:null,error:{message:'unavailable'}}:{data:expiry(),error:null});await x.gate.unlock('synthetic');await assert.rejects(x.gate.lock(),/unavailable/);assert.equal(x.gate.isUnlocked(),false)});
