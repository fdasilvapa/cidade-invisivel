import 'package:flutter/material.dart';

import '../../models/mobility_profile.dart';

/// Lista de perfis de mobilidade (seleção única).
class ProfilePicker extends StatelessWidget {
  final MobilityProfile selected;
  final ValueChanged<MobilityProfile> onChanged;

  const ProfilePicker(
      {super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final p in MobilityProfile.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              button: true,
              selected: p == selected,
              label: '${p.label}. ${p.priorities}',
              child: Material(
                color: p == selected
                    ? cs.primaryContainer
                    : cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: p == selected ? cs.primary : cs.outlineVariant,
                      width: p == selected ? 2 : 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(p),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(p.icon, size: 30, color: cs.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16)),
                              Text(p.priorities,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (p == selected)
                          Icon(Icons.check_circle, color: cs.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
