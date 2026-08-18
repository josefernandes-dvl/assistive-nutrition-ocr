/// RF25 — a tela de resultado classifica em TRÊS níveis de severidade e
/// reflete cada um por cor/texto no banner. RN03 — o nível mais baixo é
/// "ausência de correspondência", e não uma afirmação de segurança.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/scan_result.dart';
import 'package:mobile/screens/result_screen.dart';
import 'package:mobile/utils/text_parser.dart';

import 'support/harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool flagged,
    List<TraceWarning> traces = const [],
    List<ContainsDeclaration> contains = const [],
  }) async {
    useMobileSurface(tester);
    final provider = await memoryProvider(profile: celiacProfile);
    await tester.pumpWidget(wrapApp(
      ResultScreen(
        scanResult: flagged ? flaggedScanResult() : safeScanResult(),
        traceWarnings: traces,
        containsWarnings: contains,
      ),
      provider: provider,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('PERIGO quando há ingrediente sinalizado', (tester) async {
    await pump(tester, flagged: true);
    expect(find.text('Atenção! Alertas Detectados'), findsOneWidget);
    expect(find.text('Atenção: Possível Presença'), findsNothing);
    expect(find.text('Sem Correspondência para seu Perfil'), findsNothing);
  });

  testWidgets('ATENÇÃO quando só há traços ("pode conter"), sem gatilho firme',
      (tester) async {
    await pump(
      tester,
      flagged: false,
      traces: const [
        TraceWarning(term: 'Trigo', disorders: ['Doença Celíaca']),
      ],
    );
    expect(find.text('Atenção: Possível Presença'), findsOneWidget);
    expect(find.text('Atenção! Alertas Detectados'), findsNothing);
    expect(find.text('Sem Correspondência para seu Perfil'), findsNothing);
  });

  testWidgets('SEM CORRESPONDÊNCIA não afirma segurança (RN03)', (tester) async {
    await pump(tester, flagged: false);
    expect(find.text('Sem Correspondência para seu Perfil'), findsOneWidget);
    // O estado sem alerta nunca diz "Tudo Certo".
    expect(find.textContaining('Tudo Certo'), findsNothing);
    // ...e traz a ressalva explícita de não-segurança.
    expect(
      find.textContaining('não afirma que o produto é seguro'),
      findsOneWidget,
    );
  });

  // Fluxo de código de barras: a OFF tem o produto mas não a lista de
  // ingredientes/alérgenos. Não pode virar um verde "sem correspondência" —
  // seria falso "seguro". Deve dizer, em âmbar, que não deu para analisar.
  testWidgets('PRODUTO NÃO ANALISADO quando a OFF não tem ingredientes',
      (tester) async {
    useMobileSurface(tester);
    final provider = await memoryProvider(profile: celiacProfile);
    final semDados = ScanResult(
      rawText: 'Refrigerante Cola 2L',
      ingredients: const [],
      flaggedIngredients: const [],
    );
    await tester.pumpWidget(wrapApp(
      ResultScreen(scanResult: semDados, noIngredientData: true),
      provider: provider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Produto não analisado'), findsOneWidget);
    // Não pode aparecer o verde de "sem correspondência".
    expect(find.text('Sem Correspondência para seu Perfil'), findsNothing);
    // O resumo 0/0/0 sem sentido não é mostrado; no lugar, o aviso honesto.
    expect(find.text('Alertas'), findsNothing);
    expect(
      find.textContaining('não tem a lista de ingredientes'),
      findsWidgets,
    );
    // ...e nunca sugere segurança.
    expect(find.textContaining('não significa que o produto seja seguro'),
        findsOneWidget);
  });
}
