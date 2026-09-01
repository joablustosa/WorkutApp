import '../core/api_constants.dart';
import '../core/json_utils.dart';

/// Usuário do Workut.
///
/// A API guarda a foto de perfil no campo `hometown` (herança do
/// projeto original) — aqui ele é exposto como [avatarUrl].
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    this.username,
    this.aboutMe,
    this.avatarUrl,
    this.sports,
    this.weight,
    this.height,
    this.birthDate,
    this.age,
    this.maritalStatus,
    this.interests,
    this.userStatus,
    this.createdAt,
  });

  final int id;
  final String fullName;
  final String? username;
  final String? aboutMe;
  final String? avatarUrl;
  final String? sports;
  final double? weight;
  final double? height;
  final DateTime? birthDate;
  final int? age;
  final String? maritalStatus;
  final String? interests;
  final String? userStatus;
  final DateTime? createdAt;

  String get photo => avatarUrl ?? ApiConstants.defaultAvatar;

  String get firstName => fullName.trim().split(' ').first;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: asInt(json, 'id') ?? 0,
      fullName: asString(json, 'fullName') ?? 'Atleta Workut',
      username: asString(json, 'username'),
      aboutMe: asString(json, 'aboutMe'),
      avatarUrl: asString(json, 'hometown'),
      sports: asString(json, 'sports'),
      weight: asDouble(json, 'weight'),
      height: asDouble(json, 'height'),
      birthDate: asDate(json, 'birthDate'),
      age: asInt(json, 'age'),
      maritalStatus: asString(json, 'maritalStatus'),
      interests: asString(json, 'interests'),
      userStatus: asString(json, 'userStatus'),
      createdAt: asDate(json, 'createdAt'),
    );
  }

  /// Corpo aceito pelo `UserVO` da API (PUT /Users/v1).
  Map<String, dynamic> toApi() {
    return {
      'id': id,
      'fullName': fullName,
      'aboutMe': aboutMe ?? '',
      'age': age ?? 0,
      'birthDate': birthDate?.toIso8601String(),
      'interests': interests ?? 'Nenhum',
      'hasChildren': 'No',
      'ethnicity': 'Nenhuma',
      'style': 'Nenhum',
      'smokes': 'No',
      'drinks': 'No',
      'hasPets': 'No',
      'livingWith': 'Sozinho',
      'hometown': avatarUrl ?? ApiConstants.defaultAvatar,
      'sports': sports ?? 'Musculação',
      'maritalStatus': maritalStatus ?? 'Estamos ai',
      'username': username,
      'userStatus': userStatus ?? 'Active',
      'createdAt': createdAt?.toIso8601String(),
      'weight': weight,
      'height': height,
    };
  }

  AppUser copyWith({
    String? fullName,
    String? aboutMe,
    String? avatarUrl,
    String? sports,
    double? weight,
    double? height,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      username: username,
      aboutMe: aboutMe ?? this.aboutMe,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      sports: sports ?? this.sports,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      birthDate: birthDate,
      age: age,
      maritalStatus: maritalStatus,
      interests: interests,
      userStatus: userStatus,
      createdAt: createdAt,
    );
  }
}

/// Resumo do perfil devolvido por `GET /Homes/v1/{id}`.
class HomeSummary {
  const HomeSummary({
    required this.id,
    required this.fullName,
    required this.friends,
    required this.communities,
    required this.testimonies,
    required this.fans,
    required this.cool,
    required this.sexy,
    required this.anxious,
    required this.happy,
    required this.trustworthy,
  });

  final int id;
  final String fullName;
  final int friends;
  final int communities;
  final int testimonies;
  final int fans;
  final double cool;
  final double sexy;
  final double anxious;
  final double happy;
  final double trustworthy;

  static const HomeSummary empty = HomeSummary(
    id: 0,
    fullName: '',
    friends: 0,
    communities: 0,
    testimonies: 0,
    fans: 0,
    cool: 0,
    sexy: 0,
    anxious: 0,
    happy: 0,
    trustworthy: 0,
  );

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    return HomeSummary(
      id: asInt(json, 'id') ?? 0,
      fullName: asString(json, 'fullName') ?? '',
      friends: asInt(json, 'friends') ?? 0,
      communities: asInt(json, 'communities') ?? 0,
      testimonies: asInt(json, 'testimonies') ?? 0,
      fans: asInt(json, 'fans') ?? 0,
      cool: asDouble(json, 'cool') ?? 0,
      sexy: asDouble(json, 'sexy') ?? 0,
      anxious: asDouble(json, 'anxious') ?? 0,
      happy: asDouble(json, 'happy') ?? 0,
      trustworthy: asDouble(json, 'trustworthy') ?? 0,
    );
  }
}

/// Pessoa listada em `MyFriends/v1/FriendByType` ou `FriendSearch`.
class Person {
  const Person({
    required this.userId,
    required this.fullName,
    this.friendshipId,
    this.linkUserId = 0,
    this.avatarUrl,
    this.status = 'nenhum',
    this.requestedByMe = false,
  });

  final int userId;
  final int? friendshipId;

  /// `IdUser` do vínculo em MyFriend — quem enviou o pedido.
  final int linkUserId;
  final String fullName;
  final String? avatarUrl;

  /// 'nenhum', 'solicitado', 'aguardando', 'aceito' ou 'bloqueado'.
  final String status;
  final bool requestedByMe;

  String get photo => avatarUrl ?? ApiConstants.defaultAvatar;

  bool get isFollowing => status == 'aceito';
  bool get isPendingSent => status == 'solicitado';
  bool get isPendingReceived => status == 'aguardando';

  factory Person.fromJson(Map<String, dynamic> json, {int? currentUserId}) {
    final idUser = asInt(json, 'idUser') ?? 0;
    final idUserFriend = asInt(json, 'idUserFriend') ?? 0;

    // A consulta da API devolve o par (IdUser, IdUserFriend) do vínculo.
    // Quando a amizade partiu do outro lado, o "amigo" do vínculo sou eu —
    // nesse caso a outra pessoa é o IdUser.
    final otherId =
        (currentUserId != null && idUserFriend == currentUserId && idUser > 0)
            ? idUser
            : idUserFriend;

    return Person(
      userId: otherId,
      friendshipId: asInt(json, 'id'),
      linkUserId: idUser,
      fullName: asString(json, 'fullName') ?? 'Atleta Workut',
      avatarUrl: asString(json, 'hometown'),
      status: (asString(json, 'status') ?? 'nenhum').toLowerCase(),
      requestedByMe: currentUserId != null && idUser == currentUserId,
    );
  }
}
