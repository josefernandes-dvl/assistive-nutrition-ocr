import '../core/constants.dart';
import '../core/ingredient_dictionary.dart';
import '../models/ingredient.dart';

class TextParser {
  static final RegExp _prefixRegex = RegExp(
    r'\b(ingredientes?|composi[cç][aã]o|conte[uú]do|contains|ingredients)\s*[:\-]?\s*',
    caseSensitive: false,
  );

  static final List<RegExp> _endMarkers = [
    RegExp(r'informa[cç][aã]o\s+nutricional', caseSensitive: false),
    RegExp(r'tabela\s+nutricional', caseSensitive: false),
    RegExp(r'valor(?:es)?\s+(?:energ[eé]tico|nutricional)', caseSensitive: false),
    RegExp(r'nutrition\s+facts', caseSensitive: false),
    RegExp(r'al[eé]rg[eê]nicos?\s*[:\-]?', caseSensitive: false),
    RegExp(r'cont[eé]m\s+(?:gl[uú]ten|lactose|derivados)', caseSensitive: false),
    RegExp(r'pode\s+conter', caseSensitive: false),
    RegExp(r'al[eé]rgicos?\s*[:\-]', caseSensitive: false),
    RegExp(r'conservar\s+(?:em|sob)', caseSensitive: false),
    RegExp(r'validade', caseSensitive: false),
    RegExp(r'fabricado\s+por', caseSensitive: false),
    RegExp(r'ind[uú]stria\s+brasileira', caseSensitive: false),
    RegExp(r'modo\s+de\s+preparo', caseSensitive: false),
    RegExp(r'lote\s*[:\-]?', caseSensitive: false),
    RegExp(r'sac\s+(?:n[ºo°]?|n[uú]mero)', caseSensitive: false),
  ];

  /// Regex que captura a seção de "Contém traços / Pode conter".
  /// Ex.: "CONTÉM TRAÇOS DE LEITE E AMENDOIM", "PODE CONTER SOJA, OVOS".
  static final RegExp _tracesRegex = RegExp(
    r'(?:cont[eé]m\s+tra[cç]os?\s+de|pode\s+conter|cont[eé]m\s+derivados\s+de)\s*[:\-]?\s*([^.\n]{1,200})',
    caseSensitive: false,
  );

  /// Extrai a lista de avisos de traços ("contém traços de X, Y").
  /// Retorna os termos individuais já normalizados (split por vírgula/"e").
  static List<String> extractTraceWarnings(String rawText) {
    final result = <String>[];
    final matches = _tracesRegex.allMatches(rawText);
    for (final m in matches) {
      final raw = (m.group(1) ?? '').trim();
      // Divide por vírgula ou conector " e "
      final parts = raw.split(RegExp(r',|\be\b', caseSensitive: false));
      for (final p in parts) {
        final cleaned = p.trim().replaceAll(RegExp(r'[\.;:\-]+$'), '').trim();
        if (cleaned.isNotEmpty && cleaned.length < 60) {
          result.add(cleaned);
        }
      }
    }
    return result;
  }

  /// Extrai lista de nomes de ingredientes a partir do texto bruto do OCR
  static List<String> extractIngredientNames(String rawText) {
    String text = rawText;

    // 1. Localiza o início da lista de ingredientes (prefixo)
    final prefixMatch = _prefixRegex.firstMatch(text);
    if (prefixMatch != null) {
      text = text.substring(prefixMatch.end);
    }

    // 2. Corta o texto no primeiro marcador de fim encontrado
    int cutAt = text.length;
    for (final marker in _endMarkers) {
      final m = marker.firstMatch(text);
      if (m != null && m.start < cutAt) {
        cutAt = m.start;
      }
    }
    text = text.substring(0, cutAt);

    // 3. Junta linhas quebradas no meio (hifenização do OCR)
    text = text.replaceAll(RegExp(r'-\s*\n'), '');
    text = text.replaceAll(RegExp(r'\s*\n\s*'), ' ');

    // 4. Divide por separadores principais. Preserva conteúdo entre parênteses
    //    como um único token (ex.: "estabilizantes (INS 412, INS 415)").
    final parts = _splitRespectingParens(text);

    // 5. Limpa cada parte
    final cleaned = parts
        .map(_cleanIngredientName)
        .where(_isLikelyIngredient)
        .toList();

    // 6. Correção fuzzy: tenta substituir cada item pelo termo canônico mais
    //    próximo no dicionário (corrige erros típicos de OCR).
    return cleaned.map(_applyFuzzyCorrection).toList();
  }

