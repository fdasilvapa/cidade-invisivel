import 'package:flutter/widgets.dart';

import '../features/home/home_page.dart';

class AppRoutes {
  static const home = '/';

  static final Map<String, WidgetBuilder> routes = {
    home: (_) => const HomePage(),
  };
}
