import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../models/feed.dart';
import '../models/social.dart';
import '../models/workout.dart';
import '../services/auth_service.dart';
import '../services/feed_service.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import 'edit_profile_screen.dart';
import 'scrap_chat_screen.dart';

enum _ProfileTab { posts, testimonies }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppUser? _user;
  HomeSummary _summary = HomeSummary.empty;
  TrainingStats _training = TrainingStats.empty;
  List<FeedPost> _posts = [];
  List<Testimony> _testimonies = [];
  Person? _relation;

  bool _loading = true;
  bool _busyFollow = false;
  String? _error;
  _ProfileTab _tab = _ProfileTab.posts;

  bool get _isMe => widget.userId == Session.instance.userId;

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
      final user = await UserService.byId(widget.userId);
      final results = await Future.wait([
        UserService.summary(widget.userId).catchError((_) => HomeSummary.empty),
        FeedService.byUser(widget.userId).catchError((_) => <FeedPost>[]),
        SocialService.testimonies(widget.userId).catchError((_) => <Testimony>[]),
        UserService.trainingStats(widget.userId)
            .catchError((_) => TrainingStats.empty),
        if (!_isMe)
          SocialService.relationWith(widget.userId).catchError((_) => null),
      ]);

      if (!mounted) return;
      setState(() {
        _user = user;
        _summary = results[0] as HomeSummary;
        _posts = results[1] as List<FeedPost>;
        _testimonies = results[2] as List<Testimony>;
        _training = results[3] as TrainingStats;
        _relation = _isMe ? null : results.elementAtOrNull(4) as Person?;
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

  Future<void> _toggleFollow() async {
    if (_busyFollow) return;
    setState(() => _busyFollow = true);

    try {
      final relation = _relation;
      if (relation == null || relation.status == 'nenhum') {
        await SocialService.follow(widget.userId);
        if (mounted) showToast(context, 'Pedido enviado!');
      } else if (relation.isPendingReceived) {
        await SocialService.acceptFollow(relation);
        if (mounted) showToast(context, 'Agora vocês treinam juntos!');
      } else {
        await SocialService.unfollow(relation);
      }

      final updated = await SocialService.relationWith(widget.userId);
      if (mounted) setState(() => _relation = updated);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busyFollow = false);
    }
  }

  Future<void> _giveVibe(ProfileVibe vibe) async {
    try {
      await SocialService.giveVibe(toUserId: widget.userId, vibe: vibe);
      if (!mounted) return;
      showToast(context, '${vibe.emoji} ${vibe.label} enviado!');
      final summary = await UserService.summary(widget.userId);
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _writeTestimony() async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escrever depoimento'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 255,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Conte como é treinar com essa pessoa...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(context).pop(text);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(100, 42)),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );

    if (message == null) return;

    try {
      await SocialService.writeTestimony(
        profileUserId: widget.userId,
        message: message,
      );
      if (!mounted) return;
      showToast(context, 'Depoimento publicado!');
      final testimonies = await SocialService.testimonies(widget.userId);
      if (mounted) setState(() => _testimonies = testimonies);
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  Future<void> _likeTestimony(Testimony testimony) async {
    if (testimony.liked) return;
    setState(() {
      testimony.liked = true;
      testimony.likeCount += 1;
    });

    try {
      await SocialService.likeTestimony(testimony.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        testimony.liked = false;
        testimony.likeCount -= 1;
      });
      showToast(context, error.message, isError: true);
    }
  }

  Future<void> _toggleLike(FeedPost post) async {
    final wasLiked = post.liked;
    setState(() {
      post.liked = !wasLiked;
      post.likeCount += wasLiked ? -1 : 1;
      if (post.likeCount < 0) post.likeCount = 0;
    });

    try {
      if (wasLiked) {
        await FeedService.unlike(post.id);
      } else {
        await FeedService.like(post.id);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        post.liked = wasLiked;
        post.likeCount += wasLiked ? 1 : -1;
      });
      showToast(context, error.message, isError: true);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Você vai precisar entrar de novo depois.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: WorkutColors.danger),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true) await AuthService.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMe ? 'Meu perfil' : (_user?.firstName ?? 'Perfil')),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        actions: [
          if (_isMe) ...[
            IconButton(
              tooltip: 'Editar perfil',
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                if (changed == true) _load();
              },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Sair',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 6),
          ],
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

    final user = _user;
    if (user == null) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Perfil não encontrado',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _ProfileHeader(
          user: user,
          summary: _summary,
          isMe: _isMe,
          relation: _relation,
          busyFollow: _busyFollow,
          onFollow: _toggleFollow,
          onScrap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ScrapChatScreen(
                userId: user.id,
                userName: user.fullName,
                userAvatar: user.avatarUrl,
              ),
            ),
          ),
        ),
        if (_training.hasTraining) ...[
          const SizedBox(height: 16),
          _TrainingCard(stats: _training),
        ],
        const SizedBox(height: 16),
        _VibesCard(
          summary: _summary,
          canRate: !_isMe,
          onRate: _giveVibe,
        ),
        const SizedBox(height: 20),
        _TabSelector(
          current: _tab,
          postCount: _posts.length,
          testimonyCount: _testimonies.length,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: 16),
        if (_tab == _ProfileTab.posts) ..._buildPosts() else ..._buildTestimonies(),
      ],
    );
  }

  List<Widget> _buildPosts() {
    if (_posts.isEmpty) {
      return [
        EmptyState(
          icon: Icons.dynamic_feed_outlined,
          title: _isMe ? 'Você ainda não postou' : 'Sem publicações',
          message: _isMe
              ? 'Registre um treino e compartilhe o resumo no feed.'
              : 'Quando essa pessoa postar, aparece aqui.',
        ),
      ];
    }

    return [
      for (final post in _posts)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PostCard(
            post: post,
            onLike: () => _toggleLike(post),
            onComment: () async {
              final added = await showCommentsSheet(context, post);
              if (added > 0 && mounted) {
                setState(() => post.commentCount += added);
              }
            },
          ),
        ),
    ];
  }

  List<Widget> _buildTestimonies() {
    return [
      if (!_isMe)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: OutlinedButton.icon(
            onPressed: _writeTestimony,
            icon: const Icon(Icons.format_quote_rounded, size: 19),
            label: const Text('Escrever depoimento'),
          ),
        ),
      if (_testimonies.isEmpty)
        EmptyState(
          icon: Icons.format_quote_rounded,
          title: 'Nenhum depoimento ainda',
          message: _isMe
              ? 'Peça para a galera do treino escrever o primeiro.'
              : 'Seja o primeiro a deixar um depoimento.',
        )
      else
        for (final testimony in _testimonies)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TestimonyCard(
              testimony: testimony,
              onLike: () => _likeTestimony(testimony),
            ),
          ),
    ];
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.summary,
    required this.isMe,
    required this.relation,
    required this.busyFollow,
    required this.onFollow,
    required this.onScrap,
  });

  final AppUser user;
  final HomeSummary summary;
  final bool isMe;
  final Person? relation;
  final bool busyFollow;
  final VoidCallback onFollow;
  final VoidCallback onScrap;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 92,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [WorkutColors.ink, WorkutColors.brand],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Column(
              children: [
                WorkutAvatar(
                  url: user.photo,
                  name: user.fullName,
                  size: 84,
                  borderColor: Colors.white,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      Text(
                        user.fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          if (user.sports != null)
                            WorkutTag(
                              label: user.sports!,
                              icon: Icons.fitness_center_rounded,
                            ),
                          if (user.weight != null && user.weight! > 0)
                            WorkutTag(
                              label: Format.kg(user.weight!),
                              icon: Icons.monitor_weight_outlined,
                              color: WorkutColors.muted,
                              background: WorkutColors.background,
                            ),
                          if (user.height != null && user.height! > 0)
                            WorkutTag(
                              label: '${Format.weight(user.height!)} m',
                              icon: Icons.height_rounded,
                              color: WorkutColors.muted,
                              background: WorkutColors.background,
                            ),
                        ],
                      ),
                      if (user.aboutMe != null && user.aboutMe!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          user.aboutMe!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: WorkutColors.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${summary.friends}',
                        label: 'conexões',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${summary.fans}',
                        label: 'fãs',
                        color: WorkutColors.brand,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value: '${summary.testimonies}',
                        label: 'depoimentos',
                      ),
                    ),
                  ],
                ),
                if (!isMe) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: busyFollow
                              ? const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: WorkutColors.brand,
                                    ),
                                  ),
                                )
                              : _followButton(),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onScrap,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded,
                                size: 17),
                            label: const Text('Recado'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _followButton() {
    final status = relation?.status ?? 'nenhum';

    if (status == 'aceito') {
      return OutlinedButton.icon(
        onPressed: onFollow,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
        ),
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text('Seguindo'),
      );
    }

    if (status == 'solicitado') {
      return OutlinedButton(
        onPressed: onFollow,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          foregroundColor: WorkutColors.muted,
        ),
        child: const Text('Solicitado'),
      );
    }

    if (status == 'aguardando') {
      return FilledButton.icon(
        onPressed: onFollow,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          backgroundColor: WorkutColors.brand,
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text('Aceitar'),
      );
    }

    return FilledButton.icon(
      onPressed: onFollow,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: const Text('Seguir'),
    );
  }
}

