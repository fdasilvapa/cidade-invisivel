import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme/app_theme.dart';

class CidadeInvisivelApp extends StatelessWidget {
  const CidadeInvisivelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cidade Invisível',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}
