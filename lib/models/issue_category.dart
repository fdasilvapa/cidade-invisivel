import 'package:flutter/material.dart';

/// Categorias iniciais do mapa (seção 7.4).
enum IssueCategory {
  pavimentacao('Pavimentação', 'Buracos e calçadas quebradas', Icons.construction,
      Color(0xFFE65100)),
  acessibilidade('Acessibilidade', 'Rampas danificadas', Icons.accessible_forward,
      Color(0xFF1565C0)),
  obstaculos('Obstáculos', 'Postes, entulho e objetos', Icons.block,
      Color(0xFF6A1B9A)),
  sinalizacao('Sinalização', 'Ausência de piso tátil', Icons.grid_on,
      Color(0xFF00838F)),
  desniveis('Desníveis', 'Degraus e irregularidades', Icons.stairs,
      Color(0xFF4E342E)),
  bloqueios('Bloqueios', 'Passagens totalmente obstruídas', Icons.do_not_disturb_on,
      Color(0xFFC62828));

  final String label;
  final String examples;
  final IconData icon;
  final Color color;
  const IssueCategory(this.label, this.examples, this.icon, this.color);

  static IssueCategory fromName(String? n) => IssueCategory.values
      .firstWhere((c) => c.name == n, orElse: () => IssueCategory.obstaculos);
}

enum Severity {
  low('Leve'),
  medium('Moderada'),
  high('Grave');

  final String label;
  const Severity(this.label);

  static Severity fromName(String? n) => Severity.values
      .firstWhere((s) => s.name == n, orElse: () => Severity.medium);
}
