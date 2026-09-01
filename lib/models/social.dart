import '../core/api_constants.dart';
import '../core/json_utils.dart';

/// Depoimento recebido em um perfil (`MyTestimonies/v1/MyTestimony/{id}`).
///
/// `idUser` é o dono do perfil e `idUserFriend` é quem escreveu.
class Testimony {
  Testimony({
    required this.id,
    required this.profileUserId,
    required this.authorId,
    required this.message,
    this.authorName,
    this.authorAvatar,
    this.createdAt,
    this.isApproved = 0,
    this.likeCount = 0,
    this.liked = false,
  });

  final int id;
  final int profileUserId;
  final int authorId;
  final String message;
  final String? authorName;
  final String? authorAvatar;
  final DateTime? createdAt;
  final int isApproved;

  int likeCount;
  bool liked;

  String get avatar => authorAvatar ?? ApiConstants.defaultAvatar;

  factory Testimony.fromJson(Map<String, dynamic> json) {
    return Testimony(
      id: asInt(json, 'id') ?? 0,
      profileUserId: asInt(json, 'idUser') ?? 0,
      authorId: asInt(json, 'idUserFriend') ?? 0,
      message: asString(json, 'message') ?? '',
      authorName: asString(json, 'userFriendName'),
      authorAvatar: asString(json, 'image'),
      createdAt: asDate(json, 'dateTimeCreate'),
      isApproved: asInt(json, 'isApproved') ?? 0,
    );
  }
}

/// Recado (scrap) trocado entre dois usuários.
class Scrap {
  const Scrap({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.friendName,
    this.friendAvatar,
    this.createdAt,
    this.isRead = false,
  });

  final int id;
  final int senderId;
  final int receiverId;
  final String message;
  final String? friendName;
  final String? friendAvatar;
  final DateTime? createdAt;
  final bool isRead;

  factory Scrap.fromJson(Map<String, dynamic> json) {
    return Scrap(
      id: asInt(json, 'id') ?? 0,
      senderId: asInt(json, 'idUser') ?? 0,
      receiverId: asInt(json, 'idUserFriend') ?? 0,
      message: asString(json, 'message') ?? '',
      friendName: asString(json, 'nameUserFriend'),
      friendAvatar: asString(json, 'imageUserFriend'),
      createdAt: asDate(json, 'dateTimeCreate'),
      isRead: asBool(json, 'isRead'),
    );
  }
}

/// As "carinhas" do perfil — a versão Workut dos cores do Orkut.
enum ProfileVibe {
  cool('Fera', '💪', 'coolScore'),
  trustworthy('Parceiro', '🤝', 'trustworthyScore'),
  sexy('Shape', '🔥', 'sexyScore'),
  happy('Motivador', '😄', 'happyScore'),
  anxious('Focado', '⚡', 'anxiousScore');

  const ProfileVibe(this.label, this.emoji, this.field);

  final String label;
  final String emoji;
  final String field;

  /// Corpo do `UserProfileCoresVO` marcando 1 ponto nesta vibe.
  Map<String, dynamic> payload({required int fromUserId, required int toUserId}) {
    final body = <String, dynamic>{
      'idUser': toUserId,
      'idUserFriend': fromUserId,
      'trustworthyScore': 0,
      'coolScore': 0,
      'sexyScore': 0,
      'anxiousScore': 0,
      'happyScore': 0,
      'dateTimeCreate': toApiDate(DateTime.now()),
    };
    body[field] = 1;
    return body;
  }
}
