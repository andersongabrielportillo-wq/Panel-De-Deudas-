/* Panel de Deudas — Service Worker de actualizaciones controladas. */
const CACHE = 'panel-de-deudas-shell-v6-nav-safe-cache';
const CORE = ['./', './index.html', './manifest.webmanifest', './cl-nexus-adapter.cjs', './cl-nexus-shell.js', './debt-gate-client.cjs', './debt-module-controller.cjs', './debt-cache-preflight.cjs', './debt-legacy-backup.cjs', './debt-encrypted-backup.cjs', './icons/icon-192.png', './icons/icon-512.png'];
const SHELL = new Set(CORE.map(path => new URL(path, self.registration.scope).pathname));

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(CORE)));
  // No skipWaiting automático: se activa cuando el usuario confirma.
});
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting();
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k.startsWith('panel-de-deudas-') && k !== CACHE).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // Nunca interceptar Supabase, autenticación, CDNs ni otros orígenes.
  if (url.origin !== self.location.origin) return;
  const isNav = req.mode === 'navigate';
  // Solo la portada pertenece al shell offline. No guardar callbacks de Auth,
  // rutas desconocidas ni URLs con tokens/códigos en sus parámetros.
  const home = new URL('./', self.registration.scope).pathname;
  const index = new URL('./index.html', self.registration.scope).pathname;
  if (isNav && (url.search || (url.pathname !== home && url.pathname !== index))) return;
  if (!isNav && !SHELL.has(url.pathname)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      const response = await fetch(req, {cache:'no-store'});
      if (response.ok && response.type === 'basic') await cache.put(req, response.clone());
      return response;
    } catch (err) {
      const cached = await cache.match(req, {ignoreSearch:isNav});
      if (cached) return cached;
      if (isNav) {
        const fallback = await cache.match(new URL('./index.html', self.registration.scope).href);
        if (fallback) return fallback;
      }
      throw err;
    }
  })());
});
