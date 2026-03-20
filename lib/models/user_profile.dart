/// User profile for diet planning and personalization.
class UserProfile {
  final String name;
  final String city;
  final int age;
  final double weightKg;
  final double heightCm;
  final String goal; // e.g. lose_weight, maintain, gain_muscle
  final String activityLevel; // sedentary, light, moderate, active, very_active
  final List<String> dietaryRestrictions; // e.g. vegetarian, vegan, gluten_free
  final String? medicalNotes;

  const UserProfile({
    required this.name,
    required this.city,
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.goal,
    required this.activityLevel,
    this.dietaryRestrictions = const [],
    this.medicalNotes,
  });

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  Map<String, dynamic> toJson() => {
        'name': name,
        'city': city,
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'goal': goal,
        'activityLevel': activityLevel,
        'dietaryRestrictions': dietaryRestrictions,
        'medicalNotes': medicalNotes,
      };

  static UserProfile fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0,
      goal: json['goal'] as String? ?? 'maintain',
      activityLevel: json['activityLevel'] as String? ?? 'moderate',
      dietaryRestrictions:
          (json['dietaryRestrictions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      medicalNotes: json['medicalNotes'] as String?,
    );
  }
}
