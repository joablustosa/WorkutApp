import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';
import '../widgets/common.dart';
import 'plan_detail_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<WorkoutPlan> _plans = [];
  Map<int, int> _exerciseCount = {};
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

    final userId = Session.instance.userId;
    try {
      final plans = await WorkoutService.plans(userId);

      // Quantos exercícios cada treino tem — o card fica muito mais útil.
      final counts = await Future.wait(
        plans.map(
          (plan) => WorkoutService.planExercises(
            userId: userId,
            planId: plan.id,
          ).then((list) => list.length).catchError((_) => 0),
        ),
      );

      if (!mounted) return;
      setState(() {
        _plans = plans;
        _exerciseCount = {
          for (var i = 0; i < plans.length; i++) plans[i].id: counts[i],
        };
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

  Future<void> _createPlan() async {
    final name = await _askName(title: 'Novo treino', hint: 'Ex.: Peito e tríceps');
    if (name == null) return;

    try {
      final plan = await WorkoutService.createPlan(name);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      _openPlan(plan.id == 0 ? _plans.last : plan);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _renamePlan(WorkoutPlan plan) async {
    final name = await _askName(
      title: 'Renomear treino',
      hint: plan.name,
      initial: plan.name,
    );
    if (name == null) return;

    try {
      await WorkoutService.renamePlan(plan, name);
      if (mounted) _load();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _deletePlan(WorkoutPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir treino'),
        content: Text('Tem certeza que quer excluir "${plan.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: WorkutColors.danger),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await WorkoutService.deletePlan(plan.id);
      if (mounted) _load();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<String?> _askName({
    required String title,
    required String hint,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(90, 42)),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPlan(WorkoutPlan plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlanDetailScreen(plan: plan)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus treinos'),
        actions: [
          IconButton(
            onPressed: _createPlan,
            tooltip: 'Novo treino',
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
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
    if (_plans.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.fitness_center_rounded,
            title: 'Monte seu primeiro treino',
            message:
                'Crie um treino, adicione os exercícios e registre cada série com carga e repetições.',
            action: SizedBox(
              width: 220,
              child: FilledButton.icon(
                onPressed: _createPlan,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Criar treino'),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final plan = _plans[index];
        final count = _exerciseCount[plan.id] ?? 0;

        return WorkutCard(
          onTap: () => _openPlan(plan),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [WorkutColors.brand, WorkutColors.brandDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0
                          ? 'Nenhum exercício ainda'
                          : count == 1
                              ? '1 exercício'
                              : '$count exercícios',
                      style: const TextStyle(
                        fontSize: 13,
                        color: WorkutColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: WorkutColors.muted),
                onSelected: (value) {
                  if (value == 'rename') _renamePlan(plan);
                  if (value == 'delete') _deletePlan(plan);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renomear')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
