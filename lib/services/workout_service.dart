import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/json_utils.dart';
import '../core/session.dart';
import '../models/workout.dart';

class WorkoutService {
  // --- Catálogo de exercícios -------------------------------------------

  static Future<List<Exercise>> catalog() async {
    final rows = await ApiClient.getList(ApiConstants.exercises);
    final exercises = rows.map(Exercise.fromJson).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return exercises;
  }

  static Future<Exercise> byId(int id) async {
    final row = await ApiClient.getObject('${ApiConstants.exercises}/$id');
    return Exercise.fromJson(row);
  }

  static Future<Exercise> createExercise({
    required String name,
    required String type,
    String? image,
    String? link,
  }) async {
    final response = await ApiClient.post(ApiConstants.exercises, {
      'id': null,
      'name': name,
      'type': type,
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

  static Future<WorkoutPlan> createPlan(String name) async {
    final userId = Session.instance.userId;
    final response = await ApiClient.post(ApiConstants.exerciseSeries, {
      'id': null,
      'name': name,
      'idUser': userId,
      'dateTimeCreated': toApiDate(DateTime.now()),
    });
    if (response is Map) {
      return WorkoutPlan.fromJson(response.cast<String, dynamic>());
    }
    return WorkoutPlan(id: 0, name: name, userId: userId);
  }

  static Future<void> renamePlan(WorkoutPlan plan, String name) {
    return ApiClient.put(ApiConstants.exerciseSeries, {
      'id': plan.id,
      'name': name,
      'idUser': plan.userId,
      'dateTimeCreated': toApiDate(plan.createdAt ?? DateTime.now()),
      'myOrder': plan.order,
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
  }) {
    return ApiClient.post(ApiConstants.exerciseBySeries, {
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

  /// Resumo do dia inteiro: volume, séries, exercícios e PRs. Uma
  /// chamada só, calculada na API.
  static Future<WorkoutSession> sessionSummary({
    required int userId,
    DateTime? day,
  }) async {
    final date = toApiDay(day ?? DateTime.now());
    final data = await ApiClient.getObject(
      '${ApiConstants.exerciseDaillys}/GetSessionSummary'
      '?idUser=$userId&date=$date',
    );
    return WorkoutSession.fromJson(data);
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
