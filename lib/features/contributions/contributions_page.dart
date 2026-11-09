import 'package:flutter/material.dart';

import '../../core/services/app_state.dart';
import '../../core/utils/geo.dart';
import '../../models/urban_issue.dart';
import '../issue_details/issue_details_sheet.dart';

class ContributionsPage extends StatelessWidget {
  const ContributionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app.issues,
      builder: (context, _) {
        final repo = app.issues;
        final mine = repo.issues.where((i) => i.mine).toList();
        final confirmed = repo.issues
            .where((i) => repo.confirmedByMe.contains(i.id))
            .toList();
        final resolved = mine.where((i) => i.resolved).length;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Minhas contribuições'),
              bottom: TabBar(tabs: [
                Tab(text: 'Registrados (${mine.length})'),
                Tab(text: 'Confirmados (${confirmed.length})'),
              ]),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _stat(context, '${mine.length}', 'registros'),
                      const SizedBox(width: 8),
                      _stat(context, '${confirmed.length}', 'confirmações'),
                      const SizedBox(width: 8),
                      _stat(context, '$resolved', 'resolvidos'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [
                    _list(context, mine,
                        'Você ainda não registrou nenhum problema.\nToque em "Registrar problema" no mapa.'),
                    _list(context, confirmed,
                        'Você ainda não confirmou nenhum problema.\nAbra um marcador no mapa e confirme se ele continua lá.'),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stat(BuildContext context, String n, String label) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(n,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );

  Widget _list(BuildContext context, List<UrbanIssue> list, String empty) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(empty, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, k) {
        final i = list[k];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
                backgroundColor: i.category.color,
                child: Icon(i.category.icon, color: Colors.white, size: 20)),
            title: Text(i.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${i.category.label} · ${timeAgo(i.createdAt)} · ${i.resolved ? 'resolvido' : '${i.confirmationCount} confirm.'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showIssueDetails(context, i.id),
          ),
        );
      },
    );
  }
}
