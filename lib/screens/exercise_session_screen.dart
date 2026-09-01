import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../widgets/common.dart';
import 'exercise_history_screen.dart';

/// Execução do exercício: registra série por série, mostra o volume
/// do dia e avisa quando você bate um novo PR.
class ExerciseSessionScreen extends StatefulWidget {
  const ExerciseSessionScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.exerciseImage,
    this.exerciseType,
  });

  final int exerciseId;
  final String exerciseName;
  final String? exerciseImage;
  final String? exerciseType;

  @override
  State<ExerciseSessionScreen> createState() => _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends State<ExerciseSessionScreen> {
  List<WorkoutSet> _sets = [];
  ExerciseStats _stats = ExerciseStats.empty;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  double _weight = 20;
  int _reps = 10;
  WorkoutSet? _editing;

  int get _userId => Session.instance.userId;

  double get _volumeToday =>
      _sets.fold(0.0, (total, set) => total + set.volume);

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
      final results = await Future.wait([
        WorkoutService.setsOfDay(
          exerciseId: widget.exerciseId,
          userId: _userId,
        ),
        WorkoutService.stats(
          exerciseId: widget.exerciseId,
          userId: _userId,
        ),
      ]);

      if (!mounted) return;
      final sets = results[0] as List<WorkoutSet>;
      setState(() {
        _sets = sets;
        _stats = results[1] as ExerciseStats;
        _loading = false;
        if (sets.isNotEmpty) {
          _weight = sets.last.weight;
          _reps = sets.last.reps;
        } else if (_stats.bestWeight > 0) {
          _weight = _stats.bestWeight;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_reps <= 0) {
      showToast(context, 'Informe as repetições', isError: true);
      return;
    }

    final previousBest = _stats.bestWeight;
    setState(() => _saving = true);

    try {
      if (_editing != null) {
        final updated = WorkoutSet(
          id: _editing!.id,
          seq: _editing!.seq,
          weight: _weight,
          reps: _reps,
          done: _editing!.done,
          obs: _editing!.obs,
          exerciseId: widget.exerciseId,
          userId: _userId,
          createdAt: _editing!.createdAt,
        );
        await WorkoutService.updateSet(updated);
        _editing = null;
      } else {
        await WorkoutService.addSet(
          exerciseId: widget.exerciseId,
          seq: _sets.length + 1,
          weight: _weight,
          reps: _reps,
        );
      }

      await _load();

      if (mounted && _weight > previousBest && _weight > 0) {
        _celebratePr();
      }
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _celebratePr() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: WorkutColors.gold),
            SizedBox(width: 10),
            Text('Novo PR!'),
          ],
        ),
        content: Text(
          'Você acabou de bater seu recorde em ${widget.exerciseName}: '
          '${Format.kg(_weight)} x $_reps. Bora postar isso no feed?',
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDone(WorkoutSet set) async {
    setState(() => set.done = !set.done);
    try {
      await WorkoutService.updateSet(set);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => set.done = !set.done);
      showToast(context, error.message, isError: true);
    }
  }

  Future<void> _deleteSet(WorkoutSet set) async {
    try {
      await WorkoutService.deleteSet(set.id);
      if (mounted) _load();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _editObs(WorkoutSet set) async {
    final controller = TextEditingController(text: set.obs ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anotação da série'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Ex.: última repetição falhou, drop set...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: FilledButton.styleFrom(minimumSize: const Size(90, 42)),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      await WorkoutService.updateSet(set.copyWith(obs: result));
      if (mounted) _load();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  void _startEdit(WorkoutSet set) {
    setState(() {
      _editing = set;
      _weight = set.weight;
      _reps = set.reps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        actions: [
          IconButton(
            tooltip: 'Histórico e PRs',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExerciseHistoryScreen(
                  exerciseId: widget.exerciseId,
                  exerciseName: widget.exerciseName,
                ),
              ),
            ),
            icon: const Icon(Icons.insights_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(),
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              _HeaderCard(
                name: widget.exerciseName,
                image: widget.exerciseImage,
                type: widget.exerciseType,
                stats: _stats,
              ),
              const SizedBox(height: 16),
              _SessionSummary(
                volume: _volumeToday,
                sets: _sets.length,
                bestToday: _sets.isEmpty
                    ? 0
                    : _sets
                        .map((set) => set.weight)
                        .reduce((a, b) => a > b ? a : b),
              ),
              const SizedBox(height: 20),
              SectionHeader(
                title: 'Séries de hoje',
                subtitle: _sets.isEmpty
                    ? 'Nenhuma série registrada ainda'
                    : '${_sets.length} registradas',
              ),
              if (_sets.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Ajuste a carga e as repetições abaixo e toque em adicionar.',
                    style: TextStyle(color: WorkutColors.muted, fontSize: 14),
                  ),
                )
              else
                for (final set in _sets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SetTile(
                      set: set,
                      isPr: _stats.bestWeight > 0 &&
                          set.weight >= _stats.bestWeight,
                      isEditing: _editing?.id == set.id,
                      onToggleDone: () => _toggleDone(set),
                      onEdit: () => _startEdit(set),
                      onObs: () => _editObs(set),
                      onDelete: () => _deleteSet(set),
                    ),
                  ),
            ],
          ),
        ),
        _Controls(
          weight: _weight,
          reps: _reps,
          saving: _saving,
          isEditing: _editing != null,
          onWeightChanged: (value) =>
              setState(() => _weight = value < 0 ? 0 : value),
          onRepsChanged: (value) => setState(() => _reps = value < 0 ? 0 : value),
          onSave: _save,
          onCancelEdit: () => setState(() => _editing = null),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    required this.image,
    required this.type,
    required this.stats,
  });

  final String name;
  final String? image;
  final String? type;
  final ExerciseStats stats;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: WorkutColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: image == null || image!.isEmpty
                ? const Icon(Icons.sports_gymnastics_rounded,
                    color: WorkutColors.brand, size: 26)
                : Image.network(
                    image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.sports_gymnastics_rounded,
                      color: WorkutColors.brand,
                      size: 26,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (stats.hasRecord)
                      WorkutTag(
                        label: 'PR ${Format.kg(stats.bestWeight)}',
                        icon: Icons.emoji_events_rounded,
                        color: WorkutColors.gold,
                        background: WorkutColors.goldSoft,
                      )
                    else
                      const WorkutTag(
                        label: 'Sem PR ainda',
                        icon: Icons.emoji_events_outlined,
                        color: WorkutColors.muted,
                        background: WorkutColors.background,
                      ),
                    if (type != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          type!,
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
        ],
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.volume,
    required this.sets,
    required this.bestToday,
  });

  final double volume;
  final int sets;
  final double bestToday;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              value: Format.volume(volume),
              label: 'peso total',
              color: WorkutColors.brand,
            ),
          ),
          const SizedBox(
            height: 34,
            child: VerticalDivider(color: WorkutColors.line),
          ),
          Expanded(child: StatTile(value: '$sets', label: 'séries')),
          const SizedBox(
            height: 34,
            child: VerticalDivider(color: WorkutColors.line),
          ),
          Expanded(
            child: StatTile(
              value: bestToday > 0 ? Format.kg(bestToday) : '—',
              label: 'maior carga',
            ),
          ),
        ],
      ),
    );
  }
}

