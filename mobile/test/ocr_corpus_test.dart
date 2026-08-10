/// CA02 — em 10 imagens-teste de rótulos, o OCR retorna texto não vazio em
///        pelo menos 9 casos (RF05 + RF07).
/// CA07 — em 20 medições, a mediana do tempo de OCR fica em até 5 s (RNF01).
///
/// O corpus está em `validation/labels/` e é regenerável por
/// `validation/tools/generate_label_images.sh`.
///
/// **Limite de validade da medição.** O teste roda o motor disponível no
/// ambiente de execução. Em Linux/CI isso é o Tesseract (motor de
/// desenvolvimento, ADR-009); o motor de produção é o Google ML Kit, que só
/// existe em Android/iOS. O tempo medido aqui, portanto, caracteriza o
/// pipeline de desktop — não o aparelho Android de referência do RNF01. O
/// resultado é impresso com a identificação do motor para que o relatório
/// nunca seja lido como medição de celular.
@Tags(['ocr'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/ocr_service.dart';
import 'package:mobile/utils/text_parser.dart';

const _corpusDir = '../validation/labels';

/// Quantas medições o CA07 exige.
const _amostrasCA07 = 20;

String _norm(String s) {
  const map = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'é': 'e', 'ê': 'e', 'í': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o', 'ú': 'u', 'ü': 'u', 'ç': 'c',
  };
  final sb = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    sb.write(map[c] ?? c);
  }
  return sb.toString();
}

void main() {
  final manifest = json.decode(
    File('$_corpusDir/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final imagens = (manifest['imagens'] as List).cast<Map<String, dynamic>>();

  late bool ocrDisponivel;

  setUpAll(() async {
    ocrDisponivel = await OcrService.isOcrAvailable();
    if (!ocrDisponivel) {
      // ignore: avoid_print
      print('CA02/CA07 · motor de OCR indisponível neste ambiente '
          '(${OcrService.engineName()}) — medição não executada.');
    }
  });

  test('o corpus tem ao menos as 10 imagens exigidas pelo CA02', () {
    expect(imagens.length, greaterThanOrEqualTo(10));
    for (final img in imagens) {
      expect(File('$_corpusDir/${img['arquivo']}').existsSync(), isTrue,
          reason: '${img['arquivo']} ausente — rode '
              'validation/tools/generate_label_images.sh');
    }
  });

  test('CA02 — o OCR retorna texto não vazio em pelo menos 90% das imagens',
      () async {
    if (!ocrDisponivel) {
      markTestSkipped('motor de OCR indisponível');
      return;
    }

    final vazias = <String>[];
    final semIngrediente = <String>[];
    var comGatilhoCorreto = 0;

    for (final img in imagens) {
      final caminho = '$_corpusDir/${img['arquivo']}';
      String texto = '';
      try {
        texto = (await OcrService.extractText(caminho)).text;
      } on OcrException {
        texto = '';
      }

      if (texto.trim().isEmpty) {
        vazias.add(img['arquivo'] as String);
        continue;
      }

      // Métrica complementar: texto não vazio é o mínimo; o que interessa ao
      // usuário é o rótulo render ingrediente utilizável e o alerta certo.
      final nomes =
          TextParser.extractIngredientNames(TextParser.cleanOcrText(texto));
      if (nomes.isEmpty) {
        semIngrediente.add(img['arquivo'] as String);
        continue;
      }

      final disorders = (img['disorders'] as List).cast<String>();
      final analisados = TextParser.analyzeIngredients(nomes, disorders);
      // Mesmo critério do CA03: o que conta é o alerta certo para o distúrbio
      // certo. Quando dois gatilhos do mesmo distúrbio estão no mesmo item
      // ("malte de cevada"), a RN01 registra o primeiro que casa.
      final gatilho = _norm(img['expected_trigger'] as String);
      if (analisados.any((i) =>
          i.isFlagged &&
          disorders.any((d) => (i.relatedDisorder ?? '').contains(d)) &&
          (_norm(i.flagReason ?? '').contains(gatilho) ||
              _norm(i.name).contains(gatilho)))) {
        comGatilhoCorreto++;
      }
    }

    final total = imagens.length;
    final comTexto = total - vazias.length;
    final comIngredientes = comTexto - semIngrediente.length;

    // ignore: avoid_print
    print('CA02 · motor ${OcrService.engineName()} · '
        'texto não vazio: $comTexto/$total '
        '(${(comTexto / total * 100).toStringAsFixed(1)}%) · '
        'com ingrediente extraído: $comIngredientes/$total · '
        'com alerta correto: $comGatilhoCorreto/$total');

    expect(
      comTexto / total,
      greaterThanOrEqualTo(0.9),
      reason: 'imagens sem texto reconhecido: ${vazias.join(", ")}',
    );

    // O critério pede apenas texto não vazio. Como isso sozinho não diz nada
    // sobre utilidade, o corpus também fixa o que importa ao usuário: o rótulo
    // render ingrediente e o alerta correto. Uma regressão que devolva ruído
    // legível passaria no primeiro limiar e falharia aqui.
    expect(comIngredientes / total, greaterThanOrEqualTo(0.9),
        reason: 'imagens sem ingrediente extraído: '
            '${semIngrediente.join(", ")}');
    expect(comGatilhoCorreto / total, greaterThanOrEqualTo(0.85),
        reason: 'apenas $comGatilhoCorreto de $total geraram o alerta '
            'esperado pelo manifesto');
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('CA07 — a mediana do tempo de OCR fica em até 5 s em 20 medições',
      () async {
    if (!ocrDisponivel) {
      markTestSkipped('motor de OCR indisponível');
      return;
    }

    final medidas = <int>[];
    for (var i = 0; i < _amostrasCA07; i++) {
      final img = imagens[i % imagens.length];
      final caminho = '$_corpusDir/${img['arquivo']}';
      final relogio = Stopwatch()..start();
      try {
        await OcrService.extractText(caminho);
      } on OcrException {
        // Falha de leitura também consome tempo: entra na amostra.
      }
      relogio.stop();
      medidas.add(relogio.elapsedMilliseconds);
    }

    medidas.sort();
    final mediana = medidas.length.isOdd
        ? medidas[medidas.length ~/ 2]
        : ((medidas[medidas.length ~/ 2 - 1] + medidas[medidas.length ~/ 2]) / 2)
            .round();
    final p95 = medidas[(medidas.length * 0.95).floor().clamp(0, medidas.length - 1)];

    // ignore: avoid_print
    print('CA07 · motor ${OcrService.engineName()} em ${Platform.operatingSystem} · '
        '${medidas.length} medições · '
        'mediana ${(mediana / 1000).toStringAsFixed(2)}s · '
        'mín ${(medidas.first / 1000).toStringAsFixed(2)}s · '
        'máx ${(medidas.last / 1000).toStringAsFixed(2)}s · '
        'p95 ${(p95 / 1000).toStringAsFixed(2)}s');

    expect(medidas, hasLength(_amostrasCA07));
    expect(
      mediana,
      lessThanOrEqualTo(5000),
      reason: 'mediana ${(mediana / 1000).toStringAsFixed(2)}s acima de 5s',
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}
