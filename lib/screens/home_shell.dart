import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/brand.dart';
import 'feed_screen.dart';
import 'people_screen.dart';
import 'profile_screen.dart';
import 'ranking_screen.dart';
import 'workouts_screen.dart';

/// As cinco abas do Workut, na mesma ordem em celular, tablet e desktop.
class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Tab> _tabs = [
  _Tab('Feed', Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded),
  _Tab('Treinos', Icons.fitness_center_outlined, Icons.fitness_center_rounded),
  _Tab('Pessoas', Icons.group_outlined, Icons.group_rounded),
  _Tab('Ranking', Icons.emoji_events_outlined, Icons.emoji_events_rounded),
  _Tab('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Nomes usados em `?tab=` — é por aqui que os atalhos do PWA (os que o
/// Android mostra ao segurar o ícone) abrem direto na aba certa.
const List<String> _tabSlugs = [
  'feed',
  'treinos',
  'pessoas',
  'ranking',
  'perfil',
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _feedRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    // No web a URL pode pedir uma aba (`/?tab=ranking`); fora do web
    // `Uri.base` não tem query e o app abre no Feed, como sempre.
    final slug = Uri.base.queryParameters['tab']?.toLowerCase();
    final requested = slug == null ? -1 : _tabSlugs.indexOf(slug);
    if (requested >= 0) _index = requested;
  }

  void _select(int value) {
    setState(() {
      // Ao voltar para o Feed, recarrega posts de quem você segue.
      if (value == 0 && _index != 0) {
        _feedRefreshToken++;
      }
      _index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.user;

    final pages = <Widget>[
      FeedScreen(refreshToken: _feedRefreshToken),
      const WorkoutsScreen(),
      const PeopleScreen(),
      const RankingScreen(),
      ProfileScreen(userId: me?.id ?? 0),
    ];

    // No celular o conteúdo ocupa tudo; em tela larga vira coluna centrada
    // para o feed não esticar de ponta a ponta no monitor.
    final body = IndexedStack(index: _index, children: pages);
    final content = context.isCompact
        ? body
        : AppColumn(
            child: DecoratedBox(
              // Fios laterais: sem eles a coluna some no fundo e a tela larga
              // fica parecendo um app de celular perdido no meio do monitor.
              position: DecorationPosition.foreground,
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: WorkutColors.line),
                ),
              ),
              child: body,
            ),
          );

    if (context.isCompact) {
      return Scaffold(
        body: content,
        bottomNavigationBar: _BottomNav(index: _index, onSelect: _select),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _SideNav(
            index: _index,
            onSelect: _select,
            extended: context.isExpanded,
          ),
          const VerticalDivider(width: 1, color: WorkutColors.line),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: WorkutColors.line)),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        backgroundColor: WorkutColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: WorkutColors.brandSoft,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

/// Trilho lateral de tablet e desktop: ícones em tela média, ícones com
/// rótulo e a marca no topo em tela grande.
class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.index,
    required this.onSelect,
    required this.extended,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onSelect,
      extended: extended,
      backgroundColor: WorkutColors.surface,
      indicatorColor: WorkutColors.brandSoft,
      minWidth: 76,
      minExtendedWidth: 212,
      labelType:
          extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      leading: Padding(
        padding: EdgeInsets.only(
          top: 20,
          bottom: 16,
          left: extended ? 4 : 0,
          right: extended ? 4 : 0,
        ),
        child: WorkutLogo(size: 30, showWordmark: extended),
      ),
      selectedLabelTextStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: WorkutColors.brand,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: WorkutColors.muted,
      ),
      selectedIconTheme: const IconThemeData(color: WorkutColors.brand),
      unselectedIconTheme: const IconThemeData(color: WorkutColors.muted),
      destinations: [
        for (final tab in _tabs)
          NavigationRailDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: Text(tab.label),
          ),
      ],
    );
  }
}
