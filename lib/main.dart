import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/session.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await Session.instance.load();
  runApp(const WorkutApp());
}

class WorkutApp extends StatelessWidget {
  const WorkutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workut',
      debugShowCheckedModeBanner: false,
      theme: WorkutTheme.build(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

/// Decide entre login e app logado, reagindo a mudanças da sessão
/// (inclusive o logout automático quando a API devolve 401).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Session.instance,
      builder: (context, _) {
        return Session.instance.isLoggedIn
            ? const HomeShell()
            : const LoginScreen();
      },
    );
  }
}
