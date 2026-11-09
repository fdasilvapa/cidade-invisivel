import 'package:flutter/material.dart';

import '../../core/services/app_state.dart';
import '../../models/mobility_profile.dart';
import '../../shared/widgets/profile_picker.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;
  MobilityProfile _profile = MobilityProfile.general;

  void _next() {
    if (_page == 0) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      AppScope.of(context).completeOnboarding(_profile);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [_welcome(cs), _profilePage()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 2; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? cs.primary : cs.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(_page == 0 ? 'Continuar' : 'Começar'),
                    ),
                  ),
                  if (_page == 1)
                    TextButton(
                      onPressed: () =>
                          AppScope.of(context).completeOnboarding(null),
                      child: const Text('Pular por enquanto'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome(ColorScheme cs) {
    Widget point(IconData i, String t, String s) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(i, color: cs.onPrimaryContainer)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(s),
                  ],
                ),
              ),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.location_city, size: 72, color: cs.primary),
        const SizedBox(height: 16),
        Text('Cidade Invisível',
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('A cidade que você não vê, nós ajudamos a enxergar.',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 32),
        point(Icons.camera_alt, 'Registre',
            'Fotografe buracos, rampas quebradas e obstáculos.'),
        point(Icons.map, 'Veja no mapa',
            'Problemas da sua região, de acordo com a sua forma de se deslocar.'),
        point(Icons.groups, 'Confirme com a comunidade',
            'Mais pessoas confirmando deixam as informações mais confiáveis.'),
        point(Icons.lock_outline, 'Você no controle',
            'Localização e sensores só são usados quando você pedir.'),
      ],
    );
  }

  Widget _profilePage() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Como você se desloca?',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Usamos isso para destacar os problemas mais importantes para você. '
            'É opcional, não pedimos nenhuma informação médica e você pode mudar depois. '
            'Nenhum problema é escondido.'),
        const SizedBox(height: 20),
        ProfilePicker(
            selected: _profile,
            onChanged: (p) => setState(() => _profile = p)),
      ],
    );
  }
}
