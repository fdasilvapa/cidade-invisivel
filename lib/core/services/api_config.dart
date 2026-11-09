import 'package:flutter/foundation.dart' show kIsWeb;

/// Endereço do servidor local (server/server.py).
///
/// - Web servida pelo próprio servidor (ngrok/localhost): usa a mesma origem.
/// - Outros casos: `--dart-define=API_URL=http://host:porta`.
///   No emulador Android o PC é `http://10.0.2.2:8080`.
class ApiConfig {
  static const _override = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return Uri.base.origin;
    return 'http://10.0.2.2:8080';
  }

  static String resolve(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path';
}
