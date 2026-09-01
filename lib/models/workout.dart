import '../core/json_utils.dart';

/// Exercício do catálogo (`Exercises/v1`).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.image,
    this.link,
    this.type,
  });

  final int id;
  final String name;
  final String? image;
  final String? link;
  final String? type;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: asInt(json, 'id') ?? 0,
      name: asString(json, 'name') ?? 'Exercício',
      image: asString(json, 'image'),
      link: asString(json, 'link'),
      type: asString(json, 'type'),
    );
  }

  Map<String, dynamic> toApi() => {
        'id': id == 0 ? null : id,
        'name': name,
        'image': image ?? '',
        'link': link ?? '',
        'type': type ?? 'Musculação',
      };
}

/// Treino montado pelo usuário (`ExerciseSeries/v1`).
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.userId,
    this.order,
    this.createdAt,
  });

  final int id;
  final String name;
  final int userId;
  final int? order;
  final DateTime? createdAt;

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: asInt(json, 'id') ?? 0,
      name: asString(json, 'name') ?? 'Treino',
      userId: asInt(json, 'idUser') ?? 0,
      order: asInt(json, 'myOrder'),
      createdAt: asDate(json, 'dateTimeCreated'),
    );
  }

  Map<String, dynamic> toApi() => {
        'id': id == 0 ? null : id,
        'name': name,
        'idUser': userId,
        'dateTimeCreated': toApiDate(createdAt ?? DateTime.now()),
        'myOrder': order,
      };
}

/// Exercício dentro de um treino (`ExerciseBySeries/v1/MyExerciseSerie`).
class PlanExercise {
  const PlanExercise({
    required this.id,
    required this.exerciseId,
    required this.name,
    this.planId,
    this.image,
    this.type,
    this.order,
  });

  final int id;
  final int exerciseId;
  final String name;
  final int? planId;
  final String? image;
  final String? type;
  final int? order;

  factory PlanExercise.fromJson(Map<String, dynamic> json) {
    return PlanExercise(
      id: asInt(json, 'id') ?? 0,
      exerciseId: asInt(json, 'idExercise') ?? 0,
      planId: asInt(json, 'idSerie'),
      name: asString(json, 'name') ?? 'Exercício',
      image: asString(json, 'image'),
      type: asString(json, 'type'),
      order: asInt(json, 'orderExercise'),
    );
  }
}

/// Uma série executada (`ExerciseDaillys/v1`).
class WorkoutSet {
  WorkoutSet({
    required this.id,
    required this.seq,
    required this.weight,
    required this.reps,
    required this.done,
    required this.exerciseId,
    required this.userId,
    this.obs,
    this.createdAt,
  });

  final int id;
  final int seq;
  final double weight;
  final int reps;
  final int exerciseId;
  final int userId;
  bool done;
  String? obs;
  final DateTime? createdAt;

  /// Volume da série: carga x repetições.
  double get volume => weight * reps;

  /// 1RM estimado pela fórmula de Epley — é o que define o PR.
  double get estimatedOneRepMax =>
      reps <= 0 ? weight : weight * (1 + reps / 30.0);

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: asInt(json, 'id') ?? 0,
      seq: asInt(json, 'seq') ?? 0,
      weight: asDouble(json, 'weight') ?? 0,
      reps: asInt(json, 'reps') ?? 0,
      done: asBool(json, 'done'),
      obs: asString(json, 'obs'),
      exerciseId: asInt(json, 'idExercise') ?? 0,
      userId: asInt(json, 'idUserCreated') ?? 0,
      createdAt: asDate(json, 'dateTimeCreates'),
    );
  }

  Map<String, dynamic> toApi() => {
        'id': id == 0 ? null : id,
        'seq': seq,
        'weight': weight,
        'reps': reps,
        'done': done,
        'obs': obs,
        'idExercise': exerciseId,
        'idUserCreated': userId,
        'dateTimeCreates': toApiDate(createdAt ?? DateTime.now()),
      };

  WorkoutSet copyWith({bool? done, String? obs}) {
    return WorkoutSet(
      id: id,
      seq: seq,
      weight: weight,
      reps: reps,
      done: done ?? this.done,
      obs: obs ?? this.obs,
      exerciseId: exerciseId,
      userId: userId,
      createdAt: createdAt,
    );
  }
}

