/// Suíte de pares para a RN01 (marcação de ingrediente como gatilho).
///
///   - CA11: ausência de falso positivo por substring (`salsa` ≠ `sal`).
///   - CA16: gatilho no singular casando com a forma flexionada do rótulo
///           (`trigo` → `trigos`).
///
/// Espelhada em backend/test/matching.test.js — a regra vale nas duas camadas.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/text_parser.dart';

/// Testa o matcher isoladamente: um ingrediente, um gatilho (via alérgeno
/// personalizado, que aceita termo arbitrário).
bool matches(String labelText, String trigger) {
  final result = TextParser.analyzeIngredients(
    [labelText],
    const [],
    customAllergens: [trigger],
  );
  return result.single.isFlagged;
}

void main() {
  group('CA11 — sem falso positivo por substring', () {
    const traps = <List<String>>[
      ['salsa', 'sal'],
      ['salsicha', 'sal'],
      ['novo', 'ovo'],
      ['renovo', 'ovo'],
      ['melancia', 'mel'],
      ['caramelo', 'mel'],
      ['trigonometria', 'trigo'],
      ['natal', 'nata'],
      ['gemada', 'gema'],
      ['maltodextrina', 'malte'],
      ['cebolinha', 'cebola'],
      ['tomatada', 'tomate'],
    ];

    for (final pair in traps) {
      test('"${pair[1]}" não casa dentro de "${pair[0]}"', () {
        expect(matches(pair[0], pair[1]), isFalse);
      });
    }

    test('perfil com Alergia ao Ovo não marca "Sabor novo"', () {
      final r = TextParser.analyzeIngredients(
        ['Sabor novo', 'Renovo'],
        const ['Alergia ao Ovo'],
      );
      expect(r.where((i) => i.isFlagged), isEmpty);
    });
  });

  group('CA16 — flexão de número', () {
    const plurals = <List<String>>[
      ['trigos', 'trigo'],
      ['leites', 'leite'],
      ['ovos', 'ovo'],
      ['queijos', 'queijo'],
      ['cebolas', 'cebola'],
      ['alhos', 'alho'],
      ['corantes artificiais', 'corante artificial'],
      ['farinhas de trigo', 'farinha de trigo'],
      ['claras de ovo', 'clara de ovo'],
      ['alcoois', 'alcool'],
      ['conservantes', 'conservante'],
      ['gorduras trans', 'gordura trans'],
    ];

    for (final pair in plurals) {
      test('"${pair[1]}" casa com "${pair[0]}"', () {
        expect(matches(pair[0], pair[1]), isTrue);
      });
    }

    test('plural no rótulo dispara alerta de Doença Celíaca', () {
      final r = TextParser.analyzeIngredients(
        ['Farinhas de trigos enriquecidas', 'Açúcar'],
        const ['Doença Celíaca'],
      );
      final flagged = r.where((i) => i.isFlagged).toList();
      expect(flagged, hasLength(1));
      expect(flagged.first.flagReason, contains('trigo'));
    });

    test('plural também vale para avisos de traços (RF23)', () {
      final terms = TextParser.extractTraceWarnings(
        'PODE CONTER AMENDOINS E DERIVADOS DE LEITES.',
      );
      final warnings = TextParser.analyzeTraces(
        terms,
        const ['Alergia ao Amendoim', 'Intolerância à Lactose'],
      );
      expect(warnings, isNotEmpty);
      expect(
        warnings.expand((w) => w.disorders),
        contains('Alergia ao Amendoim'),
      );
    });

    test('formas geradas seguem as regras regulares do português', () {
      expect(TextParser.inflectionForms('de'), ['de']);
      expect(TextParser.inflectionForms('arachis'), ['arachis']);
      expect(TextParser.inflectionForms('trigo')..sort(), ['trigo', 'trigos']);
      expect(TextParser.inflectionForms('alcool')..sort(), ['alcoois', 'alcool']);
    });
  });

  group('CA14 — correção de erro de OCR por dicionário (RF24)', () {
    List<String> extrair(String rotulo) =>
        TextParser.extractIngredientNames('INGREDIENTES: $rotulo.');

    test('troca de uma letra é corrigida e dispara o alerta', () {
      expect(extrair('giúten'), ['glúten']);
      expect(extrair('1eite'), ['leite']);
      expect(extrair('FAR1NHA DE TR1GO'), ['farinha de trigo']);
      expect(extrair('S0JA'), ['soja']);

      final r = TextParser.analyzeIngredients(
        extrair('FAR1NHA DE TR1GO'),
        const ['Doença Celíaca'],
      );
      expect(r.single.isFlagged, isTrue);
    });

    test('palavra legítima do português não é reescrita como gatilho', () {
      // "sorbato" fica a duas edições de "sorbitol" e "ácido" a uma de
      // "amido": corrigir aqui inventaria um alerta que o rótulo não tem.
      expect(extrair('conservador sorbato de potássio'),
          ['conservador sorbato de potássio']);
      expect(extrair('ácido fólico'), ['ácido fólico']);

      final r = TextParser.analyzeIngredients(
        extrair('CONSERVADOR SORBATO DE POTÁSSIO'),
        const ['Síndrome do Intestino Irritável (SII)', 'FODMAP Sensível'],
      );
      expect(r.single.isFlagged, isFalse,
          reason: 'sorbato de potássio não é sorbitol');
    });
  });

  group('normalização de acentos', () {
    test('gatilho sem acento casa com rótulo acentuado', () {
      expect(matches('Glúten de trigo', 'gluten'), isTrue);
      expect(matches('Proteína de soja', 'proteina de soja'), isTrue);
      expect(matches('Álcoois', 'alcool'), isTrue);
    });
  });

  // Regressão do pão Pullman (foto deitada): o OCR perdeu o prefixo
  // "Ingredientes:" e o rodapé do fabricante (endereço, CNPJ) foi extraído como
  // ingrediente ("Rua Érico Veríssimo", "Jardim Cambará").
  group('metadados do rótulo não viram ingredientes', () {
    test('endereço, CNPJ e registro do fabricante são descartados', () {
      final r = TextParser.extractIngredientNames(
        'Fabricado em BIMBO DO BRASIL LTDA. 100 (SP1) NP: 35402 759 0001-85 - '
        'Rua Érico Veríssimo, 342, Jardim Cambará, CEP 05560-900.',
      );
      final joined = r.join(' | ').toLowerCase();
      expect(joined.contains('rua'), isFalse);
      expect(joined.contains('jardim'), isFalse);
      expect(joined.contains('ltda'), isFalse);
      expect(joined.contains('cep'), isFalse);
      expect(joined.contains('35402') || joined.contains('verissimo'), isFalse);
    });

    test('ingredientes reais (e código INS de aditivo) não são descartados',
        () {
      final r = TextParser.extractIngredientNames(
        'INGREDIENTES: FARINHA DE TRIGO ENRIQUECIDA COM FERRO E ÁCIDO FÓLICO, '
        'AÇÚCAR, ÓLEO VEGETAL DE GIRASSOL, GLÚTEN, SAL, PROTEÍNA VEGETAL, '
        'AMIDO MODIFICADO (INS 1442), CONSERVADOR BENZOATO DE SÓDIO.',
      );
      final joined = r.join(' | ').toLowerCase();
      expect(joined.contains('trigo'), isTrue);
      expect(joined.contains('glúten') || joined.contains('gluten'), isTrue);
      // "AMIDO MODIFICADO (INS 1442)" — o INS de 4 dígitos não pode ser tratado
      // como metadado; o ingrediente sobrevive.
      expect(joined.contains('amido'), isTrue);
      expect(r.length, greaterThanOrEqualTo(6));
    });
  });

  // Regressão do caso Velly (pipoca): o rótulo declara "CONTÉM GLÚTEN", mas o
  // app só reconhecia "pode conter / traços" e descartava a declaração direta
  // junto com o marcador de fim da lista — deixando um celíaco sem alerta.
  group('declaração direta "Contém X" (presença efetiva)', () {
    const rotuloVelly =
        'INGREDIENTES: MILHO DE PIPOCA, GORDURA VEGETAL, SAL. '
        'ALÉRGICOS: CONTÉM DERIVADOS DE SOJA. PODE CONTER LEITE E TRIGO. '
        'CONTÉM GLÚTEN.';

    test('"CONTÉM GLÚTEN" gera alerta para Doença Celíaca', () {
      final terms = TextParser.extractContainsDeclarations(rotuloVelly);
      final decls = TextParser.analyzeContains(terms, const ['Doença Celíaca']);
      expect(decls, isNotEmpty);
      expect(decls.expand((d) => d.disorders), contains('Doença Celíaca'));
    });

    test('"NÃO CONTÉM GLÚTEN" NÃO gera alerta (declaração de ausência)', () {
      // Caso oposto e crítico: um falso positivo aqui marcaria como perigoso
      // justamente o produto seguro para o celíaco.
      final terms = TextParser.extractContainsDeclarations(
        'PRODUTO SEM GLÚTEN. NÃO CONTÉM GLÚTEN.',
      );
      final decls = TextParser.analyzeContains(terms, const ['Doença Celíaca']);
      expect(decls, isEmpty);
    });

    test('"CONTÉM LEITE E OVOS" afeta Intolerância à Lactose', () {
      final terms = TextParser.extractContainsDeclarations('CONTÉM LEITE E OVOS.');
      final decls = TextParser.analyzeContains(
        terms,
        const ['Intolerância à Lactose'],
      );
      expect(decls.expand((d) => d.disorders), contains('Intolerância à Lactose'));
    });

    test('soja declarada não alerta quem não monitora soja', () {
      final terms =
          TextParser.extractContainsDeclarations('CONTÉM DERIVADOS DE SOJA.');
      final decls = TextParser.analyzeContains(terms, const ['Doença Celíaca']);
      expect(decls, isEmpty);
    });

    test('"pode conter" e "contém traços de" seguem como traço, não presença', () {
      expect(
        TextParser.extractContainsDeclarations('PODE CONTER TRIGO.'),
        isEmpty,
      );
      expect(
        TextParser.extractContainsDeclarations('CONTÉM TRAÇOS DE AMENDOIM.'),
        isEmpty,
      );
      // ...mas continuam sendo captados pela via de traços.
      expect(TextParser.extractTraceWarnings('PODE CONTER TRIGO.'), isNotEmpty);
      expect(
        TextParser.extractTraceWarnings('CONTÉM TRAÇOS DE AMENDOIM.'),
        isNotEmpty,
      );
    });
  });
}
