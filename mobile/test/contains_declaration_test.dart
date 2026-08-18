/// Regressão do caso Velly (pipoca): mesmo quando todos os ingredientes
/// lidos são seguros, uma declaração direta "CONTÉM X" do próprio rótulo
/// precisa aparecer como alerta na tela de resultado. Antes, "CONTÉM GLÚTEN"
/// era descartada junto com o marcador de fim da lista e o celíaco via
/// "0 alertas".
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/scan_result.dart';
import 'package:mobile/screens/result_screen.dart';
import 'package:mobile/utils/text_parser.dart';

import 'support/harness.dart';

void main() {
  testWidgets(
      'declaração "Contém glúten" vira alerta mesmo com ingredientes seguros',
      (tester) async {
    useMobileSurface(tester);
    final handle = tester.ensureSemantics();
    final provider = await memoryProvider(profile: celiacProfile);
    await tester.pumpWidget(wrapApp(
      ResultScreen(
        // Ingredientes todos seguros (milho, sal): sem esta declaração o
        // banner mostraria "Sem Correspondência".
        scanResult: safeScanResult(),
        containsWarnings: const [
          ContainsDeclaration(term: 'Glúten', disorders: ['Doença Celíaca']),
        ],
      ),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    // O banner geral precisa acusar perigo.
    expect(find.text('Atenção! Alertas Detectados'), findsOneWidget);
    expect(find.text('Sem Correspondência para seu Perfil'), findsNothing);

    // A seção dedicada da declaração direta aparece e nomeia o distúrbio.
    expect(find.text('Contém (declarado no rótulo)'), findsOneWidget);
    expect(find.textContaining('Glúten'), findsWidgets);

    // E o resumo passa a contar a declaração — não fica "Alertas: 0".
    final announced = semanticsNodesInOrder(tester).map(announcedText);
    expect(announced.any((t) => t == 'Alertas: 1'), isTrue,
        reason: 'a declaração "contém" deve entrar na contagem de Alertas');
    handle.dispose();
  });

  test('ScanResult round-trip preserva traços e declarações "contém" (RF14)', () {
    final original = ScanResult(
      rawText: 'INGREDIENTES: MILHO. CONTÉM GLÚTEN.',
      ingredients: const [],
      flaggedIngredients: const [],
      traceWarnings: const [
        TraceWarning(term: 'Leite', disorders: ['Intolerância à Lactose']),
      ],
      containsDeclarations: const [
        ContainsDeclaration(term: 'Glúten', disorders: ['Doença Celíaca']),
      ],
      scannedAt: DateTime(2026, 8, 14),
    );

    final restored = ScanResult.fromJson(original.toJson());

    expect(restored.traceWarnings, hasLength(1));
    expect(restored.traceWarnings.first.term, 'Leite');
    expect(restored.traceWarnings.first.disorders, ['Intolerância à Lactose']);
    expect(restored.containsDeclarations, hasLength(1));
    expect(restored.containsDeclarations.first.term, 'Glúten');
    expect(restored.containsDeclarations.first.disorders, ['Doença Celíaca']);
  });

  testWidgets('reabrir do histórico preserva o alerta "CONTÉM GLÚTEN"',
      (tester) async {
    useMobileSurface(tester);
    final provider = await memoryProvider(profile: celiacProfile);

    // Ciclo real: scan salvo com declaração "contém" → persistido (toJson) →
    // reaberto do histórico (fromJson), exatamente como a HistoryScreen faz.
    final saved = ScanResult(
      rawText: 'INGREDIENTES: MILHO DE PIPOCA, SAL. CONTÉM GLÚTEN.',
      ingredients: const [],
      flaggedIngredients: const [],
      containsDeclarations: const [
        ContainsDeclaration(term: 'Glúten', disorders: ['Doença Celíaca']),
      ],
    );
    final reopened = ScanResult.fromJson(saved.toJson());

    await tester.pumpWidget(wrapApp(
      ResultScreen(
        scanResult: reopened,
        traceWarnings: reopened.traceWarnings,
        containsWarnings: reopened.containsDeclarations,
      ),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    // O alerta de presença tem de reaparecer — não voltar a "0 alertas".
    expect(find.text('Contém (declarado no rótulo)'), findsOneWidget);
    expect(find.text('Atenção! Alertas Detectados'), findsOneWidget);
    expect(find.text('Sem Correspondência para seu Perfil'), findsNothing);
  });
}
