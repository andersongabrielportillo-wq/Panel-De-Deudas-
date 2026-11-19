import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sw=readFileSync(new URL('../sw.js',import.meta.url),'utf8');
test('precaché incluye los tres scripts de control de Deudas',()=>{
 for(const p of ['debt-gate-client.cjs','debt-module-controller.cjs','debt-cache-preflight.cjs'])
  assert.ok(sw.includes("'./"+p+"'"),'No precacheado: '+p);
});
test('el SW no intercepta Supabase ni peticiones no GET',()=>{
 assert.match(sw,/if \(req.method !== 'GET'\) return;/);
 assert.match(sw,/if \(url.origin !== self.location.origin\) return;/);
});
test('no activa automáticamente una actualización de la PWA',()=>{
 assert.match(sw,/event.data.type === 'SKIP_WAITING'/);
 assert.doesNotMatch(sw,/self\.skipWaiting\(\);\s*\/\/ auto/);
});
