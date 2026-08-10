/// CA04 — auditoria de contraste automatizada não retorna violação em nenhuma
///        tela (RF11 + RNF07, WCAG 2.2 AA · 1.4.3).
///
/// São três camadas de verificação:
///   1. a paleta declarada, medida contra os fundos em que é usada;
///   2. cada tela renderizada, medindo texto a texto o que o usuário vê;
///   3. o código-fonte, impedindo que uma cor de preenchimento volte a ser
///      usada como cor de texto numa tela futura.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme.dart';
import 'package:mobile/models/user_profile.dart';
import 'package:mobile/screens/barcode_screen.dart';
import 'package:mobile/screens/history_screen.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/privacy_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/screens/result_screen.dart';

import 'support/contrast.dart';
import 'support/harness.dart';

void main() {
  group('paleta declarada', () {
    // Fundos sólidos sobre os quais texto aparece no app.
    const fundos = <String, Color>{
      'branco (cartões, diálogos)': AppTheme.surfaceWhite,
      'fundo do app': AppTheme.backgroundLight,
    };

    const coresDeTexto = <String, Color>{
      'textPrimary': AppTheme.textPrimary,
      'textSecondary': AppTheme.textSecondary,
      'primaryGreen': AppTheme.primaryGreen,
      'primaryGreenDark': AppTheme.primaryGreenDark,
      'dangerRedText': AppTheme.dangerRedText,
      'accentOrangeDark': AppTheme.accentOrangeDark,
      'safeGreenText': AppTheme.safeGreenText,
    };

    for (final texto in coresDeTexto.entries) {
      for (final fundo in fundos.entries) {
        test('${texto.key} sobre ${fundo.key} atinge 4,5:1', () {
          final ratio = contrastRatio(texto.value, fundo.value);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '${texto.key} rendeu ${ratio.toStringAsFixed(2)}:1');
        });
      }
    }

    test('texto branco sobre os preenchimentos sólidos usados em botões e '
        'banners atinge 4,5:1', () {
      const preenchimentos = <String, Color>{
        'primaryGreen': AppTheme.primaryGreen,
        'primaryGreenDark': AppTheme.primaryGreenDark,
        'dangerRed': AppTheme.dangerRed,
        'dangerRedText': AppTheme.dangerRedText,
        'accentOrangeDark': AppTheme.accentOrangeDark,
      };
      for (final p in preenchimentos.entries) {
        final ratio = contrastRatio(Colors.white, p.value);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'branco sobre ${p.key}: ${ratio.toStringAsFixed(2)}:1');
      }
    });

    test('as cores de preenchimento continuam reprovadas como texto — '
        'é por isso que existem as variantes escuras', () {
      // Documenta a razão da separação de papéis: se alguma destas passasse a
      // atingir 4,5:1, a variante correspondente perderia o sentido.
      for (final fill in [
        AppTheme.accentOrange,
        AppTheme.warningYellow,
        AppTheme.safeGreen,
      ]) {
        expect(contrastRatio(fill, AppTheme.surfaceWhite), lessThan(4.5));
      }
    });
  });

  group('telas renderizadas', () {
    Future<List<ContrastViolation>> audit(
      WidgetTester tester,
      String nome,
      Widget tela, {
      UserProfile? profile,
      bool comHistorico = false,
    }) async {
      useMobileSurface(tester);
      final provider = await memoryProvider(
        profile: profile,
        history: comHistorico
            ? [flaggedScanResult(), safeScanResult()]
            : const [],
      );
      await tester.pumpWidget(wrapApp(tela, provider: provider));
      await tester.pumpAndSettle();
      return auditContrast(tester, nome);
    }

    void semViolacoes(List<ContrastViolation> v) {
      expect(v, isEmpty,
          reason: '\n${v.map((e) => e.toString()).join('\n')}\n');
    }

    testWidgets('Home sem perfil configurado', (tester) async {
      semViolacoes(await audit(tester, 'Home (sem perfil)', const HomeScreen()));
    });

    testWidgets('Home com perfil configurado', (tester) async {
      semViolacoes(await audit(tester, 'Home (com perfil)', const HomeScreen(),
          profile: celiacProfile));
    });

    testWidgets('Perfil', (tester) async {
      semViolacoes(await audit(tester, 'Perfil', const ProfileScreen(),
          profile: celiacProfile));
    });

    testWidgets('Histórico vazio', (tester) async {
      semViolacoes(
          await audit(tester, 'Histórico (vazio)', const HistoryScreen()));
    });

    testWidgets('Histórico com análises', (tester) async {
      semViolacoes(await audit(
        tester,
        'Histórico (com itens)',
        const HistoryScreen(),
        profile: celiacProfile,
        comHistorico: true,
      ));
    });

    testWidgets('Resultado com alertas, produto e aviso de OCR',
        (tester) async {
      semViolacoes(await audit(
        tester,
        'Resultado (com alertas)',
        ResultScreen(
          scanResult: flaggedScanResult(),
          enrichment: sampleEnrichment(),
          traceWarnings: sampleTraceWarnings(),
          lowQualityOcr: true,
        ),
        profile: celiacProfile,
      ));
    });

    testWidgets('Resultado sem alertas', (tester) async {
      semViolacoes(await audit(
        tester,
        'Resultado (sem alertas)',
        ResultScreen(scanResult: safeScanResult()),
        profile: celiacProfile,
      ));
    });

    testWidgets('Aviso de privacidade (primeira execução)', (tester) async {
      semViolacoes(await audit(
          tester, 'Aviso de privacidade', const PrivacyNoticeScreen()));
    });

    testWidgets('Privacidade e dados', (tester) async {
      semViolacoes(await audit(
        tester,
        'Privacidade e dados',
        const PrivacyScreen(),
        profile: celiacProfile,
        comHistorico: true,
      ));
    });

    testWidgets('Código de barras (entrada manual)', (tester) async {
      semViolacoes(
          await audit(tester, 'Código de barras', const BarcodeScreen()));
    });
  });

  group('regressão no código-fonte', () {
    // Cores aprovadas apenas para preenchimento, borda e ícone.
    const proibidasComoTexto = [
      'AppTheme.accentOrange',
      'AppTheme.warningYellow',
      'AppTheme.safeGreen',
      'AppTheme.primaryGreenLight',
    ];

    test('nenhuma cor de preenchimento é usada como cor de texto', () {
      final ofensas = <String>[];

      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();

        for (final trecho in _textStyleBlocks(source)) {
          for (final proibida in proibidasComoTexto) {
            // `AppTheme.safeGreen` casaria dentro de `AppTheme.safeGreenText`;
            // exige-se que o token termine ali.
            final regex = RegExp(
              'color:\\s*${RegExp.escape(proibida)}(?![A-Za-z])',
            );
            if (regex.hasMatch(trecho)) {
              ofensas.add('${file.path}: $proibida dentro de TextStyle(...)');
            }
          }
        }
      }

      expect(ofensas, isEmpty,
          reason: '\nUse a variante de texto correspondente '
              '(dangerRedText, accentOrangeDark, safeGreenText):\n'
              '${ofensas.join('\n')}\n');
    });
  });
}

/// Extrai o conteúdo de cada `TextStyle(...)` do código, respeitando o
/// balanceamento de parênteses.
List<String> _textStyleBlocks(String source) {
  final blocks = <String>[];
  for (final match in RegExp(r'TextStyle\(').allMatches(source)) {
    var depth = 1;
    var i = match.end;
    while (i < source.length && depth > 0) {
      final c = source[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      i++;
    }
    blocks.add(source.substring(match.end, i));
  }
  return blocks;
}
