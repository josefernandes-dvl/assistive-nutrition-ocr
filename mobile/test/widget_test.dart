import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile/main.dart';
import 'package:mobile/providers/app_provider.dart';

void main() {
  testWidgets('App smoke test - renders NutriScan home', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const NutriScanApp(),
      ),
    );

    expect(find.text('NutriScan'), findsOneWidget);
    expect(find.text('Escanear Rótulo'), findsOneWidget);
  });
}
