class FoodLog {
  final String id;
  final String date;
  final String mealType; // e.g. Breakfast, Lunch, Dinner, Snack
  final String foodName;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double? quantityG;
  final String? imagePath;
  final bool estimatedByAi;
  final DateTime createdAt;

  const FoodLog({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodName,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.quantityG,
    this.imagePath,
    this.estimatedByAi = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'meal_type': mealType,
      'food_name': foodName,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'quantity_g': quantityG,
      'image_path': imagePath,
      'estimated_by_ai': estimatedByAi ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FoodLog.fromMap(Map<String, dynamic> map) {
    return FoodLog(
      id: map['id'] as String,
      date: map['date'] as String,
      mealType: map['meal_type'] as String,
      foodName: map['food_name'] as String,
      calories: map['calories'] as int,
      proteinG: (map['protein_g'] as num).toDouble(),
      carbsG: (map['carbs_g'] as num).toDouble(),
      fatG: (map['fat_g'] as num).toDouble(),
      quantityG: map['quantity_g'] != null ? (map['quantity_g'] as num).toDouble() : null,
      imagePath: map['image_path'] as String?,
      estimatedByAi: (map['estimated_by_ai'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
