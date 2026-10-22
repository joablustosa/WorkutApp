import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/theme.dart';
import 'brand.dart';

/// Moldura das telas de entrada (login e cadastro).
///
/// No celular é o desenho original: faixa de marca em cima, formulário
/// embaixo. Em tela larga vira duas colunas — marca à esquerda ocupando a
/// altura toda, formulário à direita numa coluna estreita —, que é o mesmo
/// `.auth-page` / `.auth-brand` / `.auth-form` do workutFront.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onClose,
    this.footer,
  });

  final String title;
  final String subtitle;

  /// O formulário.
  final Widget child;

  /// Botão de fechar, quando a tela foi empilhada (cadastro).
  final VoidCallback? onClose;

  /// Conteúdo extra: no celular fica abaixo do formulário, em tela larga
  /// desce para o painel de marca.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  BrandHeader(title: title, subtitle: subtitle),
                  if (onClose != null)
                    Positioned(
                      top: 44,
                      right: 12,
                      child: IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    child,
                    if (footer != null) ...[
                      const SizedBox(height: 28),
                      footer!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: WorkutColors.surface,
      body: Row(
        // Sem isto o painel de marca fica do tamanho do texto, flutuando no
        // meio da tela em vez de ocupar a altura toda.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _BrandPanel(
              title: title,
              subtitle: subtitle,
              footer: footer,
            ),
          ),
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 48,
                    ),
                    child: AppColumn.form(
                      alignment: Alignment.center,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [child],
                      ),
                    ),
                  ),
                ),
                if (onClose != null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
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

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({
    required this.title,
    required this.subtitle,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WorkutColors.ink, WorkutColors.brand],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(48, 48, 48, 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WorkutLogo(size: 44, onDark: true),
                const SizedBox(height: 40),
                Text(
                  title.replaceAll('\n', ' '),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.1,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 40),
                  DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white),
                    child: IconTheme.merge(
                      data: const IconThemeData(color: Colors.white),
                      child: footer!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
