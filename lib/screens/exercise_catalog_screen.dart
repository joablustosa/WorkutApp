import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../data/gym_exercise_categories.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../widgets/common.dart';

/// Catálogo de exercícios com filtro por grupo muscular.
/// Agrupa por subcategoria para facilitar a montagem do treino.
class ExerciseCatalogScreen extends StatefulWidget {
  const ExerciseCatalogScreen({
    super.key,
    this.excludeExerciseIds = const {},
    this.initialCategory,
  });

  final Set<int> excludeExerciseIds;
  final String? initialCategory;

  @override
  State<ExerciseCatalogScreen> createState() => _ExerciseCatalogScreenState();
}

class _ExerciseCatalogScreenState extends State<ExerciseCatalogScreen> {
  final _searchController = TextEditingController();
  List<Exercise> _all = [];
  bool _loading = true;
  String? _error;
  String _term = '';
  late String _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? kGymCategories.first;
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
      final exercises = await WorkoutService.catalog(type: _category);
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

  void _selectCategory(String category) {
    if (_category == category) return;
    setState(() => _category = category);
    _load();
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
            (exercise.subType ?? '').toLowerCase().contains(term))
        .toList();
  }

  Map<String, List<Exercise>> get _grouped {
    final map = <String, List<Exercise>>{};
    for (final exercise in _filtered) {
      final key = exercise.subType?.trim().isNotEmpty == true
          ? exercise.subType!
          : 'Geral';
      map.putIfAbsent(key, () => []).add(exercise);
    }
    return map;
  }

  Future<void> _createExercise() async {
    final created = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewExerciseSheet(initialCategory: _category),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              itemCount: kGymCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = kGymCategories[index];
                final selected = category == _category;
                return FilterChip(
                  label: Text(category),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: WorkutColors.brand,
                  onSelected: (_) => _selectCategory(category),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : WorkutColors.brandDark,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _term = value),
              decoration: InputDecoration(
                hintText: 'Buscar em $_category...',
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

    final grouped = _grouped;
    if (grouped.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nenhum exercício em $_category',
        message: 'Cadastre um novo ou escolha outra categoria.',
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

    final sections = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final exercises = grouped[section]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                section,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: WorkutColors.muted,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            for (final exercise in exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WorkutCard(
                  onTap: () => Navigator.of(context).pop(exercise),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: WorkutColors.brandSoft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: WorkutColors.brand,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          exercise.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.add_circle_rounded,
                        color: WorkutColors.brand,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NewExerciseSheet extends StatefulWidget {
  const _NewExerciseSheet({required this.initialCategory});

  final String initialCategory;

  @override
  State<_NewExerciseSheet> createState() => _NewExerciseSheetState();
}

class _NewExerciseSheetState extends State<_NewExerciseSheet> {
  final _nameController = TextEditingController();
  final _subTypeController = TextEditingController();
  final _linkController = TextEditingController();
  late String _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialCategory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subTypeController.dispose();
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
        subType: _subTypeController.text.trim(),
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
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Grupo muscular'),
                items: [
                  for (final type in kGymCategories)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _subTypeController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Subcategoria (opcional)',
                  hintText: 'Ex.: Peitoral superior',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Link de referência (opcional)',
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
