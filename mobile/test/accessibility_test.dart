/// CA06 — em teste com leitor de tela, todos os elementos interativos da tela
///        de resultado são anunciados com rótulo significativo.
/// CA15 — toda tela de resultado exibe o aviso de não-substituição de
///        aconselhamento médico.
///
/// O teste liga a camada de semântica do Flutter (a mesma que alimenta
/// TalkBack e VoiceOver) e inspeciona a árvore anunciada, em vez de verificar
/// apenas a presença dos widgets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/history_screen.dart';
import 'package:mobile/screens/result_screen.dart';
import 'package:mobile/widgets/medical_disclaimer.dart';

import 'support/harness.dart';

void main() {
  /// Monta a tela de resultado em suas variações relevantes.
  Future<void> pumpResult(
    WidgetTester tester, {
    required bool flagged,
    bool enriched = false,
    bool lowQuality = false,
  }) async {
    useMobileSurface(tester);
    final provider = await memoryProvider(profile: celiacProfile);
    await tester.pumpWidget(wrapApp(
      ResultScreen(
        scanResult: flagged ? flaggedScanResult() : safeScanResult(),
        enrichment: enriched ? sampleEnrichment() : null,
        traceWarnings: flagged ? sampleTraceWarnings() : const [],
        lowQualityOcr: lowQuality,
      ),
      provider: provider,
    ));
    await tester.pumpAndSettle();
  }

  group('CA15 — aviso de não-substituição de aconselhamento médico', () {
    testWidgets('aparece no resultado com alertas', (tester) async {
      await pumpResult(tester, flagged: true, enriched: true);
      expect(find.byType(MedicalDisclaimer), findsOneWidget);
      expect(find.text(MedicalDisclaimer.message), findsOneWidget);
    });

    testWidgets('aparece também no resultado sem alertas', (tester) async {
      await pumpResult(tester, flagged: false);
      expect(find.byType(MedicalDisclaimer), findsOneWidget);
    });

    testWidgets('aparece ao reabrir uma análise do histórico (RF16)',
        (tester) async {
      useMobileSurface(tester);
      final scan = flaggedScanResult();
      final provider = await memoryProvider(
        profile: celiacProfile,
        history: [scan],
      );
      await tester.pumpWidget(
          wrapApp(const HistoryScreen(), provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.byType(MedicalDisclaimer), findsOneWidget);
    });

    testWidgets('está acima da dobra, antes da lista de ingredientes',
        (tester) async {
      await pumpResult(tester, flagged: true);
      final disclaimerY =
          tester.getTopLeft(find.byType(MedicalDisclaimer)).dy;
      final listY = tester
          .getTopLeft(find.text('Todos os Ingredientes Detectados'))
          .dy;
      expect(disclaimerY, lessThan(listY));
      // Visível sem rolagem, na superfície de referência (900 px de altura).
      expect(disclaimerY, lessThan(900));
    });

    testWidgets('é anunciado como um bloco único pelo leitor de tela',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpResult(tester, flagged: true);

      final announced = semanticsNodesInOrder(tester).map(announcedText);
      expect(
        announced.any((text) =>
            text.contains('não substitui a orientação de médico')),
        isTrue,
      );
      handle.dispose();
    });
  });

  group('CA06 — leitor de tela na tela de resultado', () {
    testWidgets('todo elemento interativo tem rótulo significativo',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpResult(tester, flagged: true, enriched: true, lowQuality: true);

      final interactive =
          semanticsNodesInOrder(tester).where(isInteractive).toList();

      expect(interactive, isNotEmpty,
          reason: 'a tela precisa expor elementos acionáveis');

      final semRotulo = interactive
          .where((n) => announcedText(n).trim().length < 2)
          .map((n) => n.toStringDeep())
          .toList();

      expect(semRotulo, isEmpty,
          reason: 'elementos interativos sem rótulo:\n'
              '${semRotulo.join("\n")}');
      handle.dispose();
    });

    testWidgets('o mesmo vale para o resultado sem alertas', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpResult(tester, flagged: false);

      final semRotulo = semanticsNodesInOrder(tester)
          .where(isInteractive)
          .where((n) => announcedText(n).trim().length < 2)
          .toList();
      expect(semRotulo, isEmpty);
      handle.dispose();
    });

    testWidgets('a situação geral é anunciada primeiro, com prefixo "Alerta"',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpResult(tester, flagged: true, enriched: true);

      final announced = semanticsNodesInOrder(tester)
          .map(announcedText)
          .where((t) => t.isNotEmpty)
          .toList();

      final indexBanner =
          announced.indexWhere((t) => t.startsWith('Alerta: Atenção!'));
      expect(indexBanner, isNonNegative,
          reason: 'o banner de severidade precisa abrir o anúncio');

      final indexIngredienteSeguro =
          announced.indexWhere((t) => t.startsWith('Sem alerta: Açúcar'));
      expect(indexIngredienteSeguro, isNonNegative);
      expect(indexBanner, lessThan(indexIngredienteSeguro));

      handle.dispose();
    });

    testWidgets('cada ingrediente sinalizado é anunciado com motivo',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpResult(tester, flagged: true);

      final announced = semanticsNodesInOrder(tester).map(announcedText);
      expect(
        announced.any((t) =>
            t.startsWith('Alerta: Farinha De Trigo Enriquecida') &&
            t.contains('trigo (Doença Celíaca)')),
        isTrue,
      );
      expect(
        announced.any((t) => t.startsWith('Sem alerta: Sal')),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('ingredientes sinalizados são anunciados antes dos demais',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpResult(tester, flagged: true);

      final announced = semanticsNodesInOrder(tester)
          .map(announcedText)
          .where((t) => t.isNotEmpty)
          .toList();

      final primeiroAlerta =
          announced.indexWhere((t) => t.startsWith('Alerta: Farinha'));
      final primeiroSeguro =
          announced.indexWhere((t) => t.startsWith('Sem alerta:'));
      expect(primeiroAlerta, isNonNegative);
      expect(primeiroSeguro, isNonNegative);
      expect(primeiroAlerta, lessThan(primeiroSeguro));
      handle.dispose();
    });

    testWidgets('as estatísticas são lidas como frases, não como números soltos',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpResult(tester, flagged: true);

      final announced = semanticsNodesInOrder(tester).map(announcedText);
      expect(announced.any((t) => t == 'Total: 4'), isTrue);
      expect(announced.any((t) => t == 'Alertas: 2'), isTrue);
      expect(announced.any((t) => t == 'Seguros: 2'), isTrue);
      handle.dispose();
    });

    testWidgets('a diretriz de acessibilidade padrão do Flutter é atendida',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpResult(tester, flagged: true, enriched: true);

      // Rótulos presentes em todos os nós acionáveis e alvos de toque com
      // tamanho mínimo — as duas checagens que o RNF07 cita explicitamente.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });
}
