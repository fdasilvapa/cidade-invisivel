import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/api_config.dart';
import '../../core/services/app_state.dart';
import '../../core/utils/geo.dart';
import '../../models/mobility_profile.dart';
import '../../models/urban_issue.dart';
import '../../shared/widgets/impact_chip.dart';

Future<void> showIssueDetails(BuildContext context, String issueId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _IssueDetails(issueId: issueId, outerContext: context),
  );
}

class _IssueDetails extends StatelessWidget {
  final String issueId;
  final BuildContext outerContext;
  const _IssueDetails({required this.issueId, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app.issues,
      builder: (context, _) {
        UrbanIssue? issue;
        for (final i in app.issues.issues) {
          if (i.id == issueId) issue = i;
        }
        if (issue == null) {
          return const SizedBox(
              height: 160, child: Center(child: Text('Registro não encontrado.')));
        }
        return _content(context, app, issue);
      },
    );
  }

  Widget _content(BuildContext context, AppState app, UrbanIssue i) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final repo = app.issues;
    final alreadyConfirmed = repo.confirmedByMe.contains(i.id);
    final myImpact = app.profile.impactOf(i.category);

    void toast(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      shrinkWrap: true,
      children: [
        if (i.photoUrl != null || i.photoPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: i.photoUrl != null
                    ? Image.network(ApiConfig.resolve(i.photoUrl!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) => const Center(
                            child: Text('Não foi possível carregar a foto.')))
                    : kIsWeb
                        ? Image.network(i.photoPath!,
                            fit: BoxFit.cover, width: double.infinity)
                        : Image.file(File(i.photoPath!),
                            fit: BoxFit.cover, width: double.infinity),
              ),
            ),
          ),
        Row(
          children: [
            CircleAvatar(
                backgroundColor: i.category.color,
                child: Icon(i.category.icon, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.category.label,
                      style: text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Registrado ${timeAgo(i.createdAt)}'
                      '${i.isDemo ? ' · exemplo' : ''}',
                      style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(i.description, style: text.bodyLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('Gravidade: ${i.severity.label}')),
            Chip(
              avatar: Icon(
                  i.resolved ? Icons.check_circle : Icons.error_outline,
                  size: 18),
              label: Text(i.resolved ? 'Resolvido' : 'Em aberto'),
            ),
            Chip(
              avatar: Icon(
                  i.communityConfirmed ? Icons.verified : Icons.help_outline,
                  size: 18),
              label: Text(i.communityConfirmed
                  ? 'Confirmado pela comunidade'
                  : 'Ainda não confirmado'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${i.confirmationCount} confirmaç${i.confirmationCount == 1 ? 'ão' : 'ões'}'
          ' · última verificação ${timeAgo(i.lastConfirmedAt)}',
          style: text.bodySmall,
        ),
        if (!i.communityConfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Poucas evidências: esta informação pode estar incompleta ou desatualizada.',
              style: text.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        if (i.aiConfidence != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                'Sugestão da IA: ${(i.aiConfidence! * 100).round()}% de confiança (apenas uma sugestão).',
                style: text.bodySmall),
          ),
        const SizedBox(height: 16),
        Text('Impacto potencial por perfil',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final p in MobilityProfile.values.where((p) => p != MobilityProfile.general))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(p.icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(p.label +
                        (p == app.profile ? '  (seu perfil)' : ''))),
                ImpactChip(level: p.impactOf(i.category)),
              ],
            ),
          ),
        if (app.profile == MobilityProfile.general)
          Text('Para você: ${myImpact.label}', style: text.bodySmall),
        const SizedBox(height: 16),
        Text(
            'Local: ${i.latitude.toStringAsFixed(5)}, ${i.longitude.toStringAsFixed(5)}',
            style: text.bodySmall),
        const SizedBox(height: 16),
        if (!i.resolved) ...[
          FilledButton.icon(
            onPressed: alreadyConfirmed
                ? null
                : () async {
                    await repo.confirmStillExists(i.id);
                    toast('Obrigado! Sua confirmação foi registrada.');
                  },
            icon: const Icon(Icons.check),
            label: Text(alreadyConfirmed
                ? 'Você já confirmou'
                : 'Confirmar: o problema continua aqui'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await repo.markResolved(i.id);
              toast('Marcado como resolvido. Outros usuários podem contestar.');
            },
            icon: const Icon(Icons.task_alt),
            label: const Text('Informar que foi resolvido'),
          ),
        ] else
          FilledButton.icon(
            onPressed: alreadyConfirmed
                ? null
                : () async {
                    await repo.confirmStillExists(i.id);
                    toast('Registro reaberto. Obrigado por contestar.');
                  },
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Contestar: o problema ainda existe'),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text:
                          'https://www.openstreetmap.org/?mlat=${i.latitude}&mlon=${i.longitude}#map=19/${i.latitude}/${i.longitude}'));
                  toast('Link da localização copiado.');
                },
                icon: const Icon(Icons.share_location),
                label: const Text('Compartilhar'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: i.flagged
                    ? null
                    : () async {
                        await repo.flag(i.id);
                        toast('Obrigado, vamos revisar este registro.');
                      },
                icon: const Icon(Icons.flag_outlined),
                label: Text(i.flagged ? 'Reportado' : 'Informação incorreta'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
