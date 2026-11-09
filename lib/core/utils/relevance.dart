import '../../models/mobility_profile.dart';
import '../../models/urban_issue.dart';

/// Pontuação de prioridade visual (perfil × gravidade, com decaimento por
/// idade quando não há confirmações recentes — RB08 e RB13).
double priorityScore(UrbanIssue i, MobilityProfile p) {
  final impact = switch (p.impactOf(i.category)) {
    ImpactLevel.high => 3.0,
    ImpactLevel.medium => 2.0,
    ImpactLevel.low => 1.0,
  };
  final sev = i.severity.index + 1;
  final ageDays = DateTime.now().difference(i.lastConfirmedAt).inDays;
  final decay = ageDays <= 30 ? 1.0 : (ageDays <= 90 ? 0.7 : 0.4);
  return impact * sev * decay;
}
