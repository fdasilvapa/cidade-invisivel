import 'package:flutter/material.dart';
import '../../core/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<_SentNotif> _history = [];
  int _notifId = 1;

  final _presets = const [
    _Preset(Icons.warning_amber, Colors.red, 'Buraco na via',
        'Buraco identificado na via pública — risco de acidentes.'),
    _Preset(Icons.lightbulb_outline, Colors.amber, 'Poste sem luz',
        'Poste de iluminação apagado na sua região.'),
    _Preset(Icons.accessibility_new, Colors.blue, 'Calçada danificada',
        'Calçada com obstáculo ou irregularidade reportada.'),
    _Preset(Icons.delete_outline, Colors.brown, 'Lixo acumulado',
        'Acúmulo de lixo ou entulho na via pública.'),
    _Preset(Icons.water_drop_outlined, Colors.teal, 'Vazamento de água',
        'Vazamento de água identificado na rua.'),
  ];

  Future<void> _send(_Preset preset) async {
    await NotificationService.show(
      context,
      id: _notifId++,
      title: preset.title,
      body: preset.body,
    );
    if (!mounted) return;

    setState(() {
      _history.insert(
          0,
          _SentNotif(
            title: preset.title,
            sentAt: DateTime.now(),
            icon: preset.icon,
            color: preset.color,
          ));
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notificação enviada: ${preset.title}'),
          backgroundColor: preset.color,
        ),
      );
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    return 'há ${diff.inDays} dias';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Reportar problema',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._presets.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: p.color.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Icon(p.icon, color: p.color),
                  title: Text(p.title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.body,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.send),
                  onTap: () => _send(p),
                ),
              )),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Histórico',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._history.map((h) => ListTile(
                  leading: Icon(h.icon, color: h.color),
                  title: Text(h.title),
                  subtitle: Text(_timeAgo(h.sentAt)),
                )),
          ],
        ],
      ),
    );
  }
}

class _Preset {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _Preset(this.icon, this.color, this.title, this.body);
}

class _SentNotif {
  final String title;
  final DateTime sentAt;
  final IconData icon;
  final Color color;

  _SentNotif(
      {required this.title,
      required this.sentAt,
      required this.icon,
      required this.color});
}
