/// Regressão do caso Velly (pipoca): mesmo quando todos os ingredientes
/// lidos são seguros, uma declaração direta "CONTÉM X" do próprio rótulo
/// precisa aparecer como alerta na tela de resultado. Antes, "CONTÉM GLÚTEN"
/// era descartada junto com o marcador de fim da lista e o celíaco via
/// "0 alertas".
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/result_screen.dart';
import 'package:mobile/utils/text_parser.dart';

import 'support/harness.dart';

void main() {
  testWidgets(
      'declaração "Contém glúten" vira alerta mesmo com ingredientes seguros',
      (tester) async {
    useMobileSurface(tester);
    final provider = await memoryProvider(profile: celiacProfile);
    await tester.pumpWidget(wrapApp(
      ResultScreen(
        // Ingredientes todos seguros (milho, sal): sem esta declaração o
        // banner mostraria "Tudo Certo".
        scanResult: safeScanResult(),
        containsWarnings: const [
          ContainsDeclaration(term: 'Glúten', disorders: ['Doença Celíaca']),
        ],
      ),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    // O banner geral precisa acusar perigo, não "Tudo Certo".
    expect(find.text('Atenção! Alertas Detectados'), findsOneWidget);
    expect(find.text('Tudo Certo! Nenhum Alerta'), findsNothing);

    // A seção dedicada da declaração direta aparece e nomeia o distúrbio.
    expect(find.text('Contém (declarado no rótulo)'), findsOneWidget);
    expect(find.textContaining('Glúten'), findsWidgets);
  });
}
