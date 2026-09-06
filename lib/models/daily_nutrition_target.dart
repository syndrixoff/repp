class DailyNutritionTarget {
  final String date; // YYYY-MM-DD
  final int targetCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFat;

  const DailyNutritionTarget({
    required this.date,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'target_calories': targetCalories,
      'target_protein': targetProtein,
      'target_carbs': targetCarbs,
      'target_fat': targetFat,
    };
  }

  factory DailyNutritionTarget.fromMap(Map<String, dynamic> map) {
    return DailyNutritionTarget(
      date: map['date'] as String,
      targetCalories: map['target_calories'] as int,
      targetProtein: map['target_protein'] as int,
      targetCarbs: map['target_carbs'] as int,
      targetFat: map['target_fat'] as int,
    );
  }
}
