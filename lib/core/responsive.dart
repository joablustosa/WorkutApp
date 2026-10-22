import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Larguras de tela do Workut.
///
/// O app nasceu no celular, então `compact` é o desenho original: navegação
/// embaixo e conteúdo ocupando tudo. `medium` (tablet, celular na horizontal,
/// janela estreita) troca a barra de baixo por um trilho lateral de ícones.
/// `expanded` (notebook, monitor) abre o trilho com rótulos e centraliza o
/// conteúdo numa coluna de leitura — é o que evita o feed esticado de ponta a
/// ponta num monitor de 27".
enum WorkutBreakpoint { compact, medium, expanded }

class WorkutLayout {
  const WorkutLayout._();

  /// Abaixo disso a navegação vive embaixo (celular em pé).
  static const double compactMax = 700;

  /// Daqui para cima o trilho lateral abre com rótulos.
  static const double expandedMin = 1100;

  /// Coluna de leitura: feed, perfil, listas. Mesma medida do `.workut-shell`
  /// do workutFront, para o site e o app ficarem com o mesmo ritmo.
  static const double contentMax = 820;

  /// Formulários (login, cadastro, composer) pedem coluna mais estreita.
  static const double formMax = 460;

  static WorkutBreakpoint of(double width) {
    if (width < compactMax) return WorkutBreakpoint.compact;
    if (width < expandedMin) return WorkutBreakpoint.medium;
    return WorkutBreakpoint.expanded;
  }
}

extension WorkutResponsiveContext on BuildContext {
  WorkutBreakpoint get breakpoint =>
      WorkutLayout.of(MediaQuery.sizeOf(this).width);

  /// `true` no desenho original de celular (navegação embaixo).
  bool get isCompact => breakpoint == WorkutBreakpoint.compact;

  /// `true` quando há espaço para trilho lateral (tablet e desktop).
  bool get isWide => breakpoint != WorkutBreakpoint.compact;

  bool get isExpanded => breakpoint == WorkutBreakpoint.expanded;

  /// Web rodando em tela grande: sem câmera nativa, com mouse e teclado.
  bool get isDesktopWeb => kIsWeb && isWide;
}

/// Centraliza o conteúdo numa coluna de largura máxima.
///
/// No celular é transparente (devolve o filho como está); em telas largas
/// segura a largura para o texto não virar uma linha de 1600px.
class AppColumn extends StatelessWidget {
  const AppColumn({
    super.key,
    required this.child,
    this.maxWidth = WorkutLayout.contentMax,
    this.alignment = Alignment.topCenter,
  });

  const AppColumn.form({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  }) : maxWidth = WorkutLayout.formMax;

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Deixa arrastar com o mouse (e com o dedo) qualquer área rolável.
///
/// No web o padrão do Flutter só rola com a roda do mouse; carrosséis e
/// listas horizontais ficavam travados para quem usa trackpad ou arrasta.
class WorkutScrollBehavior extends MaterialScrollBehavior {
  const WorkutScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
