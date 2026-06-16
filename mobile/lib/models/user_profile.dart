class UserProfile {
  final String? id;
  final String name;
  final List<String> disorders;
  final List<String> customAllergens;

  const UserProfile({
    this.id,
    required this.name,
    required this.disorders,
    this.customAllergens = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id'] as String?,
      name: json['name'] as String? ?? '',
      disorders: (json['disorders'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      customAllergens: (json['custom_allergens'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'disorders': disorders,
      'custom_allergens': customAllergens,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    List<String>? disorders,
    List<String>? customAllergens,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      disorders: disorders ?? this.disorders,
      customAllergens: customAllergens ?? this.customAllergens,
    );
  }
}
