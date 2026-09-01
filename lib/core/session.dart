import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

/// Guarda o token JWT e o usuário logado.
///
/// A API embute o usuário serializado dentro da claim `aud` do token —
/// é de lá que o app tira o perfil logo após o login, igual ao workutFront.
class Session extends ChangeNotifier {
  Session._();

  static final Session instance = Session._();

  static const String _tokenKey = 'workut_token';
  static const String _userKey = 'workut_user';

  String? _token;
  AppUser? _user;

  String? get token => _token;
  AppUser? get user => _user;
  bool get isLoggedIn => _token != null && _user != null && !isExpired(_token!);

  int get userId => _user?.id ?? 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final rawUser = prefs.getString(_userKey);

    if (token == null || rawUser == null || isExpired(token)) {
      await clear();
      return;
    }

    try {
      _token = token;
      _user = AppUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
    } catch (_) {
      await clear();
    }
    notifyListeners();
  }

  Future<void> save({required String token, required AppUser user}) async {
    _token = token;
    _user = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(_userToStorage(user)));
    notifyListeners();
  }

  Future<void> updateUser(AppUser user) async {
    if (_token == null) return;
    await save(token: _token!, user: user);
  }

  Future<void> clear() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Map<String, dynamic> _userToStorage(AppUser user) {
    final map = user.toApi();
    map.remove('password');
    return map;
  }

  // --- JWT ---------------------------------------------------------------

  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final decoded = utf8.decode(base64.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool isExpired(String token) {
    final payload = decodePayload(token);
    final exp = payload?['exp'];
    if (exp is! num) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    return DateTime.now().isAfter(expiry);
  }

  /// Extrai o usuário da claim `aud`, que vem como JSON serializado.
  static AppUser? userFromToken(String token) {
    final payload = decodePayload(token);
    if (payload == null) return null;

    final aud = payload['aud'];
    final candidates = <String>[
      if (aud is String) aud,
      if (aud is List) ...aud.map((e) => e.toString()),
    ];

    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return AppUser.fromJson(decoded);
        }
      } catch (_) {
        // Claims de audiência que não são JSON (issuer, etc.) são ignoradas.
      }
    }
    return null;
  }
}
