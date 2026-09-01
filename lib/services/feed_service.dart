import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/json_utils.dart';
import '../core/session.dart';
import '../models/feed.dart';

class FeedService {
  /// Feed principal: meus posts + os posts de quem eu sigo.
  static Future<List<FeedPost>> feed(int userId) {
    return _loadPosts('${ApiConstants.feedPosts}/GetById/$userId');
  }

  /// Só os posts de um usuário (usado no perfil).
  static Future<List<FeedPost>> byUser(int userId) {
    return _loadPosts('${ApiConstants.feedPosts}/GetByIdToFriends/$userId');
  }

  static Future<List<FeedPost>> _loadPosts(String url) async {
    // A API já devolve autor, curtidas, comentários e o resumo do treino
    // em uma chamada só — não precisamos mais cruzar listas no cliente.
    final rows = await ApiClient.getList(url);
    return rows.map(FeedPost.fromJson).toList();
  }

  static Future<FeedPost> create({
    required String content,
    String? image,
    String postType = FeedPost.kTextType,
    int? communityId,
    WorkoutPostSummary? workout,
  }) async {
    final me = Session.instance.user;
    if (me == null) throw ApiException('Você precisa estar logado.');

    final response = await ApiClient.post(ApiConstants.feedPosts, {
      'id': null,
      'idUser': me.id,
      'idCommunity': communityId,
      'content': content,
      'image': image ?? '',
      'postType': postType,
      'video': '',
      'dateTimeCreate': toApiDate(DateTime.now()),
      if (workout != null) ...{
        'idSerie': workout.planId,
        'workoutName': workout.name,
        'totalVolume': workout.volume,
        'totalSets': workout.sets,
        'totalExercises': workout.exercises,
        'durationMinutes': workout.durationMinutes,
        'prCount': workout.prCount,
      },
    });

    final created = response is Map
        ? FeedPost.fromJson(response.cast<String, dynamic>())
        : null;

    return FeedPost(
      id: created?.id ?? 0,
      userId: me.id,
      authorName: me.fullName,
      authorAvatar: me.avatarUrl,
      content: content,
      image: image,
      postType: postType,
      createdAt: DateTime.now(),
      workout: workout,
    );
  }

  static Future<void> delete(int postId) {
    return ApiClient.delete('${ApiConstants.feedPosts}/$postId');
  }

  // --- Curtidas ----------------------------------------------------------

  static Future<void> like(int postId) {
    return ApiClient.post(ApiConstants.postLikes, {
      'id': null,
      'idUser': Session.instance.userId,
      'idPost': postId,
      'dateTimeCreate': toApiDate(DateTime.now()),
    });
  }

  static Future<void> unlike(int postId) {
    final userId = Session.instance.userId;
    return ApiClient.delete('${ApiConstants.postLikes}/$userId/$postId');
  }

  // --- Comentários -------------------------------------------------------

  static Future<List<PostComment>> comments(int postId) async {
    final rows =
        await ApiClient.getList('${ApiConstants.postComments}/GetById/$postId');
    final comments = rows.map(PostComment.fromJson).toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(2000))
          .compareTo(b.createdAt ?? DateTime(2000)));
    return comments;
  }

  static Future<void> comment(int postId, String text) {
    return ApiClient.post(ApiConstants.postComments, {
      'id': null,
      'idPost': postId,
      'idUser': Session.instance.userId,
      'comment': text,
      'dateTimeCreate': toApiDate(DateTime.now()),
    });
  }

  static Future<void> deleteComment(int commentId) {
    return ApiClient.delete('${ApiConstants.postComments}/$commentId');
  }
}
