import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/feed.dart';
import '../services/feed_service.dart';
import '../services/social_service.dart';
import '../widgets/brand.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import 'people_screen.dart';
import 'post_composer_screen.dart';
import 'profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<FeedPost> _posts = [];
  bool _loading = true;
  String? _error;
  int _pendingRequests = 0;

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
      final posts = await FeedService.feed(Session.instance.userId);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
      _loadPendingRequests();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final pending = await SocialService.pendingRequests();
      if (mounted) setState(() => _pendingRequests = pending.length);
    } catch (_) {
      // Contador de pedidos é enfeite: falhar aqui não quebra o feed.
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

  Future<void> _openComments(FeedPost post) async {
    final added = await showCommentsSheet(context, post);
    if (added > 0 && mounted) {
      setState(() => post.commentCount += added);
    }
  }

  Future<void> _openComposer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostComposerScreen()),
    );
    if (created == true) _load();
  }

  void _openProfile(int userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  Future<void> _confirmDelete(FeedPost post) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: WorkutColors.danger),
              title: const Text('Apagar publicação'),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Cancelar'),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await FeedService.delete(post.id);
      if (!mounted) return;
      setState(() => _posts.remove(post));
      showToast(context, 'Publicação apagada');
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.user;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const WorkutLogo(size: 26),
        actions: [
          IconButton(
            tooltip: 'Pedidos para seguir',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PeopleScreen(showPendingFirst: true),
                ),
              );
              _loadPendingRequests();
            },
            icon: Badge(
              isLabelVisible: _pendingRequests > 0,
              label: Text('$_pendingRequests'),
              backgroundColor: WorkutColors.brand,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        backgroundColor: WorkutColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Publicar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: WorkutColors.brand,
        child: _buildBody(me?.fullName ?? 'Atleta', me?.avatarUrl),
      ),
    );
  }

  Widget _buildBody(String myName, String? myAvatar) {
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _posts.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ComposerPrompt(
            name: myName,
            avatar: myAvatar,
            onTap: _openComposer,
          );
        }

        final post = _posts[index - 1];
        return PostCard(
          post: post,
          onLike: () => _toggleLike(post),
          onComment: () => _openComments(post),
          onOpenProfile: () => _openProfile(post.userId),
          onDelete: post.userId == Session.instance.userId
              ? () => _confirmDelete(post)
              : null,
        );
      },
    );
  }
}

class _ComposerPrompt extends StatelessWidget {
  const _ComposerPrompt({
    required this.name,
    required this.avatar,
    required this.onTap,
  });

  final String name;
  final String? avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          WorkutAvatar(url: avatar, name: name, size: 40),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Como foi o treino de hoje?',
              style: TextStyle(fontSize: 14.5, color: WorkutColors.muted),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WorkutColors.brandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 18,
              color: WorkutColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}