  /// Aplica correção fuzzy a um nome de ingrediente.
  /// Primeiro tenta casar a string inteira; se não houver match, tenta
  /// substituir palavra a palavra (preserva contexto como "óleo vegetal").
  static String _applyFuzzyCorrection(String ingredient) {
    final normalizedFull = _normalizeForMatching(ingredient);

    // 1. Match da string inteira (cobre "farinha de trigo enriquecida"
    //    direto contra o dicionário sem precisar quebrar em palavras).
    final fullMatch = IngredientDictionary.bestMatch(
      normalizedFull,
      maxDistance: 3,
      maxRelative: 0.25,
    );
    if (fullMatch != null) return fullMatch;

    // 2. Match palavra a palavra, restrito a palavras com evidência de erro
    //    de leitura (ver `_temEvidenciaDeErroDeOcr`).
    final words = ingredient.split(RegExp(r'\s+'));
    final corrected = words.map((w) {
      // Preserva pontuação de borda: "(leite," corrige o miolo, não o resto.
      final core = w.replaceAll(RegExp(r'^[^\wÀ-ÿ]+|[^\wÀ-ÿ]+$'), '');
      if (core.length < 4) return w; // palavras curtas: não corrige
      if (!_temEvidenciaDeErroDeOcr(core)) return w;

      final match = IngredientDictionary.bestMatch(
        _normalizeForMatching(core),
        maxDistance: 2,
        maxRelative: 0.25,
      );
      return match == null ? w : w.replaceFirst(core, match);
    }).join(' ');

    return corrected;
  }

  /// Uma palavra isolada só é reescrita quando traz sinal de leitura errada —
  /// na prática, um dígito no meio de letras (`far1nha`, `1eite`, `s0ja`), que
  /// é o erro típico do OCR em rótulo impresso.
  ///
  /// Sem esse filtro, qualquer palavra do português a duas edições de um termo
  /// do dicionário virava aquele termo: `sorbato de potássio` (um conservante
  /// inofensivo) era reescrito como **sorbitol** e disparava alerta de FODMAP,
  /// e `ácido fólico` virava `amido fólico`. Inventar ingrediente num app de
  /// segurança alimentar é pior do que deixar de corrigir uma letra: a
  /// expressão inteira ainda é comparada com o dicionário no passo 1, que
  /// cobre os casos reais de troca de letra (`giúten` → `glúten`).
  static bool _temEvidenciaDeErroDeOcr(String word) {
    return RegExp(r'[0-9]').hasMatch(word);
  }

