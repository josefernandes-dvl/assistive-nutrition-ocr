/// CA03 — em 20 rótulos rotulados manualmente como contendo gatilho do perfil,
///        o sistema sinaliza corretamente em pelo menos 17 casos
///        (recall ≥ 85%), exercitando RF10 + RN01.
///
/// A medição roda o **pipeline completo do app**: texto bruto do OCR →
/// limpeza → extração de ingredientes (RF09) → correção por dicionário (RF24)
/// → correlação com o perfil (RF10/RN01). O corpus fica em
/// `validation/recall_corpus.json`, compartilhado com o backend.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/ingredient.dart';
import 'package:mobile/utils/text_parser.dart';

/// Normaliza como a RN01: minúsculas, sem acento, ç → c.
String _norm(String s) {
  const map = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'í': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ü': 'u', 'ç': 'c',
  };
  final lower = s.toLowerCase();
  final sb = StringBuffer();
  for (final r in lower.runes) {
    final c = String.fromCharCode(r);
    sb.write(map[c] ?? c);
  }
  return sb.toString();
}

/// Um caso conta como corretamente sinalizado quando existe um ingrediente
/// marcado **pelo distúrbio esperado** e esse ingrediente é o que o rótulo foi
/// anotado para conter — identificado pelo gatilho, no nome extraído ou no
/// motivo do alerta.
///
/// Não se exige que o motivo cite exatamente o gatilho anotado: quando dois
/// gatilhos do mesmo distúrbio aparecem no mesmo item (ex.: "shoyu (… grão de
/// soja …)"), a RN01 registra o primeiro que casa. O que importa para o
/// critério é o alerta certo no ingrediente certo.
bool _sinalizouCorretamente(
  List<Ingredient> analisados,
  String gatilho,
  String disturbio,
) {
  final alvo = _norm(gatilho);
  return analisados.any((i) =>
      i.isFlagged &&
      (i.relatedDisorder ?? '').contains(disturbio) &&
      (_norm(i.flagReason ?? '').contains(alvo) || _norm(i.name).contains(alvo)));
}

void main() {
  final corpusFile = File('../validation/recall_corpus.json');
  final corpus =
      json.decode(corpusFile.readAsStringSync()) as Map<String, dynamic>;
  final positivos = (corpus['positivos'] as List).cast<Map<String, dynamic>>();
  final negativos = (corpus['negativos'] as List).cast<Map<String, dynamic>>();

  List<Ingredient> analisar(Map<String, dynamic> caso) {
    final limpo = TextParser.cleanOcrText(caso['raw_text'] as String);
    final nomes = TextParser.extractIngredientNames(limpo);
    return TextParser.analyzeIngredients(
      nomes,
      (caso['disorders'] as List).cast<String>(),
      customAllergens: (caso['custom_allergens'] as List).cast<String>(),
    );
  }

  test('o corpus tem os 20 rótulos positivos exigidos pelo CA03', () {
    expect(positivos, hasLength(20));
  });

  group('CA03 — recall sobre o corpus rotulado', () {
    test('recall ≥ 85% no pipeline completo (OCR → alerta)', () {
      final falhas = <String>[];

      for (final caso in positivos) {
        final analisados = analisar(caso);
        final ok = _sinalizouCorretamente(
          analisados,
          caso['expected_trigger'] as String,
          caso['expected_disorder'] as String,
        );
        if (!ok) {
          falhas.add('${caso['id']} (${caso['produto']}): '
              'esperado "${caso['expected_trigger']}" para '
              '"${caso['expected_disorder']}"; '
              'extraídos: ${analisados.map((i) => i.name).join(" | ")}');
        }
      }

      final acertos = positivos.length - falhas.length;
      final recall = acertos / positivos.length;

      // ignore: avoid_print
      print('CA03 · recall = ${(recall * 100).toStringAsFixed(1)}% '
          '($acertos/${positivos.length} rótulos sinalizados corretamente)');

      expect(
        acertos,
        greaterThanOrEqualTo(17),
        reason: 'recall ${(recall * 100).toStringAsFixed(1)}% '
            '(mínimo 85%). Casos não sinalizados:\n${falhas.join('\n')}',
      );
    });

    test('nenhum rótulo do corpus deixa de ser sinalizado', () {
      // Além do limiar agregado, o corpus atual precisa passar inteiro: a lista
      // completa das falhas aparece de uma vez, não só a primeira.
      final falhas = <String>[];
      for (final caso in positivos) {
        final analisados = analisar(caso);
        if (!_sinalizouCorretamente(analisados,
            caso['expected_trigger'] as String,
            caso['expected_disorder'] as String)) {
          falhas.add('${caso['id']} — ${caso['produto']}: '
              'esperado "${caso['expected_trigger']}"; '
              'extraídos: ${analisados.map((i) => "${i.name}${i.isFlagged ? " [ALERTA]" : ""}").join(" | ")}');
        }
      }
      expect(falhas, isEmpty, reason: '\n${falhas.join('\n')}\n');
    });
  });

  group('controle negativo — especificidade', () {
    test('rótulos sem gatilho do perfil não produzem alerta', () {
      final falsosPositivos = <String>[];

      for (final caso in negativos) {
        final marcados = analisar(caso).where((i) => i.isFlagged);
        if (marcados.isNotEmpty) {
          falsosPositivos.add('${caso['id']} (${caso['produto']}): '
              '${marcados.map((i) => "${i.name} → ${i.flagReason}").join(" | ")}');
        }
      }

      expect(falsosPositivos, isEmpty,
          reason: 'falso positivo em:\n${falsosPositivos.join('\n')}');
    });
  });
}
