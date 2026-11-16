import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const html=readFileSync(new URL('../laboratorio/index.html',import.meta.url),'utf8');
test('laboratorio declara claramente que no es produccion',()=>{
 assert.match(html,/NO ES LA APLICACIÓN REAL/);
 assert.match(html,/no sincroniza dispositivos/);
 assert.match(html,/Publicación web: pendiente de autorización/);
});
test('laboratorio no incluye credenciales ni acceso a servicios remotos',()=>{
 assert.doesNotMatch(html,/supabase\.co|createClient\s*\(|fetch\s*\(|XMLHttpRequest|WebSocket|service_role|anon[_-]key|localStorage|indexedDB|navigator\.serviceWorker\.register/i);
 assert.doesNotMatch(html,/<script[^>]+src=/i);
});
test('laboratorio muestra los tres modulos y mantiene deudas bloqueado',()=>{
 for(const nombre of ['inventario','contratos','deudas'])
  assert.match(html,new RegExp('data-modulo="'+nombre+'"'));
 assert.match(html,/Deudas · acceso no disponible/);
 assert.match(html,/no permite desbloquear Deudas/);
});
