# Cidade Invisível

> A cidade que você não vê, nós ajudamos a enxergar.

App Flutter de mapa colaborativo de problemas urbanos e acessibilidade.
Trabalho "Meu Smartphone Inteligente" (Desenvolvimento Mobile, 8º período).

## Funcionalidades obrigatórias

| Recurso | Pacote | Pasta |
|---|---|---|
| Câmera | `camera` | `lib/features/camera` |
| Localização (GPS) | `geolocator` | `lib/features/location` |
| Sensores (acelerômetro) | `sensors_plus` | `lib/features/sensors` |
| Notificação local | `flutter_local_notifications` | `lib/features/notifications` |

`permission_handler` centraliza o pedido de permissões (`lib/core/permissions`).

## Como rodar

```bash
flutter pub get
flutter run
```

Requisitos: Flutter 3.47+ (Dart 3.13+), Android SDK 37 instalado.

## Estrutura

```
lib/
├── main.dart
├── app/          # MaterialApp, rotas e tema
├── core/         # constants, errors, permissions, services, utils
├── models/       # modelos de dados
├── features/     # uma pasta por funcionalidade
└── shared/       # widgets e componentes reutilizáveis
```

## Fluxo de trabalho do grupo

- Não commitar direto na `main`: criar branch `feature/<nome>` e abrir Pull Request.
- Cada feature fica na sua pasta em `lib/features/` para evitar conflitos.
- Rodar `flutter analyze` e `flutter test` antes do PR.

## Fora do escopo inicial

Firebase, Google Maps e IA (TensorFlow Lite) estão no plano do projeto, mas só
entram se sobrar tempo depois das quatro funcionalidades obrigatórias.
