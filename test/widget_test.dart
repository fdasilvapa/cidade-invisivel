import 'package:cidade_invisivel/app/app.dart';
import 'package:cidade_invisivel/core/services/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Primeiro acesso mostra o onboarding e permite escolher perfil',
      (tester) async {
    final state = AppState();
    await tester.pumpWidget(CidadeInvisivelApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Cidade Invisível'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Como você se desloca?'), findsOneWidget);
    expect(find.text('Cadeirante'), findsOneWidget);
    expect(find.text('Pular por enquanto'), findsOneWidget);
  });
}
