import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/json_utils.dart';
import '../core/session.dart';
import '../models/app_user.dart';

class AuthService {
  /// Autentica e guarda o token + usuário na sessão.
  static Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final response = await ApiClient.post(ApiConstants.login, {
      'username': username.trim(),
      'password': password,
    });

    if (response is! Map) {
      throw ApiException('Resposta inesperada do servidor.');
    }

    final data = response.cast<String, dynamic>();
    final authenticated = asBool(data, 'autenticated');
    if (!authenticated) {
      throw ApiException(
        asString(data, 'message') == 'Failed to autheticate'
            ? 'Usuário ou senha incorretos.'
            : asString(data, 'message') ?? 'Não foi possível entrar.',
      );
    }

    final token = asString(data, 'accessToken');
    if (token == null) {
      throw ApiException('O servidor não devolveu o token de acesso.');
    }

    final user = Session.userFromToken(token);
    if (user == null || user.id == 0) {
      throw ApiException('Não foi possível ler seu perfil no token.');
    }

    await Session.instance.save(token: token, user: user);
    return user;
  }

  /// Cria a conta. Os campos extras existem no `UserVO` da API e são
  /// preenchidos com um padrão para o cadastro ficar curto.
  static Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required DateTime birthDate,
    required double weight,
    required double height,
    required String sport,
  }) async {
    await ApiClient.post(ApiConstants.users, {
      'id': 0,
      'fullName': fullName.trim(),
      'aboutMe': 'Bora treinar! Cheguei no Workut.',
      'age': _ageFrom(birthDate),
      'birthDate': birthDate.toIso8601String(),
      'interests': 'Treino',
      'hasChildren': 'No',
      'ethnicity': 'Nenhuma',
      'style': 'Nenhum',
      'smokes': 'No',
      'drinks': 'No',
      'hasPets': 'No',
      'livingWith': 'Sozinho',
      'hometown': ApiConstants.defaultAvatar,
      'sports': sport,
      'maritalStatus': 'Focado no treino',
      'username': email.trim(),
      'password': password,
      'userStatus': 'Active',
      'createdAt': DateTime.now().toIso8601String(),
      'weight': weight,
      'height': height,
    });
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ApiClient.post('${ApiConstants.login}/ResetaSenha', {
      'idUsuario': Session.instance.userId,
      'senhaAtual': currentPassword,
      'novaSenha': newPassword,
      'repitaNovaSenha': newPassword,
    });
  }

  static Future<void> logout() => Session.instance.clear();

  static int _ageFrom(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hadBirthday = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age < 0 ? 0 : age;
  }
}
