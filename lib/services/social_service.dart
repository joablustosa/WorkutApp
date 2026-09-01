import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/json_utils.dart';
import '../core/session.dart';
import '../models/app_user.dart';
import '../models/social.dart';

class SocialService {
  // --- Pessoas e seguir --------------------------------------------------

  /// Lista todo mundo com o status do meu vínculo (`all`) ou filtra
  /// por status ('accepted', 'pending', ...).
  static Future<List<Person>> people({String status = 'all'}) async {
    final me = Session.instance.userId;
    final rows = await ApiClient.getList(
      '${ApiConstants.myFriends}/FriendByType/$status?id=$me',
    );
    return rows
        .map((row) => Person.fromJson(row, currentUserId: me))
        .where((person) => person.userId != me && person.userId != 0)
        .toList();
  }

  static Future<List<Person>> search(String term) async {
    final query = term.trim().isEmpty ? 'all' : term.trim();
    final me = Session.instance.userId;
    final rows = await ApiClient.getList(
      '${ApiConstants.myFriends}/FriendSearch/${Uri.encodeComponent(query)}?id=$me',
    );
    return rows
        .map((row) => Person.fromJson(row, currentUserId: me))
        .where((person) => person.userId != me && person.userId != 0)
        .toList();
  }

  static Future<List<Person>> following() => people(status: 'accepted');

  static Future<List<Person>> pendingRequests() async {
    final all = await people();
    return all.where((person) => person.isPendingReceived).toList();
  }

  /// Envia o pedido de amizade e já registra o "fã" — assim o contador
  /// de fãs do perfil (`Homes/v1`) reflete quem te segue.
  static Future<void> follow(int otherUserId) async {
    final me = Session.instance.userId;

    await ApiClient.post(ApiConstants.myFriends, {
      'id': null,
      'idUser': me,
      'idUserFriend': otherUserId,
      'status': 'pending',
      'dateTimeCreate': toApiDate(DateTime.now()),
    });

    try {
      await ApiClient.post('${ApiConstants.users}/MyFan', {
        'id': null,
        'idUser': otherUserId,
        'idUserFan': me,
        'dateTimeCreate': toApiDate(DateTime.now()),
      });
    } catch (_) {
      // O vínculo principal já foi criado; o contador de fãs é secundário.
    }
  }

  static Future<void> acceptFollow(Person person) {
    return ApiClient.put(ApiConstants.myFriends, {
      'id': person.friendshipId,
      'idUser': person.linkUserId,
      'idUserFriend': Session.instance.userId,
      'status': 'accepted',
      'dateTimeCreate': toApiDate(DateTime.now()),
    });
  }

  static Future<void> unfollow(Person person) {
    if (person.friendshipId == null || person.friendshipId == 0) {
      throw ApiException('Vínculo não encontrado.');
    }
    return ApiClient.delete('${ApiConstants.myFriends}/${person.friendshipId}');
  }

  /// Situação do meu vínculo com um usuário específico.
  static Future<Person?> relationWith(int otherUserId) async {
    final all = await people();
    for (final person in all) {
      if (person.userId == otherUserId) return person;
    }
    return null;
  }

  // --- Depoimentos -------------------------------------------------------

  static Future<List<Testimony>> testimonies(int profileUserId) async {
    final rows = await ApiClient.getList(
      '${ApiConstants.myTestimonies}/MyTestimony/$profileUserId',
    );
    final list = rows.map(Testimony.fromJson).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));

    try {
      final likes = await ApiClient.getList(ApiConstants.testimonyLikes);
      final me = Session.instance.userId;
      final counts = <int, int>{};
      final mine = <int>{};
      for (final like in likes) {
        final id = asInt(like, 'idTestimony');
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
        if (asInt(like, 'idUser') == me) mine.add(id);
      }
      for (final testimony in list) {
        testimony.likeCount = counts[testimony.id] ?? 0;
        testimony.liked = mine.contains(testimony.id);
      }
    } catch (_) {
      // Sem curtidas não é motivo para esconder os depoimentos.
    }

    return list;
  }

  static Future<void> writeTestimony({
    required int profileUserId,
    required String message,
  }) {
    return ApiClient.post(ApiConstants.myTestimonies, {
      'id': null,
      'idUser': profileUserId,
      'idUserFriend': Session.instance.userId,
      'message': message,
      'isApproved': 1,
      'dateTimeCreate': toApiDate(DateTime.now()),
    });
  }

  static Future<void> likeTestimony(int testimonyId) {
    return ApiClient.post(ApiConstants.testimonyLikes, {
      'id': null,
      'idUser': Session.instance.userId,
      'idTestimony': testimonyId,
      'dateTimeCreate': toApiDate(DateTime.now()),
    });
  }

  static Future<void> deleteTestimony(int testimonyId) {
    return ApiClient.delete('${ApiConstants.myTestimonies}/$testimonyId');
  }

  // --- Recados (scraps) --------------------------------------------------

  static Future<List<Scrap>> scrapThread(int otherUserId) async {
    final me = Session.instance.userId;
    final rows = await ApiClient.getList(
      '${ApiConstants.myScraps}/GetScrapByIdToChat/$me/$otherUserId',
    );
    return rows.map(Scrap.fromJson).toList();
  }

  static Future<void> sendScrap({
    required int toUserId,
    required String message,
  }) {
    return ApiClient.post(ApiConstants.myScraps, {
      'id': null,
      'idUser': Session.instance.userId,
      'idUserFriend': toUserId,
      'message': message,
      'isRead': false,
      'dateTimeCreate': toApiDate(DateTime.now()),
    });
  }

  // --- Vibes do perfil ---------------------------------------------------

  static Future<void> giveVibe({
    required int toUserId,
    required ProfileVibe vibe,
  }) {
    return ApiClient.post(
      ApiConstants.userProfileCores,
      vibe.payload(fromUserId: Session.instance.userId, toUserId: toUserId),
    );
  }
}
