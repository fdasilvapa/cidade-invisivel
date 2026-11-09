import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/services/app_state.dart';
import '../../shared/widgets/profile_picker.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _editName(BuildContext context, AppState app) async {
    final c = TextEditingController(text: app.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome de exibição'),
        content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(hintText: 'Como quer ser chamado?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (name != null) app.setName(name);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListenableBuilder(
        listenable: Listenable.merge([app, app.issues]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: cs.primaryContainer,
                    child: Icon(app.profile.icon, color: cs.onPrimaryContainer)),
                title: Text(
                    app.displayName.isEmpty ? 'Visitante' : app.displayName),
                subtitle: const Text('Conta e login chegam em breve'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editName(context, app),
              ),
            ),
            const SizedBox(height: 24),
            Text('Perfil de mobilidade', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('Muda a prioridade visual dos problemas, sem esconder nenhum.',
                style: text.bodySmall),
            const SizedBox(height: 12),
            ProfilePicker(selected: app.profile, onChanged: app.setProfile),
            const SizedBox(height: 16),
            Text('Notificações', style: text.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Problemas próximos'),
              subtitle: const Text('Alertas de alto impacto para o seu perfil'),
              value: app.notifyNearby,
              onChanged: (v) => app.setNotify(nearby: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Atualizações dos meus registros'),
              value: app.notifyUpdates,
              onChanged: (v) => app.setNotify(updates: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pedidos de verificação'),
              subtitle: const Text('Quando a observação por sensores sugerir conferir um trecho'),
              value: app.notifyVerification,
              onChanged: (v) => app.setNotify(verification: v),
            ),
            const SizedBox(height: 16),
            Text('Privacidade', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
                'A localização só é usada quando você abre o mapa, registra um problema ou liga uma sessão de observação. '
                'O mapa mostra onde está o problema, nunca quem registrou nem por onde você andou.',
                style: text.bodySmall),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.build_circle_outlined),
                title: const Text('Diagnóstico de recursos'),
                subtitle: const Text('Testar câmera, GPS, sensores e notificações'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, AppRoutes.diagnostics),
              ),
            ),
            if (app.issues.hasDemo) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Remover registros de exemplo'),
                  subtitle: const Text('Apaga os problemas de demonstração do mapa'),
                  onTap: () => app.issues.removeDemo(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
