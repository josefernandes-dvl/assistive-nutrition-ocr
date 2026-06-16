class Ingredient {
  final String name;
  final bool isFlagged;
  final String? flagReason;
  final String? relatedDisorder;

  const Ingredient({
    required this.name,
    this.isFlagged = false,
    this.flagReason,
    this.relatedDisorder,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String,
      isFlagged: json['is_flagged'] as bool? ?? false,
      flagReason: json['flag_reason'] as String?,
      relatedDisorder: json['related_disorder'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'is_flagged': isFlagged,
      'flag_reason': flagReason,
      'related_disorder': relatedDisorder,
    };
  }
}
