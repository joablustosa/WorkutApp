import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Marca do Workut: logo oficial + wordmark.
class WorkutLogo extends StatelessWidget {
  const WorkutLogo({
    super.key,
    this.size = 30,
    this.onDark = false,
    this.showWordmark = true,
  });

  /// Altura do selo da logo. O wordmark acompanha proporcionalmente.
  final double size;

  /// Em fundo escuro o texto fica branco.
  final bool onDark;

  /// Exibe o texto "WORKUT" ao lado da logo.
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.5),
          child: Image.asset(
            'assets/icon_launcher.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        if (showWordmark) ...[
          SizedBox(width: size * 0.28),
          Text(
            'WORKUT',
            style: TextStyle(
              fontSize: size * 0.72,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: onDark ? Colors.white : WorkutColors.ink,
            ),
          ),
        ],
      ],
    );
  }
}

/// Faixa superior das telas de entrada - o mesmo painel de marca do
/// `.auth-brand` no front.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WorkutColors.ink, WorkutColors.brand],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkutLogo(size: 40, onDark: true),
          const SizedBox(height: 22),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
