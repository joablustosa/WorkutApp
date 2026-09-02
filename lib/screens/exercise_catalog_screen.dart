import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../widgets/common.dart';

const List<String> kExerciseTypes = [
  'Peito',
  'Costas',
  'Perna',
  'Ombro',
  'Bíceps',
  'Tríceps',
  'Abdômen',
  'Cardio',
];

/// Catálogo de exercícios. Devolve o exercício escolhido para a tela
/// do treino — e permite cadastrar um novo quando não existe.
class ExerciseCatalogScreen extends StatefulWidget {
  const ExerciseCatalogScreen({super.key, this.excludeExerciseIds = const {}});

  final Set<int> excludeExerciseIds;

  @override
  State<ExerciseCatalogScreen> createState() => _ExerciseCatalogScreenState();
}

class _ExerciseCatalogScreenState extends State<ExerciseCatalogScreen> {
  final _searchController = TextEditingController();
  List<Exercise> _all = [];
  bool _loading = true;
  String? _error;
  String _term = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final exercises = await WorkoutService.catalog();
      if (!mounted) return;
      setState(() {
        _all = exercises;
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

  List<Exercise> get _filtered {
    var list = _all;
    if (widget.excludeExerciseIds.isNotEmpty) {
      list = list
          .where((exercise) => !widget.excludeExerciseIds.contains(exercise.id))
          .toList();
    }
    if (_term.trim().isEmpty) return list;
    final term = _term.toLowerCase();
    return list
        .where((exercise) =>
            exercise.name.toLowerCase().contains(term) ||
            (exercise.type ?? '').toLowerCase().contains(term))
        .toList();
  }

  Future<void> _createExercise() async {
    final created = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewExerciseSheet(),
    );

    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher exercício'),
        actions: [
          IconButton(
            tooltip: 'Criar exercício',
            onPressed: _createExercise,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _term = value),
              decoration: InputDecoration(
                hintText: 'Buscar exercício...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _term.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _term = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
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

    final exercises = _filtered;
    if (exercises.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nenhum exercício encontrado',
        message: 'Cadastre um novo exercício e ele fica disponível para todos.',
        action: SizedBox(
          width: 230,
          child: FilledButton.icon(
            onPressed: _createExercise,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Criar exercício'),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: exercises.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return WorkutCard(
          onTap: () => Navigator.of(context).pop(exercise),
          padding: const EdgeInsets.all(12),
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
                    Text(
                      exercise.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (exercise.type != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        exercise.type!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: WorkutColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline_rounded,
                  color: WorkutColors.brand),
            ],
          ),
        );
      },
    );
  }
}

class _NewExerciseSheet extends StatefulWidget {
  const _NewExerciseSheet();

  @override
  State<_NewExerciseSheet> createState() => _NewExerciseSheetState();
}

class _NewExerciseSheetState extends State<_NewExerciseSheet> {
  final _nameController = TextEditingController();
  final _linkController = TextEditingController();
  String _type = kExerciseTypes.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showToast(context, 'Dê um nome ao exercício', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final exercise = await WorkoutService.createExercise(
        name: name,
        type: _type,
        link: _linkController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(exercise);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Novo exercício',
                subtitle: 'Ele fica disponível para todo mundo do Workut',
                padding: EdgeInsets.only(bottom: 14),
              ),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex.: Supino inclinado com halteres',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Grupo muscular',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in kExerciseTypes)
                    ChoiceChip(
                      label: Text(type),
                      selected: _type == type,
                      showCheckmark: false,
                      selectedColor: WorkutColors.brand,
                      onSelected: (_) => setState(() => _type = type),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _type == type
                            ? Colors.white
                            : WorkutColors.brandDark,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Link de referência (opcional)',
                  hintText: 'Vídeo mostrando a execução',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Criar e adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
