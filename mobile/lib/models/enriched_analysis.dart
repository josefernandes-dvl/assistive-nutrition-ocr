import 'ingredient.dart';
import 'nutrition.dart';

/// Resultado da análise enriquecida vinda do backend (`/api/ocr/analyze`).
class EnrichedAnalysis {
  final List<Ingredient> ingredients;
  final List<Ingredient> flaggedIngredients;
  final List<OfficialAllergen> officialAllergens;

  /// Traços oficiais da Open Food Facts (`traces_tags`) que afetam o perfil —
  /// presença POSSÍVEL (contaminação cruzada). Costumam existir mesmo quando a
  /// lista de ingredientes do produto não foi cadastrada na OFF.
  final List<OfficialAllergen> officialTraces;
  final AnalysisSummary summary;
  final ProductInfo? product;

  const EnrichedAnalysis({
    required this.ingredients,
    required this.flaggedIngredients,
    required this.officialAllergens,
    this.officialTraces = const [],
    required this.summary,
    this.product,
  });

  factory EnrichedAnalysis.fromJson(Map<String, dynamic> json) {
    return EnrichedAnalysis(
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      flaggedIngredients: (json['flagged_ingredients'] as List<dynamic>? ?? [])
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      officialAllergens: (json['official_allergens'] as List<dynamic>? ?? [])
          .map((e) => OfficialAllergen.fromJson(e as Map<String, dynamic>))
          .toList(),
      officialTraces: (json['official_traces'] as List<dynamic>? ?? [])
          .map((e) => OfficialAllergen.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: AnalysisSummary.fromJson(
          json['summary'] as Map<String, dynamic>? ?? const {}),
      product: json['product'] == null
          ? null
          : ProductInfo.fromJson(json['product'] as Map<String, dynamic>),
    );
  }
}

class AnalysisSummary {
  final int total;
  final int flagged;
  final String severity; // safe | warning | danger

  const AnalysisSummary({
    required this.total,
    required this.flagged,
    required this.severity,
  });

  factory AnalysisSummary.fromJson(Map<String, dynamic> json) {
    return AnalysisSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      flagged: (json['flagged'] as num?)?.toInt() ?? 0,
      severity: json['severity'] as String? ?? 'safe',
    );
  }
}

class OfficialAllergen {
  final String tag; // ex.: en:gluten
  final List<String> disorders;

  const OfficialAllergen({required this.tag, required this.disorders});

  factory OfficialAllergen.fromJson(Map<String, dynamic> json) {
    return OfficialAllergen(
      tag: json['tag'] as String? ?? '',
      disorders: (json['disorders'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }

  /// Nome legível do alérgeno (sem o prefixo "en:").
  String get prettyName {
    final raw = tag.replaceFirst(RegExp(r'^[a-z]{2}:'), '');
    const map = {
      'milk': 'Leite',
      'gluten': 'Glúten',
      'eggs': 'Ovos',
      'peanuts': 'Amendoim',
      'soybeans': 'Soja',
      'nuts': 'Castanhas',
      'fish': 'Peixe',
      'crustaceans': 'Crustáceos',
      'sesame-seeds': 'Gergelim',
      'mustard': 'Mostarda',
      'celery': 'Aipo',
      'sulphur-dioxide-and-sulphites': 'Sulfitos',
      'molluscs': 'Moluscos',
      'lactose': 'Lactose',
    };
    return map[raw] ?? raw.replaceAll('-', ' ');
  }
}

/// Subconjunto da análise enriquecida usado para complementar o resultado
/// local exibido na tela de resultados (sem sobrescrever a análise offline).
class EnrichmentBundle {
  final List<OfficialAllergen> officialAllergens;
  final ProductInfo? product;

  const EnrichmentBundle({
    required this.officialAllergens,
    this.product,
  });
}

class ProductInfo {
  final String? barcode;
  final String? name;
  final String? brand;
  final String? imageUrl;
  final int? novaGroup; // 1..4 (NOVA processamento)
  final String? nutriscoreGrade; // a..e
  final NutritionInfo? nutriments;

  const ProductInfo({
    this.barcode,
    this.name,
    this.brand,
    this.imageUrl,
    this.novaGroup,
    this.nutriscoreGrade,
    this.nutriments,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      barcode: json['barcode'] as String?,
      name: json['name'] as String?,
      brand: json['brand'] as String?,
      imageUrl: json['image_url'] as String?,
      novaGroup: (json['nova_group'] as num?)?.toInt(),
      nutriscoreGrade: json['nutriscore_grade'] as String?,
      nutriments: json['nutriments'] == null
          ? null
          : NutritionInfo.fromJson(json['nutriments'] as Map<String, dynamic>),
    );
  }
}
