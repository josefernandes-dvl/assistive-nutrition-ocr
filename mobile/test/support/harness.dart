/// Utilitários compartilhados pelos testes de tela: montagem do app com um
/// armazenamento temporário, fixtures de análise e travessia da árvore de
/// semântica.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme.dart';
import 'package:mobile/models/enriched_analysis.dart';
import 'package:mobile/models/ingredient.dart';
import 'package:mobile/models/scan_result.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/providers/app_provider.dart';
import 'package:mobile/services/local_store.dart';
import 'package:mobile/utils/text_parser.dart';
import 'package:provider/provider.dart';

/// Armazenamento em memória com a mesma interface do disco.
///
/// `testWidgets` roda dentro de uma zona de tempo falso: uma operação real de
/// arquivo nunca completa ali e o teste trava. Os testes de tela usam este
/// duplo; a persistência de verdade é exercitada em `persistence_test.dart`,
/// que roda fora dessa zona.
class MemoryLocalStore extends LocalStore {
  MemoryLocalStore()
      : super(directoryResolver: () async => Directory.systemTemp);

  Map<String, dynamic>? _data;

  bool get isEmpty => _data == null;

  @override
  Future<Map<String, dynamic>?> read() async => _data;

  @override
  Future<void> write(Map<String, dynamic> data) async {
    _data = {'schema_version': LocalStore.schemaVersion, ...data};
  }

  @override
  Future<void> erase() async => _data = null;
}

/// Provider pronto para uso em teste de tela.
Future<AppProvider> memoryProvider({
  UserProfile? profile,
  List<ScanResult> history = const [],
  bool consented = true,
  MemoryLocalStore? store,
}) async {
  final provider = AppProvider(store: store ?? MemoryLocalStore());
  await provider.load();
  if (consented) await provider.acceptPrivacyNotice();
  if (profile != null) await provider.updateProfile(profile);
  for (final scan in history) {
    await provider.addScanResult(scan);
  }
  return provider;
}

/// Monta um widget dentro do MaterialApp real do projeto (mesmo tema, mesmo
/// provider), que é a condição em que a acessibilidade e o contraste precisam
/// valer.
Widget wrapApp(Widget child, {required AppProvider provider}) {
  return ChangeNotifierProvider<AppProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

/// Define uma superfície de teste estável (equivalente a um celular comum).
void useMobileSurface(WidgetTester tester, {Size logical = const Size(400, 900)}) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(logical.width * 3, logical.height * 3);
  addTearDown(tester.view.reset);
}

// ===========================================================================
// Fixtures
// ===========================================================================

const UserProfile celiacProfile = UserProfile(
  name: 'Maria',
  disorders: ['Doença Celíaca', 'Intolerância à Lactose'],
  customAllergens: ['mostarda'],
);

/// Resultado com alertas — o caso que mais exige da acessibilidade.
ScanResult flaggedScanResult() {
  const ingredients = [
    Ingredient(
      name: 'Farinha De Trigo Enriquecida',
      isFlagged: true,
      flagReason: 'trigo (Doença Celíaca)',
      relatedDisorder: 'Doença Celíaca',
    ),
    Ingredient(
      name: 'Soro De Leite',
      isFlagged: true,
      flagReason: 'soro de leite (Intolerância à Lactose)',
      relatedDisorder: 'Intolerância à Lactose',
    ),
    Ingredient(name: 'Açúcar'),
    Ingredient(name: 'Sal'),
  ];
  return ScanResult(
    rawText: 'INGREDIENTES: FARINHA DE TRIGO ENRIQUECIDA, SORO DE LEITE, '
        'AÇÚCAR, SAL. PODE CONTER AMENDOIM.',
    ingredients: ingredients,
    flaggedIngredients:
        ingredients.where((i) => i.isFlagged).toList(growable: false),
    scannedAt: DateTime(2026, 7, 20, 14, 30),
  );
}

/// Resultado sem nenhuma correspondência com o perfil.
ScanResult safeScanResult() {
  const ingredients = [
    Ingredient(name: 'Água'),
    Ingredient(name: 'Açúcar'),
  ];
  return ScanResult(
    rawText: 'INGREDIENTES: ÁGUA, AÇÚCAR.',
    ingredients: ingredients,
    flaggedIngredients: const [],
    scannedAt: DateTime(2026, 7, 19, 9, 0),
  );
}

EnrichmentBundle sampleEnrichment() {
  return const EnrichmentBundle(
    officialAllergens: [
      OfficialAllergen(tag: 'en:gluten', disorders: ['Doença Celíaca']),
      OfficialAllergen(tag: 'en:milk', disorders: ['Intolerância à Lactose']),
    ],
    product: ProductInfo(
      barcode: '7622210449283',
      name: 'Biscoito Recheado',
      brand: 'Marca Teste',
      novaGroup: 4,
      nutriscoreGrade: 'd',
    ),
  );
}

List<TraceWarning> sampleTraceWarnings() => const [
      TraceWarning(term: 'Amendoim', disorders: ['Alérgeno personalizado']),
    ];

// ===========================================================================
// Semântica
// ===========================================================================

/// Percorre a árvore de semântica em profundidade, na ordem em que um leitor
/// de tela anunciaria os nós.
List<SemanticsNode> semanticsNodesInOrder(WidgetTester tester) {
  final root = tester.binding.rootPipelineOwner.semanticsOwner
          ?.rootSemanticsNode ??
      tester.getSemantics(find.byType(MaterialApp));

  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    final children = <SemanticsNode>[];
    node.visitChildren((child) {
      children.add(child);
      return true;
    });
    for (final child in children) {
      visit(child);
    }
  }

  visit(root);
  return nodes;
}

/// Texto que o leitor de tela anunciaria para um nó.
String announcedText(SemanticsNode node) {
  final data = node.getSemanticsData();
  final parts = [data.label, data.value, data.tooltip, data.hint]
      .where((s) => s.trim().isNotEmpty);
  return parts.join(' ').trim();
}

bool isInteractive(SemanticsNode node) {
  final data = node.getSemanticsData();
  const actionable = [
    SemanticsAction.tap,
    SemanticsAction.longPress,
    SemanticsAction.increase,
    SemanticsAction.decrease,
  ];
  return actionable.any(data.hasAction);
}
