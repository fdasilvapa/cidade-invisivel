/// Leitura de movimento unificada (nativo e web).
class MotionSample {
  /// Acelerômetro com gravidade (m/s²), como no exemplo da aula.
  final double x, y, z;

  /// Aceleração do usuário, sem gravidade (m/s²).
  final double ux, uy, uz;

  /// Velocidade angular total do giroscópio (rad/s).
  final double rotation;

  const MotionSample({
    required this.x,
    required this.y,
    required this.z,
    required this.ux,
    required this.uy,
    required this.uz,
    required this.rotation,
  });
}