/// Números de um exercício: PR, melhor volume e total levantado.
class ExerciseStats {
  const ExerciseStats({
    required this.bestWeight,
    required this.bestOneRepMax,
    required this.bestVolume,
    required this.totalVolume,
    required this.totalSets,
    this.bestWeightReps = 0,
    this.bestWeightDate,
  });

  final double bestWeight;
  final double bestOneRepMax;
  final double bestVolume;
  final double totalVolume;
  final int totalSets;
  final int bestWeightReps;
  final DateTime? bestWeightDate;

  static const ExerciseStats empty = ExerciseStats(
    bestWeight: 0,
    bestOneRepMax: 0,
    bestVolume: 0,
    totalVolume: 0,
    totalSets: 0,
  );

  bool get hasRecord => totalSets > 0;

  factory ExerciseStats.fromSets(List<WorkoutSet> sets) {
    if (sets.isEmpty) return ExerciseStats.empty;

    var bestWeight = 0.0;
    var bestOneRepMax = 0.0;
    var bestVolume = 0.0;
    var totalVolume = 0.0;
    var bestWeightReps = 0;
    DateTime? bestWeightDate;

    for (final set in sets) {
      totalVolume += set.volume;
      if (set.volume > bestVolume) bestVolume = set.volume;
      if (set.estimatedOneRepMax > bestOneRepMax) {
        bestOneRepMax = set.estimatedOneRepMax;
      }
      if (set.weight > bestWeight) {
        bestWeight = set.weight;
        bestWeightReps = set.reps;
        bestWeightDate = set.createdAt;
      }
    }

    return ExerciseStats(
      bestWeight: bestWeight,
      bestOneRepMax: bestOneRepMax,
      bestVolume: bestVolume,
      totalVolume: totalVolume,
      totalSets: sets.length,
      bestWeightReps: bestWeightReps,
      bestWeightDate: bestWeightDate,
    );
  }
}

/// Linha do ranking geral (`Homes/v1/GetRanking`).
class RankingEntry {
  const RankingEntry({
    required this.userId,
    required this.userName,
    required this.exerciseName,
    required this.score,
    this.position,
    this.userImage,
    this.exerciseImage,
    this.exerciseType,
    this.weight,
    this.reps,
  });

  final int userId;
  final String userName;
  final String exerciseName;
  final double score;
  final int? position;
  final String? userImage;
  final String? exerciseImage;
  final String? exerciseType;
  final double? weight;
  final int? reps;

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      userId: asInt(json, 'idUser') ?? 0,
      userName: asString(json, 'nameUser') ?? 'Atleta Workut',
      userImage: asString(json, 'imageUser'),
      exerciseName: asString(json, 'nameExercise') ?? 'Exercício',
      exerciseImage: asString(json, 'imageExercise'),
      exerciseType: asString(json, 'typeExercise'),
      weight: asDouble(json, 'weightDailly'),
      reps: asInt(json, 'repsDailly'),
      score: asDouble(json, 'rankingScore') ?? 0,
      position: asInt(json, 'position'),
    );
  }
}

/// Resumo de um dia de treino (`ExerciseDaillys/v1/GetSessionSummary`).
class WorkoutSession {
  const WorkoutSession({
    required this.date,
    required this.totalVolume,
    required this.totalSets,
    required this.doneSets,
    required this.totalExercises,
    required this.prCount,
    required this.durationMinutes,
    required this.exercises,
  });

  final DateTime date;
  final double totalVolume;
  final int totalSets;
  final int doneSets;
  final int totalExercises;
  final int prCount;
  final int durationMinutes;
  final List<SessionExercise> exercises;

