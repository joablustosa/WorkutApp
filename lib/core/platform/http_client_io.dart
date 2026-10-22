import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Cliente HTTP nativo (Android, iOS, desktop).
http.Client createHttpClient(Duration timeout) {
  return IOClient(
    HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout,
  );
}

/// Erros de rede que valem uma segunda tentativa.
bool isTransientNetworkError(Object error) => error is SocketException;
