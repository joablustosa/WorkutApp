import '../core/api_constants.dart';
import '../core/json_utils.dart';

/// Post do feed. Pode ser um texto solto ou o resumo de um treino.
class FeedPost {
  FeedPost({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.content,
    this.authorAvatar,
    this.image,
    this.postType,
    this.video,
    this.createdAt,
    this.liked = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.workout,
  });

  final int id;
  final int userId;
  final String authorName;
  final String content;
  final String? authorAvatar;
  final String? image;
  final String? postType;
  final String? video;
  final DateTime? createdAt;

  bool liked;
  int likeCount;
  int commentCount;

  /// Resumo do treino quando o post veio da sessao (PostType = "treino").
  final WorkoutPostSummary? workout;

  bool get isWorkout => postType == kWorkoutType;

  String get avatar => authorAvatar ?? ApiConstants.defaultAvatar;

  static const String kWorkoutType = 'treino';
  static const String kTextType = 'texto';

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: asInt(json, 'id') ?? 0,
      userId: asInt(json, 'idUser') ?? 0,
      authorName: asString(json, 'fullName') ?? 'Atleta Workut',
      authorAvatar: asString(json, 'userImage'),
      content: asString(json, 'content') ?? '',
      image: asString(json, 'image'),
      postType: asString(json, 'postType'),
      video: asString(json, 'video'),
      createdAt: asDate(json, 'dateTimeCreate'),
      liked: asBool(json, 'liked'),
      likeCount: asInt(json, 'likeCount') ?? 0,
      commentCount: asInt(json, 'commentCount') ?? 0,
      workout: WorkoutPostSummary.fromJson(json),
    );
  }
}

/// Números do treino que vieram junto do post.
class WorkoutPostSummary {
  const WorkoutPostSummary({
    this.planId,
    this.name,
    this.volume = 0,
    this.sets = 0,
    this.exercises = 0,
    this.durationMinutes = 0,
    this.prCount = 0,
    this.sportType,
  });

  final int? planId;
  final String? name;
  final double volume;
  final int sets;
  final int exercises;
  final int durationMinutes;
  final int prCount;
  final String? sportType;

  bool get hasNumbers => sets > 0 || volume > 0;

  /// Devolve null quando o post não carrega resumo de treino.
  static WorkoutPostSummary? fromJson(Map<String, dynamic> json) {
    final sets = asInt(json, 'totalSets') ?? 0;
    final volume = asDouble(json, 'totalVolume') ?? 0;
    final name = asString(json, 'workoutName');

    if (sets == 0 && volume == 0 && name == null) return null;

    return WorkoutPostSummary(
      planId: asInt(json, 'idSerie'),
      name: name,
      volume: volume,
      sets: sets,
      exercises: asInt(json, 'totalExercises') ?? 0,
      durationMinutes: asInt(json, 'durationMinutes') ?? 0,
      prCount: asInt(json, 'prCount') ?? 0,
      sportType: asString(json, 'sportType'),
    );
  }
}

/// Comentário de um post (`PostComments/v1/GetById/{idPost}`).
class PostComment {
  const PostComment({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.comment,
    this.authorAvatar,
    this.createdAt,
  });

  final int id;
  final int userId;
  final String authorName;
  final String comment;
  final String? authorAvatar;
  final DateTime? createdAt;

  String get avatar => authorAvatar ?? ApiConstants.defaultAvatar;

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: asInt(json, 'id') ?? 0,
      userId: asInt(json, 'idUser') ?? 0,
      authorName: asString(json, 'user') ?? 'Atleta Workut',
      authorAvatar: asString(json, 'image'),
      comment: asString(json, 'comment') ?? '',
      createdAt: asDate(json, 'dateTimeCreate'),
    );
  }
}
