/// CA01 — o perfil sobrevive ao encerramento e reabertura do aplicativo.
/// CA05 — a análise persiste e é recuperável após reinício, em ordem
///        decrescente de data.
/// CA08 — o aceite do aviso de privacidade persiste e "apagar meus dados"
///        remove perfil, histórico e consentimento de forma verificável.
///
/// O "reinício" é simulado da forma mais fiel possível a um teste automatizado:
/// um `AppProvider` novo, sem qualquer estado em memória, lendo o mesmo
/// diretório em disco que o anterior gravou.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/ingredient.dart';
import 'package:mobile/models/scan_result.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/providers/app_provider.dart';
import 'package:mobile/services/local_store.dart';

void main() {
  late Directory tempDir;

  LocalStore storeIn(Directory dir) =>
      LocalStore(directoryResolver: () async => dir);

  /// Simula reabrir o app: instância nova, mesmo armazenamento.
  Future<AppProvider> reopenApp() async {
    final provider = AppProvider(store: storeIn(tempDir));
    await provider.load();
    return provider;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nutriscan_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  ScanResult scanAt(DateTime when, {bool flagged = false, String? raw}) {
    final ingredient = Ingredient(
      name: flagged ? 'Farinha De Trigo' : 'Água',
      isFlagged: flagged,
      flagReason: flagged ? 'trigo (Doença Celíaca)' : null,
      relatedDisorder: flagged ? 'Doença Celíaca' : null,
    );
    return ScanResult(
      rawText: raw ?? 'INGREDIENTES: ${ingredient.name}',
      ingredients: [ingredient],
      flaggedIngredients: flagged ? [ingredient] : const [],
      scannedAt: when,
    );
  }

  group('CA01 — perfil sobrevive ao reinício', () {
    test('perfil preenchido continua disponível na reabertura', () async {
      final first = await reopenApp();
      expect(first.hasProfile, isFalse, reason: 'instalação limpa');

      await first.updateProfile(const UserProfile(
        name: 'Maria',
        disorders: ['Doença Celíaca', 'Intolerância à Lactose'],
        customAllergens: ['mostarda'],
      ));

      final reopened = await reopenApp();
      expect(reopened.hasProfile, isTrue);
      expect(reopened.profile.name, 'Maria');
      expect(reopened.profile.disorders,
          containsAll(['Doença Celíaca', 'Intolerância à Lactose']));
      expect(reopened.profile.customAllergens, ['mostarda']);
    });

    test('edição do perfil substitui o que estava gravado (RF02)', () async {
      final first = await reopenApp();
      await first.updateProfile(
        const UserProfile(name: 'Maria', disorders: ['Doença Celíaca']),
      );

      final second = await reopenApp();
      await second.addDisorder('Alergia ao Ovo');
      await second.removeDisorder('Doença Celíaca');

      final third = await reopenApp();
      expect(third.profile.disorders, ['Alergia ao Ovo']);
    });

    test('exclusão do perfil preserva o histórico (RF03)', () async {
      final first = await reopenApp();
      await first.updateProfile(
        const UserProfile(name: 'Maria', disorders: ['Doença Celíaca']),
      );
      await first.addScanResult(scanAt(DateTime(2026, 7, 20, 10)));

      await (await reopenApp()).deleteProfile();

      final reopened = await reopenApp();
      expect(reopened.hasProfile, isFalse);
      expect(reopened.scanHistory, hasLength(1));
    });
  });

  group('CA05 — histórico sobrevive ao reinício e mantém a ordem', () {
    test('análises persistem ordenadas por data decrescente', () async {
      final first = await reopenApp();
      // Inseridas fora de ordem de propósito.
      await first.addScanResult(scanAt(DateTime(2026, 7, 18, 9), raw: 'antiga'));
      await first.addScanResult(
          scanAt(DateTime(2026, 7, 20, 21), flagged: true, raw: 'recente'));
      await first.addScanResult(scanAt(DateTime(2026, 7, 19, 15), raw: 'meio'));

      final reopened = await reopenApp();
      expect(reopened.scanHistory, hasLength(3));
      expect(
        reopened.scanHistory.map((s) => s.rawText).toList(),
        ['recente', 'meio', 'antiga'],
      );
      expect(
        reopened.scanHistory.map((s) => s.scannedAt).toList(),
        [
          DateTime(2026, 7, 20, 21),
          DateTime(2026, 7, 19, 15),
          DateTime(2026, 7, 18, 9),
        ],
      );
    });

    test('o detalhe da análise é recuperado por completo (RF16)', () async {
      final first = await reopenApp();
      await first.addScanResult(scanAt(DateTime(2026, 7, 20, 8), flagged: true));

      final reopened = await reopenApp();
      final restored = reopened.scanHistory.single;
      expect(restored.hasDangerousIngredients, isTrue);
      expect(restored.flaggedIngredients.single.name, 'Farinha De Trigo');
      expect(restored.flaggedIngredients.single.flagReason,
          'trigo (Doença Celíaca)');
      expect(restored.ingredients.single.relatedDisorder, 'Doença Celíaca');
      expect(restored.rawText, contains('INGREDIENTES'));
    });

    test('exclusão individual e total persistem (RF17)', () async {
      final first = await reopenApp();
      await first.addScanResult(scanAt(DateTime(2026, 7, 20, 8)));
      await first.addScanResult(scanAt(DateTime(2026, 7, 20, 9)));

      final second = await reopenApp();
      await second.removeScanResult(second.scanHistory.first);
      expect((await reopenApp()).scanHistory, hasLength(1));

      await (await reopenApp()).clearHistory();
      expect((await reopenApp()).scanHistory, isEmpty);
    });

    test('o histórico é limitado ao teto configurado', () async {
      final provider = await reopenApp();
      for (var i = 0; i < LocalStore.maxHistoryEntries + 5; i++) {
        await provider.addScanResult(
          scanAt(DateTime(2026, 1, 1).add(Duration(minutes: i))),
        );
      }
      final reopened = await reopenApp();
      expect(reopened.scanHistory, hasLength(LocalStore.maxHistoryEntries));
      // Mantém as mais recentes.
      expect(reopened.scanHistory.first.scannedAt,
          DateTime(2026, 1, 1).add(const Duration(minutes: 204)));
    });
  });

  group('CA08 — consentimento e direito de eliminação', () {
    test('instalação limpa não tem consentimento registrado', () async {
      final provider = await reopenApp();
      expect(provider.isReady, isTrue);
      expect(provider.hasPrivacyConsent, isFalse);
    });

    test('aceite do aviso persiste entre execuções (RNF11)', () async {
      final first = await reopenApp();
      await first.acceptPrivacyNotice(at: DateTime(2026, 7, 22, 12));

      final reopened = await reopenApp();
      expect(reopened.hasPrivacyConsent, isTrue);
      expect(reopened.privacyConsentAt, DateTime(2026, 7, 22, 12));
    });

    test('apagar meus dados remove perfil, histórico, consentimento e arquivo',
        () async {
      final first = await reopenApp();
      await first.acceptPrivacyNotice();
      await first.updateProfile(
        const UserProfile(name: 'Maria', disorders: ['Doença Celíaca']),
      );
      await first.addScanResult(scanAt(DateTime(2026, 7, 20, 10)));

      final file = File('${tempDir.path}/${LocalStore.fileName}');
      expect(await file.exists(), isTrue, reason: 'gravou antes de apagar');

      final second = await reopenApp();
      await second.eraseAllData();

      // Efeito imediato, em memória.
      expect(second.hasProfile, isFalse);
      expect(second.scanHistory, isEmpty);
      expect(second.hasPrivacyConsent, isFalse);

      // Efeito verificável em disco.
      expect(await file.exists(), isFalse);

      // E na reabertura, o app volta ao estado de primeira execução.
      final reopened = await reopenApp();
      expect(reopened.hasProfile, isFalse);
      expect(reopened.scanHistory, isEmpty);
      expect(reopened.hasPrivacyConsent, isFalse);
    });
  });

  group('robustez do armazenamento', () {
    test('arquivo corrompido não impede o boot', () async {
      final file = File('${tempDir.path}/${LocalStore.fileName}');
      await file.writeAsString('{ isto não é json válido');

      final provider = await reopenApp();
      expect(provider.isReady, isTrue);
      expect(provider.hasProfile, isFalse);
      expect(provider.scanHistory, isEmpty);
    });

    test('versão de schema desconhecida é descartada, não interpretada',
        () async {
      final file = File('${tempDir.path}/${LocalStore.fileName}');
      await file.writeAsString(json.encode({
        'schema_version': 999,
        'profile': {'name': 'De outra versão', 'disorders': []},
      }));

      final provider = await reopenApp();
      expect(provider.hasProfile, isFalse);
    });

    test('a gravação usa arquivo temporário e não deixa resíduo', () async {
      final provider = await reopenApp();
      await provider.updateProfile(
        const UserProfile(name: 'Maria', disorders: []),
      );

      final leftovers = tempDir
          .listSync()
          .map((e) => e.path.split(Platform.pathSeparator).last)
          .where((name) => name.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });
}
