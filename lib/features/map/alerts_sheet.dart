import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/app_state.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/relevance.dart';
import '../../models/mobility_profile.dart';
import '../../shared/widgets/impact_chip.dart';
import '../issue_details/issue_details_sheet.dart';

/// Resumo de alertas: problemas abertos de alto impacto para o perfil.
void showAlertsSheet(BuildContext context, Position? me) {
  final app = AppScope.of(context);
  final list = app.issues.issues
      .where((i) =>
          !i.resolved && app.profile.impactOf(i.category) == ImpactLevel.high)
      .toList()
    ..sort((a, b) =>
        priorityScore(b, app.profile).compareTo(priorityScore(a, app.profile)));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text('Alertas para ${app.profile.label}',
            style: Theme.of(ctx).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(me == null
            ? 'Ative a localização para ver as distâncias.'
            : 'Ordenados por prioridade para o seu perfil.'),
        const SizedBox(height: 4),
        const Text(
            'Ausência de registros não significa ausência de obstáculos.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nenhum alerta de alto impacto por aqui.')),
          ),
        for (final i in list)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: i.category.color,
                  child: Icon(i.category.icon, color: Colors.white, size: 20)),
              title: Text(i.description, maxLines: 2),
              subtitle: Text([
                i.category.label,
                if (me != null)
                  formatDistance(distanceMeters(
                      me.latitude, me.longitude, i.latitude, i.longitude)),
                '${i.confirmationCount} confirm.',
              ].join(' · ')),
              trailing: ImpactChip(level: app.profile.impactOf(i.category)),
              onTap: () {
                Navigator.pop(ctx);
                showIssueDetails(context, i.id);
              },
            ),
          ),
      ],
    ),
  );
}
