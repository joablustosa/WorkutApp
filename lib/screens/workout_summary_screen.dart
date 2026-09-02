import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/feed.dart';
import '../models/workout.dart';
import '../services/feed_service.dart';
import '../services/workout_service.dart';
import '../widgets/common.dart';

/// Treino finalizado.
///
/// É a tela de recompensa: os números do dia em destaque, os PRs
/// marcados e um caminho só — publicar para os seguidores verem.
class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.planId,
    required this.planName,
    this.sportType,
    this.fallbackDuration,
  });

  final int planId;
  final String planName;
  final String? sportType;

  /// Duração medida na sessão, usada se a API devolver zero.
  final Duration? fallbackDuration;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  WorkoutSession _session = WorkoutSession.empty;
  bool _loading = true;
  bool _publishing = false;
  String? _error;

  int get _minutes {
    if (_session.durationMinutes > 0) return _session.durationMinutes;
    return widget.fallbackDuration?.inMinutes ?? 0;
  }

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
      final session = await WorkoutService.sessionSummary(
        userId: Session.instance.userId,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
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

  /// Legenda sugerida — o usuário pode reescrever no compositor.
  String _suggestedCaption() {
    if (_session.prCount > 0) {
      final pr = _session.exercises.firstWhere(
        (exercise) => exercise.isPr,
        orElse: () => _session.exercises.first,
      );
      return 'Novo PR em ${pr.name}: ${Format.kg(pr.bestWeight)} x ${pr.bestReps}. '
          'Treino ${widget.planName} fechado!';
    }

    final heaviest = _session.exercises.isEmpty
        ? null
        : _session.exercises.reduce(
            (a, b) => a.bestWeight >= b.bestWeight ? a : b,
          );

    if (heaviest != null) {
      return '${widget.planName} concluído. Destaque: ${heaviest.name} '
          '${Format.kg(heaviest.bestWeight)} x ${heaviest.bestReps}.';
    }
    return '${widget.planName} concluído. Bora pro próximo!';
  }

  Future<void> _publish() async {
    final caption = _suggestedCaption();
    final workout = WorkoutPostSummary(
      planId: widget.planId,
      name: widget.planName,
      volume: _session.totalVolume,
      sets: _session.totalSets,
      exercises: _session.totalExercises,
      durationMinutes: _minutes,
      prCount: _session.prCount,
      sportType: widget.sportType,
    );

    setState(() => _publishing = true);
    try {
      await FeedService.createWorkoutPost(
        content: caption,
        workout: workout,
        exercises: _session.exercises,
        sportType: widget.sportType,
      );
      if (!mounted) return;
      showToast(context, 'Treino publicado no feed!');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treino finalizado'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Agora não'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _publishing ? null : _publish,
                        icon: _publishing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.ios_share_rounded, size: 19),
                        label: Text(_publishing ? 'Publicando...' : 'Publicar treino'),
                      ),
                    ),
                  ],
                ),
              ),
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
      return ErrorState(message: _error!, onRetry: _load);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _ScoreCard(
          planName: widget.planName,
          volume: _session.totalVolume,
          sets: _session.totalSets,
          exercises: _session.totalExercises,
          minutes: _minutes,
          prCount: _session.prCount,
        ),
        if (_session.prCount > 0) ...[
          const SizedBox(height: 12),
          _PrBanner(count: _session.prCount),
        ],
        const SizedBox(height: 22),
        const SectionHeader(
          title: 'O que você fez',
          subtitle: 'Ordenado pelo volume de cada exercício',
        ),
        for (final exercise in _session.exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ExerciseRow(exercise: exercise),
          ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.planName,
    required this.volume,
    required this.sets,
    required this.exercises,
    required this.minutes,
    required this.prCount,
  });

  final String planName;
  final double volume;
  final int sets;
  final int exercises;
  final int minutes;
  final int prCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            Format.volume(volume),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.6,
              height: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'peso total levantado hoje',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _ScoreStat(value: '$sets', label: 'séries'),
              _ScoreStat(value: '$exercises', label: 'exercícios'),
              _ScoreStat(
                value: minutes > 0 ? '$minutes min' : '—',
                label: 'duração',
              ),
              _ScoreStat(value: '$prCount', label: 'PRs'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreStat extends StatelessWidget {
  const _ScoreStat({required this.value, required this.label});

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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrBanner extends StatelessWidget {
  const _PrBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      color: WorkutColors.goldSoft,
      borderColor: WorkutColors.gold,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: WorkutColors.gold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1
                  ? 'Você bateu 1 recorde pessoal hoje!'
                  : 'Você bateu $count recordes pessoais hoje!',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF96650B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final SessionExercise exercise;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      padding: const EdgeInsets.all(14),
      borderColor: exercise.isPr ? WorkutColors.gold : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: WorkutColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: exercise.image == null || exercise.image!.isEmpty
                ? const Icon(Icons.sports_gymnastics_rounded,
                    color: WorkutColors.brand, size: 21)
                : Image.network(
                    exercise.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.sports_gymnastics_rounded,
                      color: WorkutColors.brand,
                      size: 21,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (exercise.isPr) ...[
                      const SizedBox(width: 8),
                      const WorkutTag(
                        label: 'PR',
                        icon: Icons.emoji_events_rounded,
                        color: WorkutColors.gold,
                        background: WorkutColors.goldSoft,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.sets} séries · melhor ${Format.kg(exercise.bestWeight)} x ${exercise.bestReps}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WorkutColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Format.volume(exercise.volume),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: WorkutColors.brand,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
