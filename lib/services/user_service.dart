import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/session.dart';
import '../models/app_user.dart';
import '../models/workout.dart';

class UserService {
  static Future<AppUser> byId(int id) async {
    final data = await ApiClient.getObject('${ApiConstants.users}/$id');
    return AppUser.fromJson(data);
  }

  static Future<HomeSummary> summary(int id) async {
    final data = await ApiClient.getObject('${ApiConstants.home}/$id');
    return HomeSummary.fromJson(data);
  }

  static Future<AppUser> update(AppUser user) async {
    await ApiClient.put(ApiConstants.users, user.toApi());
    if (user.id == Session.instance.userId) {
      await Session.instance.updateUser(user);
    }
    return user;
  }

  /// Troca a foto de perfil (a API apaga o blob antigo neste endpoint).
  static Future<AppUser> updatePhoto(AppUser user, String photoUrl) async {
    final updated = user.copyWith(avatarUrl: photoUrl);
    await ApiClient.put('${ApiConstants.users}/EditPhoto', updated.toApi());
    if (user.id == Session.instance.userId) {
      await Session.instance.updateUser(updated);
    }
    return updated;
  }

  /// Números de treino do perfil: volume, frequência, PRs e sequência.
  static Future<TrainingStats> trainingStats(int id) async {
    final data =
        await ApiClient.getObject('${ApiConstants.home}/TrainingStats/$id');
    return TrainingStats.fromJson(data);
  }

  static Future<List<RankingEntry>> ranking() async {
    final data = await ApiClient.getList('${ApiConstants.home}/GetRanking');
    final entries = data.map(RankingEntry.fromJson).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return entries;
  }
}
