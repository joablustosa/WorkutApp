// Service worker do Workut: e ele que faz o app abrir instantaneo na segunda
// visita, continuar abrindo sem internet e ser instalavel pelo navegador.
//
// Duas estrategias, de proposito:
//
// - A pagina e o `flutter_bootstrap.js` vao primeiro na rede. Sao pequenos e
//   carregam a identidade do build, entao um deploy novo e visto na hora.
// - O resto (main.dart.js, canvaskit, fontes, icones) sai do cache na hora e
//   e atualizado em segundo plano. A primeira tela aparece sem esperar rede;
//   a versao nova entra no proximo carregamento.
//
// Chamadas a API nao passam por aqui: sao de outra origem e seguem diretas.

'use strict';

const CACHE = 'workut-shell-v1';

// O minimo para a tela de abertura existir offline.
const CORE = [
  '/',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'manifest.json',
  'pwa.js',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
];

// Arquivos que valem buscar na rede antes do cache.
const NETWORK_FIRST = ['flutter_bootstrap.js', 'version.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      // `reload` evita guardar no cache do SW algo que o navegador ja tinha
      // guardado velho no cache HTTP.
      .then((cache) =>
        cache.addAll(CORE.map((url) => new Request(url, { cache: 'reload' })))
      )
      .then(() => self.skipWaiting())
      .catch(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))
      )
      .then(() => self.clients.claim())
  );
});

function isNetworkFirst(url) {
  return NETWORK_FIRST.some((name) => url.pathname.endsWith(name));
}

async function networkFirst(request, fallbackUrl) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(request);
    if (response && response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    const cached =
      (await cache.match(request)) ||
      (fallbackUrl ? await cache.match(fallbackUrl) : undefined);
    if (cached) return cached;
    throw error;
  }
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(request);

  const network = fetch(request)
    .then((response) => {
      if (response && response.ok) {
        cache.put(request, response.clone());
      }
      return response;
    })
    .catch(() => undefined);

  return cached || network.then((response) => {
    if (response) return response;
    throw new Error('Sem rede e sem cache para ' + request.url);
  });
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  // Outra origem (a API, por exemplo): deixa passar direto.
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(networkFirst(request, 'index.html'));
    return;
  }

  if (isNetworkFirst(url)) {
    event.respondWith(networkFirst(request));
    return;
  }

  event.respondWith(staleWhileRevalidate(request));
});
