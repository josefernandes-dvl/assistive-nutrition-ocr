/// Dicionário canônico de ingredientes e termos comuns em rótulos brasileiros.
/// Usado para:
///   1. Correção fuzzy pós-OCR (corrigir "vegan" → "vegetal", "asucar" → "açúcar"...).
///   2. Scoring de variantes do OCR (quanto mais termos válidos, melhor o resultado).
class IngredientDictionary {
  /// Lista canônica. Cada entrada é a forma "preferida" (com acento se aplicável).
  /// A comparação é feita após normalização (lowercase + sem diacríticos).
  static const List<String> entries = [
    // Açúcares e adoçantes
    'açúcar', 'açúcar refinado', 'açúcar cristal', 'açúcar invertido',
    'açúcar mascavo', 'açúcar demerara', 'glicose', 'frutose', 'sacarose',
    'maltose', 'lactose', 'xarope de glicose', 'xarope de milho',
    'xarope de frutose', 'mel', 'agave', 'estévia', 'sucralose',
    'aspartame', 'sacarina', 'ciclamato', 'sorbitol', 'manitol', 'xilitol',
    'maltitol', 'eritritol',

    // Cereais e farinhas
    'farinha de trigo', 'farinha de trigo enriquecida',
    'farinha de trigo integral', 'farinha de mandioca', 'farinha de milho',
    'farinha de arroz', 'farinha de aveia', 'farinha láctea', 'fubá',
    'amido', 'amido de milho', 'amido de trigo', 'amido modificado',
    'trigo', 'cevada', 'centeio', 'aveia', 'arroz', 'milho', 'gérmen de trigo',
    'farelo de trigo', 'malte', 'extrato de malte', 'semolina', 'glúten',
    'triticale', 'espelta', 'quinoa',

    // Laticínios
    'leite', 'leite em pó', 'leite integral', 'leite desnatado',
    'leite condensado', 'creme de leite', 'soro de leite', 'soro do leite',
    'soro lácteo', 'soro de leite em pó', 'queijo', 'iogurte', 'nata',
    'manteiga', 'margarina', 'caseína', 'caseinato', 'caseinato de sódio',
    'whey', 'whey protein', 'lactalbumina', 'lactoglobulina',

    // Gorduras e óleos
    'óleo vegetal', 'óleo de soja', 'óleo de girassol', 'óleo de palma',
    'óleo de canola', 'óleo de milho', 'óleo de amendoim', 'óleo de coco',
    'gordura vegetal', 'gordura hidrogenada', 'gordura trans',
    'gordura vegetal hidrogenada', 'azeite de oliva',

    // Proteínas e leguminosas
    'soja', 'proteína de soja', 'extrato de soja', 'lecitina de soja',
    'molho de soja', 'shoyu', 'tofu', 'amendoim', 'pasta de amendoim',
    'castanha', 'castanha de caju', 'castanha do pará', 'amêndoa',
    'amêndoas', 'avelã', 'nozes',

    // Ovos
    'ovo', 'ovos', 'clara de ovo', 'gema', 'gema de ovo', 'albumina',
    'ovoalbumina', 'lecitina de ovo', 'lisozima',

    // Cacau e chocolate
    'cacau', 'cacau em pó', 'manteiga de cacau', 'massa de cacau',
    'chocolate', 'chocolate ao leite', 'chocolate amargo', 'chocolate branco',

    // Sal e condimentos
    'sal', 'sal refinado', 'sal iodado', 'pimenta', 'pimenta do reino',
    'pimenta calabresa', 'cebola', 'alho', 'cebola em pó', 'alho em pó',
    'tomate', 'molho de tomate', 'orégano', 'salsa', 'salsinha',
    'cebolinha', 'manjericão', 'hortelã', 'menta', 'gengibre',

    // Aditivos (categorias)
    'conservante', 'conservantes', 'corante', 'corantes', 'corante caramelo',
    'aromatizante', 'aromatizantes', 'aromatizante natural',
    'aromatizante artificial', 'emulsificante', 'emulsificantes',
    'estabilizante', 'estabilizantes', 'espessante', 'espessantes',
    'antioxidante', 'antioxidantes', 'acidulante', 'acidulantes',
    'umectante', 'umectantes', 'edulcorante', 'edulcorantes',
    'fermento', 'fermentos químicos', 'fermento biológico',
    'bicarbonato de sódio', 'bicarbonato de amônio', 'fosfato',
    'fosfato monocálcico', 'fosfato tricálcico', 'lecitina',
    'goma xantana', 'goma guar', 'pectina', 'gelatina', 'gelatina sem sabor',
    'ágar', 'carragena',

    // Vitaminas e minerais
    'ferro', 'cálcio', 'magnésio', 'zinco', 'potássio', 'sódio',
    'ácido ascórbico', 'ácido cítrico', 'ácido lático', 'ácido fólico',
    'vitamina a', 'vitamina b', 'vitamina c', 'vitamina d', 'vitamina e',
    'niacina', 'tiamina', 'riboflavina',

    // Outros comuns
    'água', 'água potável', 'cafeína', 'álcool', 'álcool etílico',
    'glutamato monossódico', 'msg', 'levedura', 'fermento natural',
    'enzima', 'corante caramelo iii', 'corante caramelo iv',
    'diglicerídeos', 'monoglicerídeos', 'ésteres', 'ácidos graxos',

    // Termos isolados frequentes em listas de ingredientes
    'farinha', 'óleo', 'gordura', 'vegetal', 'integral', 'enriquecida',
    'natural', 'artificial', 'em pó', 'modificado', 'refinado', 'cristal',
    'invertido', 'condensado', 'desnatado', 'cozido',
  ];

