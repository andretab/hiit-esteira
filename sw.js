// sw.js — service worker: cache do "app shell" para funcionar 100% offline.
// Ao alterar qualquer arquivo do app, incremente VERSAO para forçar a atualização do cache.

const VERSAO = 'hiit-v2';
const CACHE_APP = `${VERSAO}-app`;
const CACHE_FONTES = 'hiit-fontes';

const APP_SHELL = [
  './',
  './index.html',
  './styles.css',
  './app.js',
  './generator.js',
  './storage.js',
  './efeitos.js',
  './manifest.json',
  './icons/icon.svg',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-512.png',
  './icons/apple-touch-icon.png',
];

// CSS das fontes (os arquivos .woff2 entram no cache na primeira vez que são usados).
const FONTES_CSS = 'https://fonts.googleapis.com/css2?family=Barlow:wght@400;500;600;700&family=Barlow+Condensed:wght@500;600;700;800&display=swap';

// Instalação: baixa e guarda todo o app shell.
self.addEventListener('install', (evento) => {
  evento.waitUntil(
    caches.open(CACHE_APP)
      .then((cache) => cache.addAll(APP_SHELL))
      // fontes são opcionais: sem elas o app usa as fontes do sistema
      .then(() => caches.open(CACHE_FONTES).then((c) => c.add(FONTES_CSS)).catch(() => {}))
      .then(() => self.skipWaiting()),
  );
});

// Ativação: remove caches de versões antigas.
self.addEventListener('activate', (evento) => {
  evento.waitUntil(
    caches.keys()
      .then((chaves) => Promise.all(
        chaves.filter((c) => c !== CACHE_APP && c !== CACHE_FONTES).map((c) => caches.delete(c)),
      ))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (evento) => {
  const req = evento.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Google Fonts: usa o cache e atualiza em segundo plano (stale-while-revalidate).
  if (url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com') {
    evento.respondWith(staleWhileRevalidate(req, CACHE_FONTES));
    return;
  }

  if (url.origin !== self.location.origin) return;

  // Navegação para o app: responde com o index.html do cache (página única).
  // Outras páginas (ex.: /tests/) seguem para a rede normalmente.
  const raiz = new URL('./', self.location).pathname;
  if (req.mode === 'navigate' && (url.pathname === raiz || url.pathname === `${raiz}index.html`)) {
    evento.respondWith(staleWhileRevalidate(new Request('./index.html'), CACHE_APP));
    return;
  }

  // Demais arquivos do app: responde do cache na hora e atualiza em segundo plano,
  // assim um deploy novo chega na visita seguinte mesmo sem trocar VERSAO.
  evento.respondWith(staleWhileRevalidate(req, CACHE_APP));
});

async function staleWhileRevalidate(req, nomeCache) {
  const cache = await caches.open(nomeCache);
  const emCache = await cache.match(req);
  const daRede = fetch(req)
    .then((resp) => {
      if (resp.ok || resp.type === 'opaque') cache.put(req, resp.clone());
      return resp;
    })
    .catch(() => emCache);
  return emCache || daRede;
}
