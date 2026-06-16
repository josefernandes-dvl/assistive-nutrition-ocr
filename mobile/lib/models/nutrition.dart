class NutritionInfo {
  final double? calories;
  final double? totalFat;
  final double? saturatedFat;
  final double? carbohydrates;
  final double? sugars;
  final double? fiber;
  final double? protein;
  final double? sodium;

  const NutritionInfo({
    this.calories,
    this.totalFat,
    this.saturatedFat,
    this.carbohydrates,
    this.sugars,
    this.fiber,
    this.protein,
    this.sodium,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: (json['calories'] as num?)?.toDouble(),
      totalFat: (json['total_fat'] as num?)?.toDouble(),
      saturatedFat: (json['saturated_fat'] as num?)?.toDouble(),
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble(),
      sugars: (json['sugars'] as num?)?.toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      sodium: (json['sodium'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'total_fat': totalFat,
      'saturated_fat': saturatedFat,
      'carbohydrates': carbohydrates,
      'sugars': sugars,
      'fiber': fiber,
      'protein': protein,
      'sodium': sodium,
    };
  }
}
