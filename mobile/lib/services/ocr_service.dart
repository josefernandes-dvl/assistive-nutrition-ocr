import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/ingredient_dictionary.dart';

/// Serviço de OCR multiplataforma.
///
/// - **Mobile (Android/iOS)**: usa `google_mlkit_text_recognition` (on-device,
///   gratuito, offline). É a engine recomendada para release.
/// - **Desktop (Linux/macOS/Windows)**: usa Tesseract CLI com pipeline próprio
///   de pré-processamento. Útil só para desenvolvimento — não roda em release
///   mobile.
class OcrService {
  /// Score mínimo de termos válidos do dicionário para considerar a qualidade
  /// "alta". Abaixo disso, o OCR ainda é entregue ao app mas marcado como
  /// baixa qualidade — a UI mostra um aviso, sem bloquear a análise.
  static const int _minQualityScore = 1;

  /// Roteia para o engine apropriado conforme a plataforma.
  static Future<OcrOutcome> extractText(String imagePath) {
    if (Platform.isAndroid || Platform.isIOS) {
      return _extractMobile(imagePath);
    }
    return _extractDesktop(imagePath);
  }

  /// Retorna true se o OCR estiver pronto para uso na plataforma atual.
  /// - Em mobile, ML Kit está sempre disponível (modelo bundle).
  /// - Em desktop, verifica se o binário Tesseract existe no PATH.
  static Future<bool> isOcrAvailable() {
    if (Platform.isAndroid || Platform.isIOS) return Future.value(true);
    return _isTesseractAvailable();
  }

  /// Nome legível da engine atual (para exibir na UI).
  static String engineName() {
    if (Platform.isAndroid || Platform.isIOS) return 'Google ML Kit';
    return 'Tesseract';
  }

  // ============================================================
  // MOBILE — Google ML Kit Text Recognition
  // ============================================================

  static Future<OcrOutcome> _extractMobile(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      final text = result.text.trim();

      if (text.isEmpty) {
        throw OcrException(
          'O OCR não reconheceu texto na imagem.',
          suggestion:
              'Tente uma foto mais nítida, sem reflexos, enquadrando apenas a '
              'lista de ingredientes — ou use a leitura por código de barras.',
        );
      }

      final matches = IngredientDictionary.scoreText(text);
      return OcrOutcome(
        text: text,
        qualityScore: matches,
        isLowQuality: matches < _minQualityScore,
      );
    } finally {
      await recognizer.close();
    }
  }

  // ============================================================
  // DESKTOP — Tesseract CLI com pipeline próprio
  // ============================================================

  static Future<OcrOutcome> _extractDesktop(String imagePath) async {
    try {
      // 1. Imagem como veio. O Tesseract já faz binarização adaptativa (Otsu)
      //    internamente e, em rótulo bem iluminado, ela supera qualquer
      //    pré-processamento fixo — a mesma constatação que levou à remoção do
      //    pré-processamento manual no caminho mobile (RF08).
      final results = await _runVariant(imagePath);

      // 2. Só quando a leitura direta não reconhece nenhum termo do dicionário
      //    vale pagar o custo do pipeline de resgate (upscale, normalização,
      //    binarização dupla), que existe para rótulo escuro ou de baixo
      //    contraste.
      if (results.isEmpty || results.first.dictMatches == 0) {
        for (final variante in await _preprocessVariants(imagePath)) {
          results.addAll(await _runVariant(variante));
        }
        results.sort((a, b) => b.score.compareTo(a.score));
      }

      if (results.isEmpty) {
        throw OcrException(
          'O OCR não reconheceu texto na imagem.',
          suggestion:
              'Tente uma foto mais nítida com boa iluminação difusa — ou use '
              'a leitura por código de barras.',
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

  /// Roda os dois modos de segmentação do Tesseract sobre uma variante,
  /// devolvendo os resultados não vazios, do melhor para o pior.
  static Future<List<_TesseractResult>> _runVariant(String variantPath) async {
    final results = await Future.wait(
      const ['6', '4'].map((psm) => _runTesseract(variantPath, psm)),
    );
    final uteis = results.where((r) => r.text.trim().isNotEmpty).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return uteis;
  }

  static Future<List<String>> _preprocessVariants(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    img.Image? base = img.decodeImage(bytes);
    if (base == null) return [inputPath];

    // Normaliza para 3 canais antes de qualquer cálculo de luminância.
    // Numa imagem de 1 canal (PNG/JPEG salvo em escala de cinza), os canais
    // verde e azul valem zero, e a luminância fica presa em ~30% do valor
    // real — o que fazia a binarização devolver uma imagem inteiramente preta
    // e o OCR não reconhecer nada. Regressão coberta por ocr_corpus_test.dart.
    if (base.numChannels < 3) {
      base = base.convert(numChannels: 3);
    }

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

    final isDarkDominant = _meanLuminance(gray) < 128;
    final binNormal = img.luminanceThreshold(gray.clone(), threshold: 0.55);
    final inverted = img.invert(gray.clone());
    final binInverted = img.luminanceThreshold(inverted, threshold: 0.55);

    final first = isDarkDominant ? binInverted : binNormal;
    final second = isDarkDominant ? binNormal : binInverted;

    return [
      await _saveTemp(first, suffix: isDarkDominant ? 'inv' : 'bin'),
      await _saveTemp(second, suffix: isDarkDominant ? 'bin' : 'inv'),
    ];
  }

  static double _meanLuminance(img.Image image) {
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

  /// Diretório temporário para os arquivos intermediários do pré-processamento.
  ///
  /// `path_provider` depende de plugin de plataforma; em execução sem plugin
  /// registrado (harness de teste e benchmark do CA02/CA07) ele lança. Nesse
  /// caso cai no temporário do sistema, que serve igualmente bem para um
  /// arquivo descartável.
  static Future<Directory> _tempDirectory() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  static Future<String> _saveTemp(img.Image image,
      {required String suffix}) async {
    final tmpDir = await _tempDirectory();
    final outPath = p.join(
      tmpDir.path,
      'ocr_${suffix}_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await File(outPath).writeAsBytes(img.encodePng(image));
    return outPath;
  }

  static Future<_TesseractResult> _runTesseract(
      String imagePath, String psm) async {
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
      return _TesseractResult(text: '', psm: psm, dictMatches: 0);
    }
    final text = result.stdout as String;
    final matches = IngredientDictionary.scoreText(text);
    final alpha = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(text).length;
    return _TesseractResult(
      text: text,
      psm: psm,
      dictMatches: matches,
      score: matches * 100 + alpha,
    );
  }

  static Future<bool> _isTesseractAvailable() async {
    try {
      final result = await Process.run('tesseract', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
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

class _TesseractResult {
  final String text;
  final String psm;
  final int dictMatches;
  final int score;
  const _TesseractResult({
    required this.text,
    required this.psm,
    required this.dictMatches,
    this.score = 0,
  });
}
