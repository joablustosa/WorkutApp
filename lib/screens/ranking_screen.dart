import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/workout.dart';
import '../services/user_service.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

/// Ranking geral: a API calcula um score relativo ao peso e à altura,
/// então quem levanta muito para o próprio corpo sobe.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  List<RankingEntry> _entries = [];
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
      final entries = await UserService.ranking();
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
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
    if (_entries.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 40),
          EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Ranking vazio',
            message: 'Registre séries nos seus treinos para entrar na disputa.',
          ),
        ],
      );
    }

    final myId = Session.instance.userId;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _entries.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) return const _RankingIntro();

        final position = index;
        final entry = _entries[index - 1];
        return _RankingTile(
          entry: entry,
          position: position,
          isMe: entry.userId == myId,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: entry.userId),
            ),
          ),
        );
      },
    );
  }
}

class _RankingIntro extends StatelessWidget {
  const _RankingIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WorkutColors.gold, WorkutColors.brand],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quem está levantando mais',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score relativo ao seu peso e altura — força de verdade, não só número.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.entry,
    required this.position,
    required this.isMe,
    required this.onTap,
  });

  final RankingEntry entry;
  final int position;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (position) {
      1 => WorkutColors.gold,
      2 => const Color(0xFF9AA3B8),
      3 => const Color(0xFFCD7F32),
      _ => WorkutColors.muted,
    };

    return WorkutCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      color: isMe ? WorkutColors.brandSoft : null,
      borderColor: isMe ? WorkutColors.brand : null,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: position <= 3
                ? Icon(Icons.military_tech_rounded, color: medalColor, size: 26)
                : Text(
                    '$position',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: WorkutColors.muted,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          WorkutAvatar(
            url: entry.userImage,
            name: entry.userName,
            size: 44,
            borderColor: position <= 3 ? medalColor : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.exerciseName} • ${Format.kg(entry.weight ?? 0)} x ${entry.reps ?? 0}',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.score.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: WorkutColors.brand,
                ),
              ),
              const Text(
                'score',
                style: TextStyle(fontSize: 11, color: WorkutColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
