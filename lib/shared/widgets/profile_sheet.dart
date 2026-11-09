import 'package:flutter/material.dart';

import '../../core/services/app_state.dart';
import '../../models/mobility_profile.dart';

/// Seletor rápido da "Visão por perspectiva".
void showProfileSheet(BuildContext context) {
  final app = AppScope.of(context);
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text('Visão por perspectiva',
              style: Theme.of(ctx).textTheme.titleLarge),
          const Text(
              'Destaca o que mais importa para você. Nenhum problema é escondido.'),
          const SizedBox(height: 8),
          for (final p in MobilityProfile.values)
            ListTile(
              leading: Icon(p.icon),
              title: Text(p.label),
              subtitle: Text(p.priorities),
              trailing: p == app.profile ? const Icon(Icons.check) : null,
              onTap: () {
                app.setProfile(p);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    ),
  );
}
