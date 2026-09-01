import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../models/social.dart';
import '../services/social_service.dart';
import '../widgets/common.dart';

/// Recados — a caixinha de scraps do perfil, agora em formato de conversa.
class ScrapChatScreen extends StatefulWidget {
  const ScrapChatScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  final int userId;
  final String userName;
  final String? userAvatar;

  @override
  State<ScrapChatScreen> createState() => _ScrapChatScreenState();
}

class _ScrapChatScreenState extends State<ScrapChatScreen> {
  final _controller = TextEditingController();
  List<Scrap> _scraps = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final scraps = await SocialService.scrapThread(widget.userId);
      if (!mounted) return;
      setState(() {
        _scraps = scraps;
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await SocialService.sendScrap(toUserId: widget.userId, message: text);
      _controller.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            WorkutAvatar(
              url: widget.userAvatar,
              name: widget.userName,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildList()),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Deixe um recado...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: WorkutColors.brand,
                      minimumSize: const Size(46, 46),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            size: 19, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: WorkutColors.brand),
      );
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_scraps.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Nenhum recado ainda',
        message: 'Mande o primeiro recado para ${widget.userName.split(' ').first}.',
      );
    }

    final myId = Session.instance.userId;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _scraps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final scrap = _scraps[index];
        final isMine = scrap.senderId == myId;

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: isMine ? WorkutColors.brand : WorkutColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              border: Border.all(
                color: isMine ? WorkutColors.brand : WorkutColors.line,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scrap.message,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: isMine ? Colors.white : WorkutColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Format.timeAgo(scrap.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.8)
                        : WorkutColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
