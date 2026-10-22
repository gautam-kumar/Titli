// Offline shell: serve from cache, refresh in the background.
const C = 'titli-v1';
const FILES = ['./', 'index.html', 'styles.css', 'app.js', 'brain.js', 'hero.js', 'vendor/three.module.min.js', 'vendor/RoomEnvironment.js', 'manifest.webmanifest',
  ...['ring', 'gas', 'card', 'pPink', 'pViolet', 'pCyan', 'diya', 'play', 'icon'].map(n => `assets/${n}.png`)];
self.addEventListener('install', e => e.waitUntil(caches.open(C).then(c => c.addAll(FILES)).then(() => self.skipWaiting())));
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(caches.match(e.request).then(hit => {
    const net = fetch(e.request).then(r => { if (r.ok && new URL(e.request.url).origin === location.origin) caches.open(C).then(c => c.put(e.request, r.clone())); return r }).catch(() => hit);
    return hit || net;
  }));
});
