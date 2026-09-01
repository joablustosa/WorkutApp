import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'session.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Cliente HTTP do Workut: injeta o Bearer token, trata erro e
/// normaliza a resposta (a API às vezes devolve corpo vazio).
class ApiClient {
  ApiClient._();

  static const Duration _timeout = Duration(seconds: 30);

  static Map<String, String> _headers({bool json = true}) {
    final token = Session.instance.token;
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json, text/plain',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String url) async {
    return _send(() => http.get(Uri.parse(url), headers: _headers()));
  }

  static Future<List<Map<String, dynamic>>> getList(String url) async {
    final data = await get(url);
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  static Future<Map<String, dynamic>> getObject(String url) async {
    final data = await get(url);
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  static Future<dynamic> post(String url, Object? body) async {
    return _send(
      () => http.post(
        Uri.parse(url),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<dynamic> put(String url, Object? body) async {
    return _send(
      () => http.put(
        Uri.parse(url),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<dynamic> delete(String url) async {
    return _send(() => http.delete(Uri.parse(url), headers: _headers()));
  }

  /// Envia uma imagem para `File/v1/uploadFile` e devolve a URL pública.
  ///
  /// A API só aceita `.jpg`, `.jpeg` e `.png` — o nome do arquivo precisa
  /// chegar com a extensão certa.
  static Future<String> uploadImage(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${_filesBase()}/uploadFile'),
    )
      ..headers.addAll(_headers(json: false))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    try {
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Não foi possível enviar a imagem.',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      final url = decoded is Map ? decoded['docUrl'] ?? decoded['DocUrl'] : null;
      if (url == null || url.toString().isEmpty) {
        throw ApiException('A API não devolveu a URL da imagem.');
      }
      return url.toString();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(_friendlyNetworkError(error));
    }
  }

  static String _filesBase() {
    // Evita import circular com ApiConstants em tempo de compilação web.
    return 'https://workutapi-ewfaggdga2aaeghx.eastus2-01.azurewebsites.net/api/File/v1';
  }

  static Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(_timeout);
    } catch (error) {
      throw ApiException(_friendlyNetworkError(error));
    }

    if (response.statusCode == 401) {
      await Session.instance.clear();
      throw ApiException(
        'Sua sessão expirou. Entre novamente.',
        statusCode: 401,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _friendlyStatusError(response.statusCode, response.body),
        statusCode: response.statusCode,
      );
    }

    final body = response.body.trim();
    if (body.isEmpty) return null;

    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return body;
    }
  }

  static String _friendlyNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('failed host lookup') ||
        text.contains('network')) {
      return 'Sem conexão com a internet. Tente de novo.';
    }
    if (text.contains('timeout')) {
      return 'O servidor demorou demais para responder.';
    }
    return 'Não foi possível falar com o servidor. Tente de novo.';
  }

  static String _friendlyStatusError(int status, String body) {
    switch (status) {
      case 400:
        return 'Dados inválidos. Confira o que foi preenchido.';
      case 403:
        return 'Você não tem permissão para isso.';
      case 404:
        return 'Não encontramos o que você pediu.';
      case 500:
      case 502:
      case 503:
        return 'O servidor do Workut está instável. Tente em instantes.';
      default:
        return body.isNotEmpty && body.length < 160
            ? body
            : 'Algo deu errado (código $status).';
    }
  }
}