class _SetTile extends StatelessWidget {
  const _SetTile({
    required this.set,
    required this.isPr,
    required this.isEditing,
    required this.onToggleDone,
    required this.onEdit,
    required this.onObs,
    required this.onDelete,
  });

  final WorkoutSet set;
  final bool isPr;
  final bool isEditing;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onObs;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      onTap: onEdit,
      borderColor: isEditing ? WorkutColors.brand : null,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: WorkutColors.brandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '${set.seq}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: WorkutColors.brandDark,
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
                    Text(
                      '${Format.kg(set.weight)} x ${set.reps}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isPr) ...[
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
                const SizedBox(height: 3),
                Text(
                  set.obs != null && set.obs!.isNotEmpty
                      ? set.obs!
                      : '${Format.volume(set.volume)} de volume',
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
          IconButton(
            onPressed: onObs,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.sticky_note_2_outlined,
              size: 19,
              color: set.obs != null && set.obs!.isNotEmpty
                  ? WorkutColors.brand
                  : WorkutColors.muted,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 19, color: WorkutColors.muted),
          ),
          Checkbox(
            value: set.done,
            onChanged: (_) => onToggleDone(),
            activeColor: WorkutColors.success,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.weight,
    required this.reps,
    required this.saving,
    required this.isEditing,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onSave,
    required this.onCancelEdit,
  });

  final double weight;
  final int reps;
  final bool saving;
  final bool isEditing;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onSave;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: WorkutColors.surface,
        border: Border(top: BorderSide(color: WorkutColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Stepper(
                      label: 'Carga (kg)',
                      value: Format.weight(weight),
                      onMinus: () => onWeightChanged(weight - 2.5),
                      onPlus: () => onWeightChanged(weight + 2.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stepper(
                      label: 'Repetições',
                      value: '$reps',
                      onMinus: () => onRepsChanged(reps - 1),
                      onPlus: () => onRepsChanged(reps + 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isEditing) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancelEdit,
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: saving ? null : onSave,
                      icon: Icon(
                        isEditing
                            ? Icons.check_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 20,
                      ),
                      label: Text(
                        isEditing ? 'Salvar série' : 'Adicionar série',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
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
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: WorkutColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: WorkutColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WorkutColors.line),
          ),
          child: Row(
            children: [
              _RoundButton(icon: Icons.remove_rounded, onTap: onMinus),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _RoundButton(icon: Icons.add_rounded, onTap: onPlus),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Icon(icon, size: 20, color: WorkutColors.brand),
      ),
    );
  }
}
