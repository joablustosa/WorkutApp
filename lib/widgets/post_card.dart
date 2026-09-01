import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/feed.dart';
import 'common.dart';

/// Cartão de post do feed: autor, conteúdo, foto e as ações sociais.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    this.onOpenProfile,
    this.onDelete,
  });

  final FeedPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return WorkutCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onOpenProfile,
                child: WorkutAvatar(
                  url: post.avatar,
                  name: post.authorName,
                  size: 44,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onOpenProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Format.timeAgo(post.createdAt),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: WorkutColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (post.isWorkout)
                const WorkutTag(
                  label: 'Treino',
                  icon: Icons.fitness_center_rounded,
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: WorkutColors.muted,
                  ),
                ),
            ],
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.content,
              style: const TextStyle(fontSize: 15, height: 1.45),
            ),
          ],
          if (post.workout != null && post.workout!.hasNumbers) ...[
            const SizedBox(height: 12),
            WorkoutSummaryBlock(workout: post.workout!),
          ],
          if (post.image != null && post.image!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                post.image!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Divider(height: 18),
          Row(
            children: [
              _ActionButton(
                icon: post.liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: post.likeCount > 0 ? '${post.likeCount}' : 'Curtir',
                color: post.liked ? WorkutColors.brand : WorkutColors.muted,
                onTap: onLike,
              ),
              const SizedBox(width: 4),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: post.commentCount > 0
                    ? '${post.commentCount}'
                    : 'Comentar',
                color: WorkutColors.muted,
                onTap: onComment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// O card de treino do feed: os números da sessão, não texto solto.
/// É o que faz o seguidor entender o treino em um relance.
class WorkoutSummaryBlock extends StatelessWidget {
  const WorkoutSummaryBlock({super.key, required this.workout});

  final WorkoutPostSummary workout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4F4), Color(0xFFF4F6F9)],
        ),
        border: Border.all(color: WorkutColors.brandSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: WorkutColors.brand,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  workout.name ?? 'Treino concluído',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (workout.prCount > 0)
                WorkutTag(
                  label: workout.prCount == 1
                      ? '1 PR'
                      : '${workout.prCount} PRs',
                  icon: Icons.emoji_events_rounded,
                  color: WorkutColors.gold,
                  background: WorkutColors.goldSoft,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _WorkoutMetric(
                value: Format.volume(workout.volume),
                label: 'volume',
                highlight: true,
              ),
              _WorkoutMetric(value: '${workout.sets}', label: 'séries'),
              _WorkoutMetric(
                value: '${workout.exercises}',
                label: 'exercícios',
              ),
              if (workout.durationMinutes > 0)
                _WorkoutMetric(
                  value: '${workout.durationMinutes} min',
                  label: 'duração',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutMetric extends StatelessWidget {
  const _WorkoutMetric({
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
              fontSize: highlight ? 18 : 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: highlight ? WorkutColors.brand : WorkutColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: Icon(icon, size: 19, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
