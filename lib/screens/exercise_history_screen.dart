import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../widgets/common.dart';

/// Histórico do exercício: PR, 1RM estimado, volume total e cada série
/// já registrada, agrupada por dia.
class ExerciseHistoryScreen extends StatefulWidget {
  const ExerciseHistoryScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  final int exerciseId;
  final String exerciseName;

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  List<WorkoutSet> _sets = [];
  ExerciseStats _stats = ExerciseStats.empty;
  bool _loading = true;
  String? _error;

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
      final sets = await WorkoutService.history(
        exerciseId: widget.exerciseId,
        userId: Session.instance.userId,
      );
      if (!mounted) return;
      setState(() {
        _sets = sets;
        _stats = ExerciseStats.fromSets(sets);
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

  /// Agrupa as séries por dia, do mais recente para o mais antigo.
  List<MapEntry<DateTime, List<WorkoutSet>>> get _byDay {
    final map = <DateTime, List<WorkoutSet>>{};
    for (final set in _sets) {
      final date = set.createdAt;
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      map.putIfAbsent(day, () => []).add(set);
    }

    final entries = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    for (final entry in entries) {
      entry.value.sort((a, b) => a.seq.compareTo(b.seq));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exerciseName)),
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
    if (_sets.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 40),
          EmptyState(
            icon: Icons.insights_rounded,
            title: 'Sem histórico ainda',
            message:
                'Assim que você registrar séries deste exercício, seus recordes aparecem aqui.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _PrCard(stats: _stats),
        const SizedBox(height: 16),
        WorkutCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  value: Format.volume(_stats.totalVolume),
                  label: 'volume total',
                ),
              ),
              const SizedBox(
                height: 34,
                child: VerticalDivider(color: WorkutColors.line),
              ),
              Expanded(
                child: StatTile(
                  value: '${_stats.totalSets}',
                  label: 'séries feitas',
                ),
              ),
              const SizedBox(
                height: 34,
                child: VerticalDivider(color: WorkutColors.line),
              ),
              Expanded(
                child: StatTile(
                  value: Format.volume(_stats.bestVolume),
                  label: 'melhor série',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(
          title: 'Linha do tempo',
          subtitle: 'Cada dia de treino deste exercício',
        ),
        for (final entry in _byDay)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DayCard(day: entry.key, sets: entry.value, stats: _stats),
          ),
      ],
    );
  }
}

class _PrCard extends StatelessWidget {
  const _PrCard({required this.stats});

  final ExerciseStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WorkutColors.ink, WorkutColors.brandDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: WorkutColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'Seu recorde pessoal',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Format.weight(stats.bestWeight),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'kg x ${stats.bestWeightReps}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '1RM estimado: ${Format.kg(stats.bestOneRepMax)}'
            '${stats.bestWeightDate != null ? '  •  ${Format.date(stats.bestWeightDate)}' : ''}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.sets,
    required this.stats,
  });

  final DateTime day;
  final List<WorkoutSet> sets;
  final ExerciseStats stats;

  @override
  Widget build(BuildContext context) {
    final volume = sets.fold(0.0, (total, set) => total + set.volume);

    return WorkutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Format.fullDate(day),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              WorkutTag(
                label: Format.volume(volume),
                icon: Icons.local_fire_department_rounded,
              ),
            ],
          ),
          const Divider(height: 18),
          for (final set in sets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${set.seq}.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: WorkutColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${Format.kg(set.weight)} x ${set.reps}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (stats.bestWeight > 0 &&
                      set.weight >= stats.bestWeight) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.emoji_events_rounded,
                        size: 15, color: WorkutColors.gold),
                  ],
                  const Spacer(),
                  if (set.obs != null && set.obs!.isNotEmpty)
                    const Icon(Icons.sticky_note_2_outlined,
                        size: 15, color: WorkutColors.muted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
