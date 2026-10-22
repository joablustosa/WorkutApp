// Bootstrap customizado do Flutter web.
//
// O padrao do Flutter registra o `flutter_service_worker.js`, que na versao
// 3.47 virou um stub que se desregistra sozinho (o service worker do Flutter
// foi descontinuado). Sem service worker com `fetch` nao ha cache, nao ha
// offline e o Chrome nao oferece instalar o app.
//
// Entao aqui o loader sobe sem service worker nenhum e quem registra o nosso
// (`sw.js`) e o `pwa.js`.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
