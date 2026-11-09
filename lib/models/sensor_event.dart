class SensorEvent {
  final DateTime at;
  final double intensity;
  final double? latitude;
  final double? longitude;

  /// Já existe problema registrado próximo a este ponto?
  final bool nearKnownIssue;

  const SensorEvent({
    required this.at,
    required this.intensity,
    this.latitude,
    this.longitude,
    this.nearKnownIssue = false,
  });

  bool get hasLocation => latitude != null && longitude != null;
}
