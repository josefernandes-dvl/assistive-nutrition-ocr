import 'ingredient.dart';
import 'nutrition.dart';

class ScanResult {
  final String? id;
  final String rawText;
  final List<Ingredient> ingredients;
  final NutritionInfo? nutritionInfo;
  final List<Ingredient> flaggedIngredients;
  final String? imagePath;
  final DateTime scannedAt;

  ScanResult({
    this.id,
    required this.rawText,
    required this.ingredients,
    this.nutritionInfo,
    required this.flaggedIngredients,
    this.imagePath,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['_id'] as String?,
      rawText: json['raw_text'] as String? ?? '',
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      nutritionInfo: json['nutrition_info'] != null
          ? NutritionInfo.fromJson(
              json['nutrition_info'] as Map<String, dynamic>)
          : null,
      flaggedIngredients: (json['flagged_ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      imagePath: json['image_path'] as String?,
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'raw_text': rawText,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'nutrition_info': nutritionInfo?.toJson(),
      'flagged_ingredients': flaggedIngredients.map((e) => e.toJson()).toList(),
      'image_path': imagePath,
      'scanned_at': scannedAt.toIso8601String(),
    };
  }

  bool get hasDangerousIngredients => flaggedIngredients.isNotEmpty;

  int get totalIngredients => ingredients.length;
}
