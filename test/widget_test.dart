import 'package:flutter_test/flutter_test.dart';

import 'package:cidade_invisivel/app/app.dart';

void main() {
  testWidgets('Tela inicial exibe as quatro funcionalidades', (tester) async {
    await tester.pumpWidget(const CidadeInvisivelApp());

    expect(find.text('Câmera'), findsOneWidget);
    expect(find.text('Localização GPS'), findsOneWidget);
    expect(find.text('Acelerômetro'), findsOneWidget);
    expect(find.text('Notificações'), findsOneWidget);
  });
}
