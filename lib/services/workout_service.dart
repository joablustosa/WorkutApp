import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/json_utils.dart';
import '../core/session.dart';
import '../models/workout.dart';

class WorkoutService {
  // --- Catálogo de exercícios -------------------------------------------

  static Future<List<Exercise>> catalog({String? type}) async {
    final url = type == null || type.isEmpty
        ? ApiConstants.exercises
        : '${ApiConstants.exercises}?type=${Uri.encodeComponent(type)}';
    final rows = await ApiClient.getList(url);
    final exercises = rows.map(Exercise.fromJson).toList()
      ..sort((a, b) {
        final sub = (a.subType ?? '').compareTo(b.subType ?? '');
        if (sub != 0) return sub;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return exercises;
  }

  static Future<Exercise> byId(int id) async {
    final row = await ApiClient.getObject('${ApiConstants.exercises}/$id');
    return Exercise.fromJson(row);
  }

  static Future<Exercise> createExercise({
    required String name,
    required String type,
    String? subType,
    String? image,
    String? link,
  }) async {
    final response = await ApiClient.post(ApiConstants.exercises, {
      'id': null,
      'name': name,
      'type': type,
      'subType': subType ?? '',
      'image': image ?? '',
      'link': link ?? '',
    });
    if (response is Map) {
      return Exercise.fromJson(response.cast<String, dynamic>());
    }
    return Exercise(id: 0, name: name, type: type, image: image, link: link);
  }

  // --- Treinos (séries) --------------------------------------------------

  static Future<List<WorkoutPlan>> plans(int userId) async {
    final rows =
        await ApiClient.getList('${ApiConstants.exerciseSeries}/MySerie/$userId');
    return rows.map(WorkoutPlan.fromJson).toList();
  }

  static Future<WorkoutPlan> createPlan(String name, {String sportType = 'gym'}) async {
    final userId = Session.instance.userId;
    final response = await ApiClient.post(ApiConstants.exerciseSeries, {
      'id': null,
      'name': name,
      'idUser': userId,
      'dateTimeCreated': toApiDate(DateTime.now()),
      'sportType': sportType,
    });
    if (response is Map) {
      return WorkoutPlan.fromJson(response.cast<String, dynamic>());
    }
    return WorkoutPlan(id: 0, name: name, userId: userId, sportType: sportType);
  }

  static Future<void> renamePlan(WorkoutPlan plan, String name) {
    return ApiClient.put(ApiConstants.exerciseSeries, {
      'id': plan.id,
      'name': name,
      'idUser': plan.userId,
      'dateTimeCreated': toApiDate(plan.createdAt ?? DateTime.now()),
      'myOrder': plan.order,
      'sportType': plan.sportType ?? 'gym',
    });
  }

  static Future<void> deletePlan(int planId) {
    return ApiClient.delete('${ApiConstants.exerciseSeries}/$planId');
  }

  // --- Exercícios de um treino ------------------------------------------

  static Future<List<PlanExercise>> planExercises({
    required int userId,
    required int planId,
  }) async {
    final rows = await ApiClient.getList(
      '${ApiConstants.exerciseBySeries}/MyExerciseSerie/$userId/$planId',
    );
    final list = rows.map(PlanExercise.fromJson).toList()
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    return list;
  }

  static Future<void> addExerciseToPlan({
    required int planId,
    required int exerciseId,
  }) async {
    if (exerciseId <= 0) {
      throw ApiException('Exercício inválido. Escolha um exercício do catálogo.');
    }
    await ApiClient.post(ApiConstants.exerciseBySeries, {
      'id': null,
      'idSerie': planId,
      'idUser': Session.instance.userId,
      'idExercise': exerciseId,
      'dateTimeCreated': toApiDate(DateTime.now()),
    });
  }

  static Future<void> removeExerciseFromPlan(int planExerciseId) {
    return ApiClient.delete('${ApiConstants.exerciseBySeries}/$planExerciseId');
  }

  // --- Execução (séries do dia) -----------------------------------------

  static Future<List<WorkoutSet>> setsOfDay({
    required int exerciseId,
    required int userId,
    DateTime? day,
  }) async {
    final date = toApiDay(day ?? DateTime.now());
    final rows = await ApiClient.getList(
      '${ApiConstants.exerciseDaillys}/GetToList'
      '?id=$exerciseId&idUser=$userId&date=$date',
    );
    final sets = rows.map(WorkoutSet.fromJson).toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    return sets;
  }

  /// Histórico completo do exercício, já ordenado da carga maior para a menor.
  static Future<List<WorkoutSet>> history({
    required int exerciseId,
    required int userId,
  }) async {
    final rows = await ApiClient.getList(
      '${ApiConstants.exerciseDaillys}/GetToHistory/$exerciseId/$userId',
    );
    return rows.map(WorkoutSet.fromJson).toList();
  }

  static Future<ExerciseStats> stats({
    required int exerciseId,
    required int userId,
  }) async {
    final sets = await history(exerciseId: exerciseId, userId: userId);
    return ExerciseStats.fromSets(sets);
  }

  static Future<WorkoutSet> addSet({
    required int exerciseId,
    required int seq,
    required double weight,
    required int reps,
    bool done = false,
    String? obs,
  }) async {
    final userId = Session.instance.userId;
    final body = WorkoutSet(
      id: 0,
      seq: seq,
      weight: weight,
      reps: reps,
      done: done,
      obs: obs,
      exerciseId: exerciseId,
      userId: userId,
    ).toApi();

    final response = await ApiClient.post(ApiConstants.exerciseDaillys, body);
    if (response is Map) {
      return WorkoutSet.fromJson(response.cast<String, dynamic>());
    }
    return WorkoutSet(
      id: 0,
      seq: seq,
      weight: weight,
      reps: reps,
      done: done,
      obs: obs,
      exerciseId: exerciseId,
      userId: userId,
      createdAt: DateTime.now(),
    );
  }

  static Future<void> updateSet(WorkoutSet set) {
    return ApiClient.put(ApiConstants.exerciseDaillys, set.toApi());
  }

  static Future<void> deleteSet(int setId) {
    return ApiClient.delete('${ApiConstants.exerciseDaillys}/$setId');
  }

  /// Resumo do dia — pode filtrar pelos exercícios do treino atual.
  static Future<WorkoutSession> sessionSummary({
    required int userId,
    DateTime? day,
    int? planId,
    List<int>? exerciseIds,
  }) async {
    final date = toApiDay(day ?? DateTime.now());
    final buffer = StringBuffer(
      '${ApiConstants.exerciseDaillys}/GetSessionSummary?idUser=$userId&date=$date',
    );
    if (planId != null && planId > 0) {
      buffer.write('&idSerie=$planId');
    }
    if (exerciseIds != null && exerciseIds.isNotEmpty) {
      buffer.write('&exerciseIds=${exerciseIds.join(',')}');
    }
    final data = await ApiClient.getObject(buffer.toString());
    return WorkoutSession.fromJson(data);
  }

  // --- Sessão de treino (início/fim) ------------------------------------

  static Future<WorkoutSessionRecord> startSession({
    required int planId,
    required int userId,
  }) async {
    final response = await ApiClient.post('${ApiConstants.workoutSessions}/start', {
      'idSerie': planId,
      'idUser': userId,
    });
    if (response is Map) {
      return WorkoutSessionRecord.fromJson(response.cast<String, dynamic>());
    }
    throw ApiException('Não foi possível iniciar o treino.');
  }

  static Future<WorkoutSessionRecord> endSession(int sessionId) async {
    final response = await ApiClient.put(
      '${ApiConstants.workoutSessions}/end/$sessionId',
      null,
    );
    if (response is Map) {
      return WorkoutSessionRecord.fromJson(response.cast<String, dynamic>());
    }
    throw ApiException('Não foi possível finalizar o treino.');
  }

  static Future<WorkoutSessionRecord?> activeSession({
    required int planId,
    required int userId,
  }) async {
    try {
      final data = await ApiClient.getObject(
        '${ApiConstants.workoutSessions}/active?idUser=$userId&idSerie=$planId',
      );
      if (data.isEmpty) return null;
      return WorkoutSessionRecord.fromJson(data);
    } on ApiException catch (error) {
      if (error.statusCode == 204) return null;
      rethrow;
    }
  }

  /// Junta as séries de hoje de todos os exercícios de um treino —
  /// é daqui que saem o peso total e o número de séries do post.
  static Future<Map<int, List<WorkoutSet>>> planSetsOfDay({
    required List<PlanExercise> exercises,
    required int userId,
    DateTime? day,
  }) async {
    final results = await Future.wait(
      exercises.map(
        (exercise) => setsOfDay(
          exerciseId: exercise.exerciseId,
          userId: userId,
          day: day,
        ).catchError((_) => <WorkoutSet>[]),
      ),
    );

    return {
      for (var i = 0; i < exercises.length; i++)
        exercises[i].exerciseId: results[i],
    };
  }
}