  static List<String> _splitRespectingParens(String text) {
    final result = <String>[];
    final buffer = StringBuffer();
    int depth = 0;
    for (final r in text.runes) {
      final c = String.fromCharCode(r);
      if (c == '(' || c == '[') {
        depth++;
        buffer.write(c);
      } else if (c == ')' || c == ']') {
        if (depth > 0) depth--;
        buffer.write(c);
      } else if (depth == 0 && (c == ',' || c == ';' || c == '.')) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    if (buffer.isNotEmpty) result.add(buffer.toString());
    return result;
  }

  static String _cleanIngredientName(String raw) {
    String s = raw.trim();
    // Remove percentuais e quantidades no início/fim (ex.: "açúcar 25%")
    s = s.replaceAll(RegExp(r'\b\d+[\.,]?\d*\s*(?:%|g|mg|kg|ml|l|kcal|kj)\b',
        caseSensitive: false), '');
    // Remove códigos INS/E isolados (mantém quando agregados ao nome)
    s = s.replaceAll(RegExp(r'\b(?:ins|e)\s*\d+[a-z]?\b', caseSensitive: false), '');
    // Remove caracteres de bullet, asteriscos e estranhos
    s = s.replaceAll(RegExp(r'[\*•·◦●▪►»]+'), ' ');
    // Colapsa parênteses vazios
    s = s.replaceAll(RegExp(r'\(\s*\)'), '');
    // Normaliza espaços
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove pontuação de borda
    s = s.replaceAll(RegExp(r'^[\-:;,\.\s]+|[\-:;,\.\s]+$'), '').trim();
    return s;
  }

  static bool _isLikelyIngredient(String s) {
    if (s.isEmpty) return false;
    if (s.length < 2 || s.length > 120) return false;
    // Precisa ter pelo menos uma vogal (filtra ruído do OCR)
    if (!RegExp(r'[aeiouáàâãéèêíïóôõúùûAEIOUÁÀÂÃÉÈÊÍÏÓÔÕÚÙÛ]').hasMatch(s)) {
      return false;
    }
    // Tem que ter pelo menos 2 letras consecutivas
    if (!RegExp(r'[A-Za-zÀ-ÿ]{2,}').hasMatch(s)) return false;
    return true;
  }

  /// Analisa avisos de "contém traços de X" / "pode conter X" contra o perfil.
  /// Retorna mapa: termo do aviso → lista de distúrbios afetados (vazio se nenhum).
  static List<TraceWarning> analyzeTraces(
    List<String> traceTerms,
    List<String> userDisorders, {
    List<String> customAllergens = const [],
  }) {
    final result = <TraceWarning>[];
    for (final term in traceTerms) {
      final normalized = _normalizeForMatching(term);
      final affected = <String>[];

      for (final disorder in userDisorders) {
        final triggers = AppConstants.problematicIngredients[disorder] ?? [];
        for (final trigger in triggers) {
          if (_matchesAsWord(normalized, trigger)) {
            if (!affected.contains(disorder)) affected.add(disorder);
            break;
          }
        }
      }

      for (final allergen in customAllergens) {
        if (allergen.trim().isEmpty) continue;
        if (_matchesAsWord(normalized, allergen)) {
          if (!affected.contains('Alérgeno personalizado')) {
            affected.add('Alérgeno personalizado');
          }
        }
      }

      if (affected.isNotEmpty) {
        result.add(TraceWarning(term: _prettifyName(term), disorders: affected));
      }
    }
    return result;
  }

  /// Analisa ingredientes contra distúrbios + alérgenos customizados.
  /// Retorna lista com flags e motivos consolidados (todos os triggers que casaram).
  static List<Ingredient> analyzeIngredients(
    List<String> ingredientNames,
    List<String> userDisorders, {
    List<String> customAllergens = const [],
  }) {
    final result = <Ingredient>[];

    for (final name in ingredientNames) {
      final normalized = _normalizeForMatching(name);
      final reasons = <String>[];
      final disorders = <String>[];

      for (final disorder in userDisorders) {
        final triggers = AppConstants.problematicIngredients[disorder] ?? [];
        for (final trigger in triggers) {
          if (_matchesAsWord(normalized, trigger)) {
            reasons.add('$trigger ($disorder)');
            if (!disorders.contains(disorder)) disorders.add(disorder);
            break; // só um trigger por distúrbio
          }
        }
      }

      for (final allergen in customAllergens) {
        if (allergen.trim().isEmpty) continue;
        if (_matchesAsWord(normalized, allergen)) {
          reasons.add('$allergen (alérgeno personalizado)');
          if (!disorders.contains('Alérgeno personalizado')) {
            disorders.add('Alérgeno personalizado');
          }
        }
      }

      result.add(Ingredient(
        name: _prettifyName(name),
        isFlagged: reasons.isNotEmpty,
        flagReason: reasons.isEmpty ? null : reasons.join(' · '),
        relatedDisorder: disorders.isEmpty ? null : disorders.join(', '),
      ));
    }

    return result;
  }

  /// Limpa caracteres estranhos do OCR mantendo acentos do português.
  static String cleanOcrText(String rawText) {
    return rawText
        // Caracteres permitidos: letras (com acentos), dígitos, espaços e pontuação útil
        .replaceAll(
            RegExp(r'[^A-Za-zÀ-ÿ0-9\s,;.:%()\[\]\-/&]', unicode: true), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }

  // --- helpers de matching ---

  static String _normalizeForMatching(String text) {
    final lower = text.toLowerCase();
    final sb = StringBuffer();
    for (final r in lower.runes) {
      sb.write(_stripDiacritic(String.fromCharCode(r)));
    }
    return sb.toString();
  }

  static String _stripDiacritic(String c) {
    const map = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    return map[c] ?? c;
  }

  /// Match por palavra (com fronteiras), tolerante a acentos e a flexão de
  /// número (RN01).
  ///
  /// A fronteira de palavra evita o falso positivo de substring (`sal` não
  /// casa com `salsa`, `ovo` não casa com `novo`). O conjunto de formas
  /// flexionadas cobre o risco simétrico: um gatilho registrado no singular
  /// precisa casar com a forma plural impressa no rótulo (`trigo` → `trigos`).
  ///
  /// Cada palavra do gatilho vira uma alternativa `(?:forma1|forma2)`, porque
  /// em português a flexão pode recair sobre o núcleo (`farinhas de trigo`) ou
  /// sobre o complemento (`claras de ovo`).
  static bool _matchesAsWord(String normalizedHaystack, String trigger) {
    final pattern = _triggerPattern(trigger);
    if (pattern == null) return false;
    return pattern.hasMatch(normalizedHaystack);
  }

  /// Cache de padrões: o mesmo gatilho é testado contra dezenas de ingredientes
  /// por análise.
  static final Map<String, RegExp?> _patternCache = {};

  static RegExp? _triggerPattern(String trigger) {
    return _patternCache.putIfAbsent(trigger, () {
      final t = _normalizeForMatching(trigger).trim();
      if (t.isEmpty) return null;
      final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      final body = words.map((w) {
        final forms = inflectionForms(w).map(RegExp.escape).toList();
        return forms.length == 1 ? forms.first : '(?:${forms.join('|')})';
      }).join(r'\s+');
      // Fronteira manual (espaço, pontuação ou início/fim) — \b em Dart não
      // cobre bem unicode.
      return RegExp(r'(?:^|[^a-z0-9])' + body + r'(?:$|[^a-z0-9])');
    });
  }

  /// Formas de número aceitas para uma palavra já normalizada (sem acento).
  ///
  /// Cobre as regras regulares do português suficientes para rotulagem:
  /// vogal → +s (`trigo`/`trigos`), -l → -is (`alcool`/`alcoois`),
  /// -m → -ns, -r/-z → +es, -ao → -oes. Palavras de até 2 letras (`de`, `do`)
  /// não são flexionadas. Visível para teste.
  static List<String> inflectionForms(String word) {
    final w = word.trim();
    if (w.length < 3) return [w];
    final forms = <String>{w};
    final last = w[w.length - 1];

    if (w.endsWith('ao')) {
      forms.add('${w.substring(0, w.length - 2)}oes');
    } else if ('aeiou'.contains(last)) {
      forms.add('${w}s');
    } else if (last == 'l') {
      forms.add('${w.substring(0, w.length - 1)}is');
    } else if (last == 'm') {
      forms.add('${w.substring(0, w.length - 1)}ns');
    } else if (last == 'r' || last == 'z') {
      forms.add('${w}es');
    }
    // Palavras terminadas em -s (`arachis`, `ovos`) permanecem invariáveis:
    // gerar singular a partir delas reintroduziria risco de falso positivo.

    return forms.toList();
  }

  static String _prettifyName(String s) {
    // Primeira letra de cada palavra em maiúscula, demais em minúscula
    final words = s.toLowerCase().split(' ');
    return words.map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

/// Aviso de "contém traços / pode conter" identificado como relevante para o perfil.
class TraceWarning {
  final String term;
  final List<String> disorders;
  const TraceWarning({required this.term, required this.disorders});
}
