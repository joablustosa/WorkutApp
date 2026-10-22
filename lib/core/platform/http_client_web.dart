import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Cliente HTTP do navegador: usa `fetch`, respeita CORS e manda os
/// cookies da própria origem. O timeout é aplicado pelo `ApiClient`.
http.Client createHttpClient(Duration timeout) {
  return BrowserClient()..withCredentials = false;
}

/// No web uma falha de rede chega como `ClientException`, já tratada no
/// `ApiClient`; não existe `SocketException` para inspecionar aqui.
bool isTransientNetworkError(Object error) => false;
