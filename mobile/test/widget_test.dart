import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/providers/app_provider.dart';
import 'package:provider/provider.dart';

import 'support/harness.dart';

void main() {
  testWidgets('App smoke test - renders NutriScan home', (tester) async {
    useMobileSurface(tester);
    // Instalação já consentida: o aviso de privacidade tem teste próprio em
    // privacy_flow_test.dart.
    final provider = await memoryProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const NutriScanApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NutriScan'), findsOneWidget);
    expect(find.text('Escanear Rótulo'), findsOneWidget);
  });

  testWidgets('App aguarda a carga local antes de decidir a tela',
      (tester) async {
    useMobileSurface(tester);
    final provider = AppProvider(store: MemoryLocalStore());

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const NutriScanApp(),
      ),
    );
    await tester.pump();

    // Antes de `load()`, nada é decidido — nem home, nem aviso.
    expect(find.text('NutriScan'), findsNothing);
    expect(find.text('Antes de começar'), findsNothing);

    await provider.load();
    await tester.pumpAndSettle();
    expect(find.text('Antes de começar'), findsOneWidget);
  });
}
