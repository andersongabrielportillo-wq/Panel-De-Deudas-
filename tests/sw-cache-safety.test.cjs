/* Synthetic Service Worker cache tests. No browser sessions or real data. */
'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const source=fs.readFileSync(require('node:path').join(__dirname,'..','sw.js'),'utf8');
function setup({networkResponse,networkError=false}={}){
 const events={};const entries=new Map();const writes=[];
 const cache={addAll:async()=>{},put:async(req,res)=>{writes.push(req.url);entries.set(req.url,res)},match:async req=>entries.get(typeof req==='string'?req:req.url)};
 const context={
  URL,Set,Promise,
  self:{location:{origin:'https://example.test'},registration:{scope:'https://example.test/app/'},addEventListener:(name,fn)=>events[name]=fn,clients:{claim:async()=>{}}},
  caches:{open:async()=>cache,keys:async()=>[] ,delete:async()=>true},
  fetch:async req=>{if(networkError)throw Error('offline');return networkResponse||{status:200,type:'basic',redirected:false,url:req.url,clone(){return this}}},
 };
 vm.runInNewContext(source,context);
 function request(url,mode='navigate',method='GET'){
  let responsePromise;
  events.fetch({request:{url,mode,method},respondWith:p=>{responsePromise=p}});
  return responsePromise;
 }
 return {request,writes,entries,events};
}
test('auth callback query is never intercepted',()=>{const x=setup();assert.equal(x.request('https://example.test/app/?code=secret'),undefined);assert.equal(x.writes.length,0)});
test('unknown route is never intercepted',()=>{const x=setup();assert.equal(x.request('https://example.test/app/auth/callback'),undefined)});
test('cross-origin API is never intercepted',()=>{const x=setup();assert.equal(x.request('https://api.example.test/data','cors'),undefined)});
test('non-GET requests are never intercepted',()=>{const x=setup();assert.equal(x.request('https://example.test/app/','navigate','POST'),undefined)});
test('redirected response is not cached',async()=>{const url='https://example.test/app/';const x=setup({networkResponse:{status:200,type:'basic',redirected:true,url,clone(){return this}}});await x.request(url);assert.equal(x.writes.length,0)});
test('response from another path is not cached',async()=>{const x=setup({networkResponse:{status:200,type:'basic',redirected:false,url:'https://example.test/app/login',clone(){return this}}});await x.request('https://example.test/app/');assert.equal(x.writes.length,0)});
test('successful matching shell response is cached',async()=>{const url='https://example.test/app/';const x=setup();await x.request(url);assert.deepEqual(x.writes,[url])});
test('offline root can recover cached response',async()=>{const url='https://example.test/app/';const x=setup();await x.request(url);const y=setup({networkError:true});y.entries.set(url,{status:200});const response=await y.request(url);assert.equal(response.status,200)});
