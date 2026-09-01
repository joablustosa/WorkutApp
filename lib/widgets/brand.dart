import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Marca do Workut: halter vermelho + wordmark, o mesmo desenho do logo
/// oficial e da classe `.workut-logo` do workutFront.
class WorkutLogo extends StatelessWidget {
  const WorkutLogo({
    super.key,
    this.size = 30,
    this.onDark = false,
  });

  /// Altura do selo do halter. O wordmark acompanha proporcionalmente.
  final double size;

  /// Em fundo escuro o selo fica translucido e o texto branco.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onDark
                ? Colors.white.withValues(alpha: 0.16)
                : WorkutColors.brand,
            borderRadius: BorderRadius.circular(size * 0.32),
          ),
          child: Icon(
            Icons.fitness_center_rounded,
            size: size * 0.58,
            color: Colors.white,
          ),
        ),
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
          const WorkutLogo(size: 34, onDark: true),
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
