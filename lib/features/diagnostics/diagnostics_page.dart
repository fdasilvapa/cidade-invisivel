import 'package:flutter/material.dart';

import '../../app/routes.dart';

/// Telas de teste dos recursos nativos (câmera, GPS, sensores, notificações).
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.photo_camera, 'Câmera', 'Testar captura de foto', AppRoutes.camera),
      (Icons.my_location, 'Localização GPS', 'Ver latitude e longitude',
          AppRoutes.location),
      (Icons.sensors, 'Acelerômetro', 'Ver leituras em tempo real',
          AppRoutes.sensors),
      (Icons.notifications_active, 'Notificações', 'Enviar alerta de teste',
          AppRoutes.notifications),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico de recursos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Use estas telas para verificar se cada recurso do aparelho está funcionando.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (final i in items) ...[
            Card(
              child: ListTile(
                leading: Icon(i.$1),
                title: Text(i.$2),
                subtitle: Text(i.$3),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, i.$4),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
