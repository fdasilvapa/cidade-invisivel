import 'package:flutter/material.dart';

import '../../core/services/app_state.dart';
import '../../core/utils/geo.dart';
import '../../core/utils/relevance.dart';
import '../../shared/widgets/impact_chip.dart';
import '../../shared/widgets/profile_sheet.dart';
import '../issue_details/issue_details_sheet.dart';
import '../issue_reporting/report_page.dart';

/// Tela de início: saudação, ação principal, atalhos e destaques do perfil.
class HomePage extends StatelessWidget {
  /// Troca a aba do shell (0 início, 1 mapa, 2 observar, 3 contribuições, 4 perfil).
  final ValueChanged<int> onNavigate;
  const HomePage({super.key, required this.onNavigate});

  static const _tips = [
    'Fotografe o problema de frente e de perto: isso ajuda a comunidade a reconhecê-lo.',
    'Confirmar um registro existente vale tanto quanto criar um novo.',
    'Evite fotografar rostos e placas de carros. Cuidamos da privacidade de todos.',
    'Ligue a observação de trajeto ao caminhar: impactos viram pistas de onde olhar.',
  ];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.issues]),
      builder: (context, _) {
        final repo = app.issues;
        final open = repo.issues.where((i) => !i.resolved).toList()
          ..sort((a, b) => priorityScore(b, app.profile)
              .compareTo(priorityScore(a, app.profile)));
        final top = open.take(3).toList();
        final confirmed = repo.issues.where((i) => i.communityConfirmed).length;
        final resolved = repo.issues.where((i) => i.resolved).length;
        final tip = _tips[DateTime.now().day % _tips.length];

        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(app: app),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -28),
                      child: _ReportCta(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReportPage())),
                      ),
                    ),
                    if (!repo.online)
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: const ListTile(
                            leading: Icon(Icons.cloud_off),
                            title: Text('Sem conexão com o servidor'),
                            subtitle: Text(
                                'Mostrando os últimos dados salvos. Tentando reconectar…'),
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: const Offset(0, -12),
                      child: _QuickActions(onNavigate: onNavigate),
                    ),
                    const SizedBox(height: 8),
                    _SectionTitle(
                      title: 'Em destaque para ${app.profile.label}',
                      action: 'Ver mapa',
                      onAction: () => onNavigate(1),
                    ),
                    const SizedBox(height: 8),
                    if (top.isEmpty)
                      _EmptyHighlights(onOpenMap: () => onNavigate(1))
                    else
                      for (final i in top)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              leading: CircleAvatar(
                                  backgroundColor: i.category.color,
                                  child: Icon(i.category.icon,
                                      color: Colors.white, size: 20)),
                              title: Text(i.description,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${i.category.label} · ${i.confirmationCount} confirm. · ${timeAgo(i.lastConfirmedAt)}'),
                              trailing: ImpactChip(
                                  level: app.profile.impactOf(i.category)),
                              onTap: () => showIssueDetails(context, i.id),
                            ),
                          ),
                        ),
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Juntos, tornamos a cidade visível'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Stat(
                            value: '${repo.issues.length}',
                            label: 'problemas\nregistrados',
                            icon: Icons.place,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        _Stat(
                            value: '$confirmed',
                            label: 'confirmados\npela comunidade',
                            icon: Icons.verified,
                            color: const Color(0xFF3949AB)),
                        const SizedBox(width: 10),
                        _Stat(
                            value: '$resolved',
                            label: 'já\nresolvidos',
                            icon: Icons.celebration,
                            color: const Color(0xFF2E7D32)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _TipCard(text: tip),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final AppState app;
  const _Header({required this.app});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';
    final name = app.displayName.isEmpty ? '' : ', ${app.displayName}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 52),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, const Color(0xFF3F7CE0)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_city, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text('Cidade Invisível',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 20),
            Text('$greeting$name! 👋',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('A cidade que você não vê, nós ajudamos a enxergar.',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.white.withValues(alpha: .92))),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Visão atual: ${app.profile.label}. Toque para mudar.',
              child: Material(
                color: Colors.white.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => showProfileSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(app.profile.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('Visão: ${app.profile.label}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ReportCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      shadowColor: cs.secondary.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(24),
      color: cs.secondary,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .25),
                    shape: BoxShape.circle),
                child: Icon(Icons.add_a_photo,
                    color: cs.onSecondary, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Viu um problema?',
                        style: TextStyle(
                            color: cs.onSecondary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Registre em 3 passos: foto, local e detalhes.',
                        style: TextStyle(
                            color: cs.onSecondary.withValues(alpha: .92))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: cs.onSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _QuickActions({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.map_rounded, 'Mapa', 'Problemas na região', const Color(0xFF1E88E5), 1),
      (Icons.directions_walk_rounded, 'Observar trajeto', 'Sensores ajudam a achar',
          const Color(0xFF8E24AA), 2),
      (Icons.emoji_events_rounded, 'Contribuições', 'Seu histórico',
          const Color(0xFFF9A825), 3),
      (Icons.tune_rounded, 'Meu perfil', 'Visão e alertas',
          const Color(0xFF00897B), 4),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: [
        for (final i in items)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onNavigate(i.$5),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: i.$4.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(i.$1, color: i.$4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(i.$3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

class _EmptyHighlights extends StatelessWidget {
  final VoidCallback onOpenMap;
  const _EmptyHighlights({required this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('🗺️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            const Text('Ainda não há registros por aqui.',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
                'Abra o mapa para ver a sua região ou seja o primeiro a registrar um problema.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onOpenMap, child: const Text('Abrir o mapa')),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _Stat(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String text;
  const _TipCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.tertiary.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Você sabia?',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
