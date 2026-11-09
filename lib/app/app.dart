import 'package:flutter/material.dart';

import '../core/services/app_state.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/shell/main_shell.dart';
import 'routes.dart';
import 'theme/app_theme.dart';

class CidadeInvisivelApp extends StatefulWidget {
  /// Estado injetável para testes.
  final AppState? state;
  const CidadeInvisivelApp({super.key, this.state});

  @override
  State<CidadeInvisivelApp> createState() => _CidadeInvisivelAppState();
}

class _CidadeInvisivelAppState extends State<CidadeInvisivelApp> {
  late final AppState _state = widget.state ?? AppState();
  late final Future<void> _loading = widget.state != null
      ? Future.value()
      : _state.load();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'Cidade Invisível',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        routes: AppRoutes.routes,
        home: FutureBuilder<void>(
          future: _loading,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            return ListenableBuilder(
              listenable: _state,
              builder: (_, _) => _state.onboarded
                  ? const MainShell()
                  : const OnboardingPage(),
            );
          },
        ),
      ),
    );
  }
}
