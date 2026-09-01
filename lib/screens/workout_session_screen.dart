import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../widgets/common.dart';
import 'exercise_catalog_screen.dart';
import 'exercise_history_screen.dart';
import 'workout_summary_screen.dart';

/// Treino em andamento.
///
/// Tudo acontece aqui: o cronômetro roda, cada exercício abre no lugar
/// para registrar a série e o rodapé mostra o volume subindo. O fundo
/// escuro separa o "estou treinando" do resto do app — e enxerga melhor
/// no meio da academia.
class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({
    super.key,
    required this.plan,
    required this.exercises,
  });

  final WorkoutPlan plan;
  final List<PlanExercise> exercises;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final Map<int, List<WorkoutSet>> _sets = {};
  final Map<int, ExerciseStats> _stats = {};
  final Set<int> _expanded = {};

  late List<PlanExercise> _exercises = List.of(widget.exercises);
  Timer? _ticker;
  DateTime _startedAt = DateTime.now();
  Duration _elapsed = Duration.zero;
  bool _loading = true;
  String? _error;

  int get _userId => Session.instance.userId;

  List<WorkoutSet> get _allSets =>
      _sets.values.expand((sets) => sets).toList();

  double get _volume => _allSets.fold(0.0, (total, set) => total + set.volume);

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sets = await WorkoutService.planSetsOfDay(
        exercises: _exercises,
        userId: _userId,
      );

      // Se já havia série registrada hoje, o cronômetro continua de onde parou.
      final registered = sets.values.expand((list) => list).toList();
      final firstAt = registered
          .map((set) => set.createdAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (earliest, date) =>
              earliest == null || date.isBefore(earliest) ? date : earliest);

      if (!mounted) return;
      setState(() {
        _sets
          ..clear()
          ..addAll(sets);
        _startedAt = firstAt ?? DateTime.now();
        _elapsed = DateTime.now().difference(_startedAt);
        _loading = false;
      });

      _loadStats();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// Carrega o PR de cada exercício em segundo plano — serve só para
  /// avisar quando a carga de hoje passa o recorde.
  Future<void> _loadStats() async {
    for (final exercise in _exercises) {
      try {
        final stats = await WorkoutService.stats(
          exerciseId: exercise.exerciseId,
          userId: _userId,
        );
        if (!mounted) return;
        setState(() => _stats[exercise.exerciseId] = stats);
      } catch (_) {
        // Sem PR carregado o registro de série continua funcionando.
      }
    }
  }

  Future<void> _addSet({
    required PlanExercise exercise,
    required double weight,
    required int reps,
  }) async {
    final current = _sets[exercise.exerciseId] ?? [];
    final previousBest = _stats[exercise.exerciseId]?.bestWeight ?? 0;

    try {
      final created = await WorkoutService.addSet(
        exerciseId: exercise.exerciseId,
        seq: current.length + 1,
        weight: weight,
        reps: reps,
        done: true,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _sets[exercise.exerciseId] = [...current, created]);

      if (weight > previousBest && previousBest > 0) {
        showToast(context, '🏆 Novo PR em ${exercise.name}: ${Format.kg(weight)}');
        setState(() {
          _stats[exercise.exerciseId] = ExerciseStats(
            bestWeight: weight,
            bestOneRepMax: weight * (1 + reps / 30),
            bestVolume: weight * reps,
            totalVolume: 0,
            totalSets: current.length + 1,
            bestWeightReps: reps,
          );
        });
      }
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _removeSet(PlanExercise exercise, WorkoutSet set) async {
    try {
      await WorkoutService.deleteSet(set.id);
      if (!mounted) return;
      setState(() {
        _sets[exercise.exerciseId] = (_sets[exercise.exerciseId] ?? [])
            .where((item) => item.id != set.id)
            .toList();
      });
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExerciseCatalogScreen()),
    );
    if (exercise == null) return;

    try {
      await WorkoutService.addExerciseToPlan(
        planId: widget.plan.id,
        exerciseId: exercise.id,
      );
      final updated = await WorkoutService.planExercises(
        userId: _userId,
        planId: widget.plan.id,
      );
      if (!mounted) return;
      setState(() {
        _exercises = updated;
        _expanded.add(exercise.id);
      });
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _finish() async {
    if (_allSets.isEmpty) {
      final leave = await _confirmLeave();
      if (leave == true && mounted) Navigator.of(context).pop();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          planId: widget.plan.id,
          planName: widget.plan.name,
          fallbackDuration: _elapsed,
        ),
      ),
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<bool?> _confirmLeave() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do treino'),
        content: const Text(
          'Você ainda não registrou nenhuma série. Quer sair mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar treinando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: WorkutColors.danger),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkutColors.ink,
      appBar: AppBar(
        backgroundColor: WorkutColors.ink,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.plan.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(
                    color: WorkutColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  'Treinando · ${Format.duration(_elapsed)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Adicionar exercício',
            onPressed: _addExercise,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _SessionBar(
        volume: _volume,
        sets: _allSets.length,
        exercises: _sets.values.where((list) => list.isNotEmpty).length,
        onFinish: _finish,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }

    if (_exercises.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline_rounded,
                  size: 42, color: Colors.white54),
              const SizedBox(height: 14),
              const Text(
                'Treino sem exercícios',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Adicione o primeiro exercício para começar a registrar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 230,
                child: FilledButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Adicionar exercício'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _exercises.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final exercise = _exercises[index];
        return _SessionExerciseCard(
          exercise: exercise,
          sets: _sets[exercise.exerciseId] ?? const [],
          stats: _stats[exercise.exerciseId],
          expanded: _expanded.contains(exercise.exerciseId),
          onToggle: () => setState(() {
            if (!_expanded.remove(exercise.exerciseId)) {
              _expanded.add(exercise.exerciseId);
            }
          }),
          onAddSet: (weight, reps) =>
              _addSet(exercise: exercise, weight: weight, reps: reps),
          onRemoveSet: (set) => _removeSet(exercise, set),
          onHistory: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExerciseHistoryScreen(
                exerciseId: exercise.exerciseId,
                exerciseName: exercise.name,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cartão de um exercício dentro da sessão: fechado mostra o que já foi
/// feito, aberto vira o teclado de carga e repetições.
class _SessionExerciseCard extends StatefulWidget {
  const _SessionExerciseCard({
    required this.exercise,
    required this.sets,
    required this.stats,
    required this.expanded,
    required this.onToggle,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onHistory,
  });

  final PlanExercise exercise;
  final List<WorkoutSet> sets;
  final ExerciseStats? stats;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(double weight, int reps) onAddSet;
  final void Function(WorkoutSet set) onRemoveSet;
  final VoidCallback onHistory;

  @override
  State<_SessionExerciseCard> createState() => _SessionExerciseCardState();
}

class _SessionExerciseCardState extends State<_SessionExerciseCard> {
  double? _weight;
  int? _reps;
  bool _saving = false;

  /// Sugere a última série feita; sem histórico, começa do PR.
  double get _currentWeight =>
      _weight ??
      (widget.sets.isNotEmpty
          ? widget.sets.last.weight
          : (widget.stats?.bestWeight ?? 20));

  int get _currentReps => _reps ?? (widget.sets.isNotEmpty ? widget.sets.last.reps : 10);

  double get _volume =>
      widget.sets.fold(0.0, (total, set) => total + set.volume);

  Future<void> _submit() async {
    if (_saving || _currentReps <= 0) return;
    setState(() => _saving = true);
    widget.onAddSet(_currentWeight, _currentReps);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      setState(() {
        _saving = false;
        _weight = null;
        _reps = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.sets.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: WorkutColors.inkSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.expanded
              ? WorkutColors.brand
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: done
                          ? WorkutColors.brand
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      done
                          ? Icons.check_rounded
                          : Icons.fitness_center_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.exercise.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          done
                              ? '${widget.sets.length} séries · ${Format.volume(_volume)}'
                              : (widget.stats?.hasRecord == true
                                  ? 'PR ${Format.kg(widget.stats!.bestWeight)}'
                                  : 'Sem série ainda'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onHistory,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.insights_rounded,
                      size: 19,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  Icon(
                    widget.expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          if (widget.sets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final set in widget.sets)
                    _SetChip(
                      set: set,
                      isPr: (widget.stats?.bestWeight ?? 0) > 0 &&
                          set.weight >= widget.stats!.bestWeight,
                      onRemove: () => widget.onRemoveSet(set),
                    ),
                ],
              ),
            ),
          if (widget.expanded) ...[
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DarkStepper(
                          label: 'Carga (kg)',
                          value: Format.weight(_currentWeight),
                          onMinus: () => setState(
                            () => _weight =
                                (_currentWeight - 2.5).clamp(0, 999).toDouble(),
                          ),
                          onPlus: () =>
                              setState(() => _weight = _currentWeight + 2.5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DarkStepper(
                          label: 'Reps',
                          value: '$_currentReps',
                          onMinus: () => setState(
                            () => _reps = (_currentReps - 1).clamp(0, 999),
                          ),
                          onPlus: () => setState(() => _reps = _currentReps + 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        'Registrar ${Format.kg(_currentWeight)} x $_currentReps',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetChip extends StatelessWidget {
  const _SetChip({
    required this.set,
    required this.isPr,
    required this.onRemove,
  });

  final WorkoutSet set;
  final bool isPr;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onRemove,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isPr
              ? WorkutColors.gold.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPr) ...[
              const Icon(Icons.emoji_events_rounded,
                  size: 13, color: WorkutColors.gold),
              const SizedBox(width: 5),
            ],
            Text(
              '${Format.weight(set.weight)} × ${set.reps}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isPr ? WorkutColors.gold : Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkStepper extends StatelessWidget {
  const _DarkStepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _RoundDarkButton(icon: Icons.remove_rounded, onTap: onMinus),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _RoundDarkButton(icon: Icons.add_rounded, onTap: onPlus),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundDarkButton extends StatelessWidget {
  const _RoundDarkButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

/// Rodapé fixo com o placar da sessão e o botão de finalizar.
class _SessionBar extends StatelessWidget {
  const _SessionBar({
    required this.volume,
    required this.sets,
    required this.exercises,
    required this.onFinish,
  });

  final double volume;
  final int sets;
  final int exercises;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: WorkutColors.inkSoft,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              _LiveStat(value: Format.volume(volume), label: 'volume'),
              _LiveStat(value: '$sets', label: 'séries'),
              _LiveStat(value: '$exercises', label: 'exercícios'),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onFinish,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(132, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('Finalizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
