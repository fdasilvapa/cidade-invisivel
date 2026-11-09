import 'package:flutter/material.dart';

import '../../app/routes.dart';

/// Tela inicial provisória: um card por recurso nativo.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureItem(
        icon: Icons.photo_camera,
        color: Colors.blue,
        title: 'Câmera',
        subtitle: 'Fotografar um problema urbano',
        route: AppRoutes.camera,
      ),
      _FeatureItem(
        icon: Icons.my_location,
        color: Colors.green,
        title: 'Localização GPS',
        subtitle: 'Obter latitude e longitude',
        route: AppRoutes.location,
      ),
      _FeatureItem(
        icon: Icons.sensors,
        color: Colors.orange,
        title: 'Acelerômetro',
        subtitle: 'Sensores em tempo real',
        route: AppRoutes.sensors,
      ),
      _FeatureItem(
        icon: Icons.notifications_active,
        color: Colors.purple,
        title: 'Notificações',
        subtitle: 'Alertas de problemas urbanos',
        route: AppRoutes.notifications,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cidade Invisível'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: features.map((f) => _FeatureCard(item: f)).toList(),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;

  const _FeatureItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;

  const _FeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, item.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 36, color: item.color),
              ),
              const SizedBox(height: 12),
              Text(item.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(item.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
