import 'package:geolocator/geolocator.dart';

class LocationFailure implements Exception {
  final String message;
  const LocationFailure(this.message);
  @override
  String toString() => message;
}

/// Localização pedida somente quando uma ação depende dela (seção 8.2).
class LocationService {
  LocationService._();

  /// Tempo máximo total (inclui a espera pela resposta ao pedido de permissão).
  static Future<Position> current() => _current().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const LocationFailure(
            'A localização demorou demais. Confira se você permitiu o acesso.'),
      );

  static Future<Position> _current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure('O GPS do aparelho está desligado.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const LocationFailure('Permissão de localização negada.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationFailure(
          'Permissão bloqueada. Libere a localização nas configurações do aparelho.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 20),
        onTimeout: () =>
            throw const LocationFailure('Não foi possível obter o GPS a tempo.'));
  }
}
