/// Cria o `http.Client` certo para cada plataforma.
///
/// No celular/desktop usamos o `IOClient` (com timeout de conexão). No web
/// `dart:io` não existe, então entra o `BrowserClient`, que fala via `fetch`.
/// O `export` condicional é resolvido em tempo de compilação, de forma que o
/// build web nunca chega a enxergar `dart:io`.
export 'http_client_io.dart'
    if (dart.library.js_interop) 'http_client_web.dart';
