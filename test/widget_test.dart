import 'package:flutter_test/flutter_test.dart';

import 'package:cidade_invisivel/app/app.dart';

void main() {
  testWidgets('Tela inicial exibe as quatro funcionalidades', (tester) async {
    await tester.pumpWidget(const CidadeInvisivelApp());

    expect(find.text('Câmera'), findsOneWidget);
    expect(find.text('Localização'), findsOneWidget);
    expect(find.text('Sensores'), findsOneWidget);
    expect(find.text('Notificações'), findsOneWidget);
  });
}