  static final WorkoutSession empty = WorkoutSession(
    date: DateTime.now(),
    totalVolume: 0,
    totalSets: 0,
    doneSets: 0,
    totalExercises: 0,
    prCount: 0,
    durationMinutes: 0,
    exercises: const [],
  );

  bool get hasWork => totalSets > 0;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final rows = pick(json, 'exercises');
    return WorkoutSession(
      date: asDate(json, 'date') ?? DateTime.now(),
      totalVolume: asDouble(json, 'totalVolume') ?? 0,
      totalSets: asInt(json, 'totalSets') ?? 0,
      doneSets: asInt(json, 'doneSets') ?? 0,
      totalExercises: asInt(json, 'totalExercises') ?? 0,
      prCount: asInt(json, 'prCount') ?? 0,
      durationMinutes: asInt(json, 'durationMinutes') ?? 0,
      exercises: rows is List
          ? rows
              .whereType<Map>()
              .map((e) => SessionExercise.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}

/// Um exercício dentro do resumo do dia.
class SessionExercise {
  const SessionExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.volume,
    required this.bestWeight,
    required this.bestReps,
    required this.isPr,
    this.image,
    this.type,
  });

  final int exerciseId;
  final String name;
  final int sets;
  final double volume;
  final double bestWeight;
  final int bestReps;
  final bool isPr;
  final String? image;
  final String? type;

  factory SessionExercise.fromJson(Map<String, dynamic> json) {
    return SessionExercise(
      exerciseId: asInt(json, 'idExercise') ?? 0,
      name: asString(json, 'name') ?? 'Exercício',
      image: asString(json, 'image'),
      type: asString(json, 'type'),
      sets: asInt(json, 'sets') ?? 0,
      volume: asDouble(json, 'volume') ?? 0,
      bestWeight: asDouble(json, 'bestWeight') ?? 0,
      bestReps: asInt(json, 'bestReps') ?? 0,
      isPr: asBool(json, 'isPr'),
    );
  }
}

/// Estatísticas do perfil (`Homes/v1/TrainingStats/{id}`).
class TrainingStats {
  const TrainingStats({
    required this.volumeLast7Days,
    required this.volumeThisMonth,
    required this.bestVolumeDay,
    required this.workoutsThisMonth,
    required this.totalWorkouts,
    required this.totalSets,
    required this.personalRecords,
    required this.streakWeeks,
    this.lastWorkout,
  });

  final double volumeLast7Days;
  final double volumeThisMonth;
  final double bestVolumeDay;
  final int workoutsThisMonth;
  final int totalWorkouts;
  final int totalSets;
  final int personalRecords;
  final int streakWeeks;
  final DateTime? lastWorkout;

  static const TrainingStats empty = TrainingStats(
    volumeLast7Days: 0,
    volumeThisMonth: 0,
    bestVolumeDay: 0,
    workoutsThisMonth: 0,
    totalWorkouts: 0,
    totalSets: 0,
    personalRecords: 0,
    streakWeeks: 0,
  );

  bool get hasTraining => totalWorkouts > 0;

  factory TrainingStats.fromJson(Map<String, dynamic> json) {
    return TrainingStats(
      volumeLast7Days: asDouble(json, 'volumeLast7Days') ?? 0,
      volumeThisMonth: asDouble(json, 'volumeThisMonth') ?? 0,
      bestVolumeDay: asDouble(json, 'bestVolumeDay') ?? 0,
      workoutsThisMonth: asInt(json, 'workoutsThisMonth') ?? 0,
      totalWorkouts: asInt(json, 'totalWorkouts') ?? 0,
      totalSets: asInt(json, 'totalSets') ?? 0,
      personalRecords: asInt(json, 'personalRecords') ?? 0,
      streakWeeks: asInt(json, 'streakWeeks') ?? 0,
      lastWorkout: asDate(json, 'lastWorkout'),
    );
  }
}
