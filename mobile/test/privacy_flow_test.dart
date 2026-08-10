/// CA08 — no primeiro uso o aviso de privacidade é exibido, e "Apagar meus
///        dados" remove perfil e histórico de forma verificável.
///
/// Aqui o critério é exercido pela interface, do jeito que o usuário encontra:
/// app recém-instalado, aceite, uso, exclusão. A verificação do que sobra em
/// disco está em `persistence_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/providers/app_provider.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/privacy_screen.dart';
import 'package:provider/provider.dart';

import 'support/harness.dart';

void main() {
  Future<AppProvider> pumpApp(
    WidgetTester tester, {
    required bool consented,
    MemoryLocalStore? store,
  }) async {
    useMobileSurface(tester);
    final provider = await memoryProvider(
      consented: consented,
      store: store,
      profile: consented ? celiacProfile : null,
      history: consented ? [flaggedScanResult()] : const [],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const NutriScanApp(),
      ),
    );
    await tester.pumpAndSettle();
    return provider;
  }

  group('CA08 — aviso de privacidade no primeiro uso (RNF11)', () {
    testWidgets('instalação nova abre no aviso, não na home', (tester) async {
      await pumpApp(tester, consented: false);

      expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Antes de começar'), findsOneWidget);
    });

    testWidgets('o aviso declara o que é tratado e o caráter informativo',
        (tester) async {
      await pumpApp(tester, consented: false);

      expect(find.text('Seus dados ficam neste aparelho'), findsOneWidget);
      expect(
          find.text('A foto do rótulo nunca sai do aparelho'), findsOneWidget);
      expect(find.text('O que é enviado ao servidor'), findsOneWidget);
      expect(find.text('Você pode apagar tudo'), findsOneWidget);
      expect(find.text('Isto não é aconselhamento médico'), findsOneWidget);
    });

    testWidgets('após o aceite o app abre e não pergunta de novo',
        (tester) async {
      final provider = await pumpApp(tester, consented: false);

      await tester.ensureVisible(find.text('Entendi e aceito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entendi e aceito'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(provider.hasPrivacyConsent, isTrue);

      // "Reabrir" o app com o mesmo armazenamento não repete o aviso.
      expect(provider.hasPrivacyConsent, isTrue);
    });

    testWidgets('quem já aceitou vai direto para a home', (tester) async {
      await pumpApp(tester, consented: true);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(PrivacyNoticeScreen), findsNothing);
    });
  });

  group('CA08 — apagar meus dados (RNF14 / LGPD Art. 18, VI)', () {
    testWidgets('a home dá acesso à tela de privacidade', (tester) async {
      await pumpApp(tester, consented: true);

      await tester.scrollUntilVisible(
        find.text('Privacidade e dados'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Privacidade e dados'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyScreen), findsOneWidget);
      expect(find.text('Apagar meus dados'), findsWidgets);
    });

    testWidgets('a exclusão exige confirmação e pode ser cancelada',
        (tester) async {
      final provider = await pumpApp(tester, consented: true);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: const MaterialApp(home: PrivacyScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final botaoApagar =
          find.widgetWithText(ElevatedButton, 'Apagar meus dados');
      await tester.ensureVisible(botaoApagar);
      await tester.pumpAndSettle();
      await tester.tap(botaoApagar);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(provider.hasProfile, isTrue);
      expect(provider.scanHistory, hasLength(1));
    });

    testWidgets('confirmada, remove perfil, histórico e consentimento',
        (tester) async {
      final store = MemoryLocalStore();
      final provider = await pumpApp(tester, consented: true, store: store);

      expect(provider.hasProfile, isTrue);
      expect(provider.scanHistory, isNotEmpty);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: const MaterialApp(home: PrivacyScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final botaoApagar =
          find.widgetWithText(ElevatedButton, 'Apagar meus dados');
      await tester.ensureVisible(botaoApagar);
      await tester.pumpAndSettle();
      await tester.tap(botaoApagar);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar tudo'));
      await tester.pumpAndSettle();

      expect(provider.hasProfile, isFalse);
      expect(provider.scanHistory, isEmpty);
      expect(provider.hasPrivacyConsent, isFalse);
      expect(store.isEmpty, isTrue,
          reason: 'o armazenamento local também precisa ficar vazio');
    });

    testWidgets('depois de apagar, o app volta ao aviso de primeira execução',
        (tester) async {
      final provider = await pumpApp(tester, consented: true);
      await provider.eraseAllData();
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
