import 'package:flutter/material.dart';

import 'issue_category.dart';

/// Impacto potencial de um problema para um perfil de mobilidade.
enum ImpactLevel {
  high('Alto', Color(0xFFD32F2F)),
  medium('Médio', Color(0xFFF9A825)),
  low('Baixo', Color(0xFF558B2F));

  final String label;
  final Color color;
  const ImpactLevel(this.label, this.color);
}

/// Perfis de mobilidade (seção 10 do documento mestre).
enum MobilityProfile {
  wheelchair(
    'Cadeirante',
    Icons.accessible,
    'Rampas, largura livre, degraus e continuidade',
    {
      IssueCategory.acessibilidade: ImpactLevel.high,
      IssueCategory.desniveis: ImpactLevel.high,
      IssueCategory.bloqueios: ImpactLevel.high,
      IssueCategory.obstaculos: ImpactLevel.medium,
      IssueCategory.pavimentacao: ImpactLevel.medium,
    },
  ),
  pedestrian(
    'Pedestre',
    Icons.directions_walk,
    'Buracos, obstáculos e pavimentação',
    {
      IssueCategory.pavimentacao: ImpactLevel.high,
      IssueCategory.obstaculos: ImpactLevel.high,
      IssueCategory.bloqueios: ImpactLevel.medium,
      IssueCategory.desniveis: ImpactLevel.medium,
    },
  ),
  elderly(
    'Idoso',
    Icons.elderly,
    'Desníveis, irregularidades e travessias',
    {
      IssueCategory.desniveis: ImpactLevel.high,
      IssueCategory.pavimentacao: ImpactLevel.high,
      IssueCategory.acessibilidade: ImpactLevel.medium,
      IssueCategory.sinalizacao: ImpactLevel.medium,
      IssueCategory.obstaculos: ImpactLevel.medium,
      IssueCategory.bloqueios: ImpactLevel.medium,
    },
  ),
  visual(
    'Deficiência visual',
    Icons.visibility_off,
    'Obstáculos, piso tátil e sinalização',
    {
      IssueCategory.obstaculos: ImpactLevel.high,
      IssueCategory.sinalizacao: ImpactLevel.high,
      IssueCategory.bloqueios: ImpactLevel.high,
      IssueCategory.desniveis: ImpactLevel.medium,
      IssueCategory.pavimentacao: ImpactLevel.medium,
    },
  ),
  general(
    'Perfil geral',
    Icons.person,
    'Todas as categorias, sem destaque específico',
    {},
  );

  final String label;
  final IconData icon;
  final String priorities;
  final Map<IssueCategory, ImpactLevel> _impact;

  const MobilityProfile(this.label, this.icon, this.priorities, this._impact);

  /// Perfil geral trata todas as categorias com a mesma relevância (médio).
  ImpactLevel impactOf(IssueCategory c) =>
      this == general ? ImpactLevel.medium : (_impact[c] ?? ImpactLevel.low);

  static MobilityProfile fromName(String? n) => MobilityProfile.values
      .firstWhere((p) => p.name == n, orElse: () => MobilityProfile.general);
}
