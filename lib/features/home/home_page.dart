import 'package:flutter/material.dart';

/// Tela inicial provisória. Cada card será ligado à sua feature
/// (camera, location, sensors, notifications) pelo respectivo responsável.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.photo_camera, 'Câmera', 'Fotografar um problema urbano'),
      (Icons.my_location, 'Localização', 'Obter latitude e longitude'),
      (Icons.sensors, 'Sensores', 'Acelerômetro em tempo real'),
      (Icons.notifications, 'Notificações', 'Alertas de problemas próximos'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cidade Invisível')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (icon, title, subtitle) in items)
            Card(
              child: ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
        ],
      ),
    );
  }
}
