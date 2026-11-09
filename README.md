# Cidade Invisível

> A cidade que você não vê, nós ajudamos a enxergar.

App Flutter de mapa colaborativo de problemas urbanos e acessibilidade.
Trabalho "Meu Smartphone Inteligente" (Desenvolvimento Mobile, 8º período).

## Funcionalidades obrigatórias

| Recurso | Pacote | Pasta |
|---|---|---|
| Câmera | `camera` | `lib/features/camera` |
| Localização (GPS) | `geolocator` | `lib/core/services/location_service.dart` |
| Sensores (acelerômetro) | `sensors_plus` | `lib/core/services/motion/`, `lib/features/sensors` |
| Notificação local | `flutter_local_notifications` | `lib/core/services/notification_service.dart` |

As telas de teste de cada recurso ficam em **Perfil → Diagnóstico de recursos**.
`permission_handler` pede a permissão da câmera; localização e notificações usam
as próprias bibliotecas.

## Como rodar

Requisitos: Flutter 3.47+ (Dart 3.13+) e, para Android, Android SDK com um emulador.

```bash
flutter pub get
flutter analyze && flutter test
```

### 1. Servidor local (registros e fotos compartilhados)

Os registros ficam num banco SQLite servido por um script Python (só biblioteca
padrão, sem instalar nada). Ele também entrega o app web.

```bash
python3 server/server.py --port 8080          # API em http://localhost:8080
```

Os dados ficam em `server/data/` (ignorado pelo git).

### 2. App no emulador Android

O emulador enxerga o PC em `10.0.2.2`, que já é o endereço padrão da API:

```bash
flutter run -d <id-do-emulador>
```

Para um celular real ou outro endereço, informe a URL da API:

```bash
flutter run --dart-define=API_URL=http://<ip-do-pc>:8080
```

> Sem o servidor ligado o app abre, mostra "Sem conexão com o servidor" e usa os
> últimos dados salvos.

### 3. App na web

```bash
flutter build web --release
python3 server/server.py --port 8080          # serve o app e a API juntos
```

Abra `http://localhost:8080`. Para testar no celular, publique a porta com um
túnel HTTPS (por exemplo `ngrok http 8080`): câmera, GPS e sensores só funcionam
em HTTPS. Notificações na web são apenas avisos dentro do app; a notificação
local de verdade é a do Android.

## Estrutura

```
lib/
├── main.dart
├── app/          # MaterialApp, rotas e tema
├── core/         # services (GPS, notificações, sensores, repositório), utils
├── models/       # UrbanIssue, MobilityProfile, IssueCategory...
├── features/     # home, map, issue_reporting, sensors, camera, profile...
└── shared/       # widgets reutilizáveis
server/           # servidor Python + SQLite (API e app web)
```

## Fluxo de trabalho do grupo

- Não commitar direto na `main`: criar branch `feature/<nome>` e abrir Pull Request.
- Cada feature fica na sua pasta em `lib/features/` para evitar conflitos.
- Rodar `flutter analyze` e `flutter test` antes do PR.

## Próximos passos

Classificação da foto por IA, "resolver com prova" (foto do depois), pontos e
selos, notificações push (FCM/OneSignal) e rotas conscientes.