/// Os "cores" do Orkut, repaginados para academia.
class _VibesCard extends StatelessWidget {
  const _VibesCard({
    required this.summary,
    required this.canRate,
    required this.onRate,
  });

  final HomeSummary summary;
  final bool canRate;
  final ValueChanged<ProfileVibe> onRate;

  double _valueOf(ProfileVibe vibe) => switch (vibe) {
        ProfileVibe.cool => summary.cool,
        ProfileVibe.trustworthy => summary.trustworthy,
        ProfileVibe.sexy => summary.sexy,
        ProfileVibe.happy => summary.happy,
        ProfileVibe.anxious => summary.anxious,
      };

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Vibes do perfil',
            subtitle: canRate
                ? 'Toque para dar um ponto — no melhor estilo Orkut'
                : 'O que a galera acha do seu treino',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final vibe in ProfileVibe.values)
                _VibeChip(
                  vibe: vibe,
                  value: _valueOf(vibe),
                  onTap: canRate ? () => onRate(vibe) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VibeChip extends StatelessWidget {
  const _VibeChip({required this.vibe, required this.value, this.onTap});

  final ProfileVibe vibe;
  final double value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: WorkutColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: WorkutColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(vibe.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            Text(
              vibe.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                color: WorkutColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({
    required this.current,
    required this.postCount,
    required this.testimonyCount,
    required this.onChanged,
  });

  final _ProfileTab current;
  final int postCount;
  final int testimonyCount;
  final ValueChanged<_ProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WorkutColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WorkutColors.line),
      ),
      child: Row(
        children: [
          _tab(
            label: 'Treinos e posts ($postCount)',
            selected: current == _ProfileTab.posts,
            onTap: () => onChanged(_ProfileTab.posts),
          ),
          _tab(
            label: 'Depoimentos ($testimonyCount)',
            selected: current == _ProfileTab.testimonies,
            onTap: () => onChanged(_ProfileTab.testimonies),
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? WorkutColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : WorkutColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _TestimonyCard extends StatelessWidget {
  const _TestimonyCard({required this.testimony, required this.onLike});

  final Testimony testimony;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WorkutAvatar(
                url: testimony.avatar,
                name: testimony.authorName ?? 'Atleta',
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testimony.authorName ?? 'Atleta Workut',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Format.timeAgo(testimony.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: WorkutColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.format_quote_rounded,
                  color: WorkutColors.brandSoft, size: 30),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            testimony.message,
            style: const TextStyle(fontSize: 14.5, height: 1.5),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: onLike,
                style: TextButton.styleFrom(
                  foregroundColor:
                      testimony.liked ? WorkutColors.brand : WorkutColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  testimony.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                ),
                label: Text(
                  testimony.likeCount > 0
                      ? '${testimony.likeCount}'
                      : 'Curtir',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Os números que interessam para quem treina: volume, frequência,
/// recordes e sequência de semanas.
class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.stats});

  final TrainingStats stats;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Treino',
            subtitle: stats.lastWorkout == null
                ? null
                : 'Último treino ${Format.timeAgo(stats.lastWorkout)}',
            padding: EdgeInsets.zero,
            action: stats.streakWeeks > 0
                ? WorkutTag(
                    label: stats.streakWeeks == 1
                        ? '1 semana'
                        : '${stats.streakWeeks} semanas',
                    icon: Icons.local_fire_department_rounded,
                    color: WorkutColors.brand,
                    background: WorkutColors.brandSoft,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _TrainingStat(
                value: Format.volume(stats.volumeLast7Days),
                label: 'volume 7 dias',
                highlight: true,
              ),
              _TrainingStat(
                value: '${stats.workoutsThisMonth}',
                label: 'treinos no mês',
              ),
              _TrainingStat(
                value: '${stats.personalRecords}',
                label: 'recordes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainingStat extends StatelessWidget {
  const _TrainingStat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

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
            style: TextStyle(
              fontSize: highlight ? 20 : 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: highlight ? WorkutColors.brand : WorkutColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: WorkutColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
