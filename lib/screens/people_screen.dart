import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../services/social_service.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

/// Descobrir gente para seguir e responder aos pedidos recebidos.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, this.showPendingFirst = false});

  final bool showPendingFirst;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _searchController = TextEditingController();
  List<Person> _people = [];
  bool _loading = true;
  String? _error;
  String _term = '';
  final Set<int> _busy = {};

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
      final people = await SocialService.people();
      if (!mounted) return;
      setState(() {
        _people = people;
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

  List<Person> get _pending =>
      _people.where((person) => person.isPendingReceived).toList();

  List<Person> get _filtered {
    final term = _term.trim().toLowerCase();
    final list = term.isEmpty
        ? _people
        : _people
            .where((person) => person.fullName.toLowerCase().contains(term))
            .toList();

    // Quem ainda não sigo aparece primeiro: é o que dá o que fazer.
    list.sort((a, b) {
      int rank(Person person) {
        if (person.isPendingReceived) return 0;
        if (person.status == 'nenhum') return 1;
        if (person.isPendingSent) return 2;
        return 3;
      }

      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return list;
  }

  Future<void> _run(Person person, Future<void> Function() action) async {
    setState(() => _busy.add(person.userId));
    try {
      await action();
      await _load();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy.remove(person.userId));
    }
  }

  void _openProfile(Person person) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: person.userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pessoas'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _term = value),
              decoration: InputDecoration(
                hintText: 'Buscar quem treina...',
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: WorkutColors.brand,
              child: _buildBody(),
            ),
          ),
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
      return ListView(
        children: [
          const SizedBox(height: 60),
          ErrorState(message: _error!, onRetry: _load),
        ],
      );
    }

    final people = _filtered;
    final pending = _pending;

    if (people.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 40),
          EmptyState(
            icon: Icons.group_outlined,
            title: 'Ninguém por aqui',
            message: 'Tente outro nome ou volte mais tarde.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (pending.isNotEmpty && _term.isEmpty) ...[
          SectionHeader(
            title: 'Pedidos para seguir você',
            subtitle: '${pending.length} esperando resposta',
          ),
          const SizedBox(height: 4),
        ],
        for (final person in people)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PersonTile(
              person: person,
              busy: _busy.contains(person.userId),
              onTap: () => _openProfile(person),
              onFollow: () => _run(
                person,
                () => SocialService.follow(person.userId),
              ),
              onAccept: () => _run(
                person,
                () => SocialService.acceptFollow(person),
              ),
              onUnfollow: () => _run(
                person,
                () => SocialService.unfollow(person),
              ),
            ),
          ),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.busy,
    required this.onTap,
    required this.onFollow,
    required this.onAccept,
    required this.onUnfollow,
  });

  final Person person;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onFollow;
  final VoidCallback onAccept;
  final VoidCallback onUnfollow;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      borderColor: person.isPendingReceived ? WorkutColors.brand : null,
      child: Row(
        children: [
          WorkutAvatar(
            url: person.photo,
            name: person.fullName,
            size: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(person),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: WorkutColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: WorkutColors.brand,
              ),
            )
          else
            _actionButton(),
        ],
      ),
    );
  }

  Widget _actionButton() {
    if (person.isPendingReceived) {
      return FilledButton(
        onPressed: onAccept,
        style: FilledButton.styleFrom(
          minimumSize: const Size(92, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: WorkutColors.brand,
        ),
        child: const Text('Aceitar'),
      );
    }

    if (person.isFollowing) {
      return OutlinedButton(
        onPressed: onUnfollow,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(96, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('Seguindo'),
      );
    }

    if (person.isPendingSent) {
      return OutlinedButton(
        onPressed: onUnfollow,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(100, 38),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: WorkutColors.muted,
        ),
        child: const Text('Solicitado'),
      );
    }

    return FilledButton(
      onPressed: onFollow,
      style: FilledButton.styleFrom(
        minimumSize: const Size(90, 38),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: const Text('Seguir'),
    );
  }

  static String _statusLabel(Person person) {
    if (person.isPendingReceived) return 'Quer seguir você';
    if (person.isPendingSent) return 'Aguardando aceite';
    if (person.isFollowing) return 'Vocês treinam juntos';
    return 'Ainda não conectados';
  }
}
