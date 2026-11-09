import 'package:flutter/widgets.dart';

import '../features/camera/camera_page.dart';
import '../features/diagnostics/diagnostics_page.dart';
import '../features/home/home_page.dart';
import '../features/location/location_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/sensors/sensors_page.dart';

class AppRoutes {
  static const home = '/';
  static const camera = '/camera';
  static const location = '/location';
  static const notifications = '/notifications';
  static const sensors = '/sensors';
  static const diagnostics = '/diagnostics';

  static final Map<String, WidgetBuilder> routes = {
    home: (_) => const HomePage(),
    camera: (_) => const CameraPage(),
    location: (_) => const LocationPage(),
    notifications: (_) => const NotificationsPage(),
    sensors: (_) => const SensorsPage(),
    diagnostics: (_) => const DiagnosticsPage(),
  };
}