  /// Mapa de correções pontuais para erros frequentes do OCR.
  /// Aplicado ANTES do fuzzy match — se o termo aparecer aqui, usa direto.
  /// Útil para casos onde Levenshtein não acerta (ex.: "vegan" → "vegetal").
  static const Map<String, String> commonOcrFixes = {
    'vegan': 'vegetal',
    'vegeta': 'vegetal',
    'vegtal': 'vegetal',
    'asucar': 'açúcar',
    'acucar': 'açúcar',
    'agucar': 'açúcar',
    'farinba': 'farinha',
    'fariha': 'farinha',
    'farinh': 'farinha',
    'trigol': 'trigo',
    'tngo': 'trigo',
    'leitel': 'leite',
    'leíte': 'leite',
    'lacte': 'leite',
    'cacaa': 'cacau',
    'cacao': 'cacau',
    'cacav': 'cacau',
    'sat': 'sal',
    'sal,': 'sal',
    'óteo': 'óleo',
    'oteo': 'óleo',
    'oleos': 'óleo',
    'fermenlo': 'fermento',
    'femento': 'fermento',
    'corarte': 'corante',
    'consetvante': 'conservante',
    'estabilizanle': 'estabilizante',
    'aromatizanle': 'aromatizante',
    'emulsificanle': 'emulsificante',
    'lecilina': 'lecitina',
    'lecltina': 'lecitina',
    'sotbitol': 'sorbitol',
    'casetna': 'caseína',
    'casefna': 'caseína',
    'gtuten': 'glúten',
    'gluien': 'glúten',
  };

  /// Versões normalizadas (lowercase + sem acentos) — calculadas uma vez.
  static final List<String> normalizedEntries =
      entries.map(_normalize).toList(growable: false);

  /// Acesso à versão normalizada de uma entrada pelo índice.
  static String normalizedAt(int index) => normalizedEntries[index];

  /// Para correção fuzzy: dada uma palavra normalizada do OCR, retorna a entrada
  /// canônica mais próxima — ou null se nenhuma estiver perto o suficiente.
  /// Considera primeiro o mapa de erros conhecidos do OCR.
  static String? bestMatch(
    String normalizedWord, {
    int maxDistance = 2,
    double maxRelative = 0.3,
  }) {
    if (normalizedWord.length < 3) return null;

    // 1. Correção direta para erros frequentes do OCR
    final direct = commonOcrFixes[normalizedWord];
    if (direct != null) return direct;

    // 2. Busca Levenshtein no dicionário canônico
    String? best;
    int bestDist = 1 << 30;

    for (var i = 0; i < normalizedEntries.length; i++) {
      final entry = normalizedEntries[i];
      // Performance: pula se a diferença de tamanho já excede o limite.
      final lenDiff = (entry.length - normalizedWord.length).abs();
      if (lenDiff > maxDistance && lenDiff / entry.length > maxRelative) {
        continue;
      }
      final d = _levenshtein(normalizedWord, entry);
      if (d < bestDist) {
        bestDist = d;
        best = entries[i];
      }
    }

    if (best == null) return null;
    final rel = bestDist / best.length;
    if (bestDist <= maxDistance && rel <= maxRelative) return best;
    return null;
  }

  /// Conta quantos termos do dicionário aparecem como substring no texto dado.
  /// Usado para "pontuar" variantes de OCR — quanto mais termos válidos
  /// aparecem, melhor o resultado.
  static int scoreText(String text) {
    final normalized = _normalize(text);
    int score = 0;
    for (final entry in normalizedEntries) {
      if (entry.length < 4) continue; // ignora termos muito curtos (sal, ovo)
      if (normalized.contains(entry)) score++;
    }
    return score;
  }

  // -------- helpers --------

  static String _normalize(String s) {
    final lower = s.toLowerCase();
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

  /// Distância de Levenshtein iterativa, otimizada para strings curtas.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final m = a.length;
    final n = b.length;
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        curr[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }
}
