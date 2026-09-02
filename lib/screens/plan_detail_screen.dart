import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../widgets/common.dart';
import 'exercise_catalog_screen.dart';
import 'exercise_session_screen.dart';
import 'workout_session_screen.dart';
import 'workout_summary_screen.dart';

/// Tela do treino: os exercícios, o que já foi feito hoje e o botão
/// que transforma a sessão em post no feed.
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  List<PlanExercise> _exercises = [];
  Map<int, List<WorkoutSet>> _setsToday = {};
  bool _loading = true;
  String? _error;

  int get _userId => Session.instance.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final exercises = await WorkoutService.planExercises(
        userId: _userId,
        planId: widget.plan.id,
      );
      final sets = await WorkoutService.planSetsOfDay(
        exercises: exercises,
        userId: _userId,
      );

      if (!mounted) return;
      setState(() {
        _exercises = exercises;
        _setsToday = sets;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  List<WorkoutSet> get _allSetsToday =>
      _setsToday.values.expand((sets) => sets).toList();

  double get _volumeToday =>
      _allSetsToday.fold(0.0, (total, set) => total + set.volume);

  int get _doneToday => _allSetsToday.where((set) => set.done).length;

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseCatalogScreen(
          excludeExerciseIds:
              _exercises.map((item) => item.exerciseId).toSet(),
        ),
      ),
    );
    if (exercise == null) return;

    try {
      await WorkoutService.addExerciseToPlan(
        planId: widget.plan.id,
        exerciseId: exercise.id,
      );
      if (!mounted) return;
      showToast(context, '${exercise.name} adicionado ao treino');
      _load();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _removeExercise(PlanExercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover exercício'),
        content: Text('Tirar "${exercise.name}" deste treino?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: WorkutColors.danger),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await WorkoutService.removeExerciseFromPlan(exercise.id);
      if (mounted) _load();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _openExercise(PlanExercise exercise) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseSessionScreen(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.name,
          exerciseImage: exercise.image,
          exerciseType: exercise.type,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _startSession() async {
    if (_exercises.isEmpty) {
      showToast(
        context,
        'Adicione pelo menos um exercício para treinar',
        isError: true,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          plan: widget.plan,
          exercises: _exercises,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openSummary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          planId: widget.plan.id,
          planName: widget.plan.name,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.plan.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        backgroundColor: WorkutColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Exercício',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: WorkutColors.brand,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: WorkutColors.brand),
      );
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          ErrorState(message: _error!, onRetry: _load),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _TodayCard(
          volume: _volumeToday,
          sets: _allSetsToday.length,
          done: _doneToday,
          exercises: _exercises.length,
          onStart: _startSession,
          onSummary: _allSetsToday.isEmpty ? null : _openSummary,
        ),
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'Exercícios',
          subtitle: 'Toque para registrar as séries de hoje',
        ),
        if (_exercises.isEmpty)
          EmptyState(
            icon: Icons.add_circle_outline_rounded,
            title: 'Treino vazio',
            message: 'Adicione exercícios para começar a registrar as séries.',
            action: SizedBox(
              width: 220,
              child: FilledButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Adicionar exercício'),
              ),
            ),
          )
        else
          for (final exercise in _exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExerciseTile(
                exercise: exercise,
                sets: _setsToday[exercise.exerciseId] ?? const [],
                onTap: () => _openExercise(exercise),
                onRemove: () => _removeExercise(exercise),
              ),
            ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.volume,
    required this.sets,
    required this.done,
    required this.exercises,
    required this.onStart,
    this.onSummary,
  });

  final double volume;
  final int sets;
  final int done;
  final int exercises;
  final VoidCallback onStart;
  final VoidCallback? onSummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WorkutColors.ink, WorkutColors.brand],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Hoje, ${Format.date(DateTime.now())}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            Format.volume(volume),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          Text(
            'peso total levantado',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(value: '$sets', label: 'séries'),
              _MiniStat(value: '$done', label: 'concluídas'),
              _MiniStat(value: '$exercises', label: 'exercícios'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: WorkutColors.ink,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: Icon(
                    sets > 0
                        ? Icons.play_arrow_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 20,
                  ),
                  label: Text(sets > 0 ? 'Continuar treino' : 'Iniciar treino'),
                ),
              ),
              if (onSummary != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSummary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 17),
                    label: const Text('Postar'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.sets,
    required this.onTap,
    required this.onRemove,
  });

  final PlanExercise exercise;
  final List<WorkoutSet> sets;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final volume = sets.fold(0.0, (total, set) => total + set.volume);
    final hasWork = sets.isNotEmpty;

    return WorkutCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: WorkutColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: exercise.image == null || exercise.image!.isEmpty
                ? const Icon(Icons.sports_gymnastics_rounded,
                    color: WorkutColors.brand, size: 22)
                : Image.network(
                    exercise.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.sports_gymnastics_rounded,
                      color: WorkutColors.brand,
                      size: 22,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (hasWork)
                      WorkutTag(
                        label:
                            '${sets.length}x • ${Format.volume(volume)}',
                        icon: Icons.check_circle_rounded,
                        color: WorkutColors.success,
                        background: WorkutColors.successSoft,
                      )
                    else
                      const WorkutTag(
                        label: 'Sem série hoje',
                        icon: Icons.radio_button_unchecked_rounded,
                        color: WorkutColors.muted,
                        background: WorkutColors.background,
                      ),
                    if (exercise.type != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          exercise.type!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: WorkutColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded,
                size: 18, color: WorkutColors.muted),
          ),
        ],
      ),
    );
  }
}
