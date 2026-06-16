import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/ingredient_dictionary.dart';

/// Serviço de OCR de alta performance para desktop (Linux/macOS/Windows).
///
/// Pipeline v3 (paralelo):
///   1. Pré-processa em DUAS variantes: binarizada normal (texto escuro em
///      fundo claro) e binarizada INVERTIDA (texto claro em fundo escuro,
///      como rótulos de plástico colorido).
///   2. Roda Tesseract com 2 PSMs (6 = bloco uniforme, 4 = coluna) em
///      paralelo — 4 chamadas, todas concorrentes.
///   3. Pontua cada resultado pelo dicionário de ingredientes.
///   4. Se o melhor candidato tiver score baixo, lança exceção com sugestão
///      de usar barcode (a foto provavelmente é ruim).
class OcrService {
  /// Score mínimo de termos válidos do dicionário para o resultado ser aceito.
  /// Abaixo disso, considera-se que o OCR falhou (foto ruim).
  static const int _minQualityScore = 2;

  static Future<OcrOutcome> extractText(String imagePath) async {
    try {
      final variants = await _preprocessVariants(imagePath);

      // Fan-out: roda todas as combinações (variante × PSM) em paralelo.
      final futures = <Future<_OcrResult>>[];
      for (final variantPath in variants) {
        for (final psm in const ['6', '4']) {
          futures.add(_runTesseract(variantPath, psm));
        }
      }
      final results = (await Future.wait(futures))
          .where((r) => r.text.trim().isNotEmpty)
          .toList();

      if (results.isEmpty) {
        throw OcrException(
          'O OCR não reconheceu texto na imagem.',
          suggestion:
              'Tente uma foto mais nítida, sem reflexos, enquadrando apenas a '
              'lista de ingredientes — ou use a leitura por código de barras.',
        );
      }

      results.sort((a, b) => b.score.compareTo(a.score));
      final best = results.first;

      return OcrOutcome(
        text: best.text.trim(),
        qualityScore: best.dictMatches,
        isLowQuality: best.dictMatches < _minQualityScore,
      );
    } on ProcessException {
      throw OcrException(
        'Tesseract não encontrado.',
        suggestion: 'Instale com: sudo apt install tesseract-ocr tesseract-ocr-por',
      );
    }
  }

  // ----------- Pipeline de pré-processamento -----------

  static Future<List<String>> _preprocessVariants(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    img.Image? base = img.decodeImage(bytes);
    if (base == null) return [inputPath];

    base = img.bakeOrientation(base);

    if (base.width < 1800) {
      final factor = 1800 / base.width;
      base = img.copyResize(
        base,
        width: (base.width * factor).round(),
        height: (base.height * factor).round(),
        interpolation: img.Interpolation.cubic,
      );
    } else if (base.width > 3500) {
      final factor = 3500 / base.width;
      base = img.copyResize(
        base,
        width: 3500,
        height: (base.height * factor).round(),
        interpolation: img.Interpolation.average,
      );
    }

    img.Image gray = img.grayscale(base);
    gray = img.gaussianBlur(gray, radius: 1);
    gray = img.normalize(gray, min: 0, max: 255);
    gray = _sharpen(gray);

    // Decide se a imagem é majoritariamente clara ou escura para escolher
    // qual variante vai como "principal" e qual como "fallback".
    final isDarkDominant = _meanLuminance(gray) < 128;

    // VARIANTE A: binarização normal (texto escuro em fundo claro)
    final binNormal = img.luminanceThreshold(gray.clone(), threshold: 0.55);

    // VARIANTE B: binarização invertida (texto claro em fundo escuro).
    // Inverte primeiro e depois binariza — equivalente a thresholding "ao contrário".
    final inverted = img.invert(gray.clone());
    final binInverted = img.luminanceThreshold(inverted, threshold: 0.55);

    // Ordena: a variante "esperada" primeiro melhora a chance do early-best.
    final first = isDarkDominant ? binInverted : binNormal;
    final second = isDarkDominant ? binNormal : binInverted;

    return [
      await _saveTemp(first, suffix: isDarkDominant ? 'inv' : 'bin'),
      await _saveTemp(second, suffix: isDarkDominant ? 'bin' : 'inv'),
    ];
  }

  static double _meanLuminance(img.Image image) {
    // Amostra esparsa para não percorrer milhões de pixels
    int sum = 0, count = 0;
    final step = (image.width * image.height ~/ 5000).clamp(1, 1000);
    int idx = 0;
    for (final pixel in image) {
      if (idx % step == 0) {
        sum += pixel.luminance.round();
        count++;
      }
      idx++;
    }
    return count == 0 ? 128 : sum / count;
  }

  static img.Image _sharpen(img.Image src) {
    return img.convolution(
      src,
      filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0],
      div: 1,
    );
  }

  static Future<String> _saveTemp(img.Image image,
      {required String suffix}) async {
    final tmpDir = await getTemporaryDirectory();
    final outPath = p.join(
      tmpDir.path,
      'ocr_${suffix}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await File(outPath).writeAsBytes(img.encodePng(image));
    return outPath;
  }

  // ----------- Execução do Tesseract -----------

  static Future<_OcrResult> _runTesseract(String imagePath, String psm) async {
    final result = await Process.run(
      'tesseract',
      [
        imagePath,
        'stdout',
        '-l', 'por+eng',
        '--oem', '1',
        '--psm', psm,
        '-c', 'preserve_interword_spaces=1',
      ],
    );
    if (result.exitCode != 0) {
      return _OcrResult(text: '', psm: psm, dictMatches: 0);
    }
    final text = result.stdout as String;
    final matches = IngredientDictionary.scoreText(text);
    final alpha = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(text).length;
    // Score: termos válidos pesam muito; comprimento é tiebreaker.
    final score = matches * 100 + alpha;
    return _OcrResult(
      text: text,
      psm: psm,
      dictMatches: matches,
      score: score,
    );
  }

  // ----------- API auxiliar -----------

  static Future<bool> isTesseractAvailable() async {
    try {
      final result = await Process.run('tesseract', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> availableLanguages() async {
    try {
      final result = await Process.run('tesseract', ['--list-langs']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        return lines.skip(1).where((l) => l.trim().isNotEmpty).toList();
      }
    } catch (_) {/* ignore */}
    return [];
  }

  static bool get isDesktopPlatform =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}

class OcrOutcome {
  final String text;
  final int qualityScore;
  final bool isLowQuality;
  const OcrOutcome({
    required this.text,
    required this.qualityScore,
    required this.isLowQuality,
  });
}

class OcrException implements Exception {
  final String message;
  final String suggestion;
  OcrException(this.message, {required this.suggestion});
  @override
  String toString() => '$message\n$suggestion';
}

class _OcrResult {
  final String text;
  final String psm;
  final int dictMatches;
  final int score;
  const _OcrResult({
    required this.text,
    required this.psm,
    required this.dictMatches,
    this.score = 0,
  });
}
