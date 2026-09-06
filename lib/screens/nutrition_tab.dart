import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../ai/local_llm_service.dart';

class NutritionTab extends StatefulWidget {
  const NutritionTab({super.key});

  @override
  State<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<NutritionTab> {
  final DatabaseService _db = DatabaseService();
  List<FoodLog> _todayLogs = [];
  bool _isLoading = true;
  bool _isAnalyzing = false;

  int _totalCalories = 0;
  double _totalProtein = 0;
  double _totalCarbs = 0;
  double _totalFat = 0;

  final int _targetCalories = 2500;
  final double _targetProtein = 180.0;
  final double _targetCarbs = 250.0;
  final double _targetFat = 70.0;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    setState(() => _isLoading = true);
    final today = DateTime.now().toIso8601String().split('T')[0];
    final logs = await _db.getFoodLogsForDate(today);
    
    int cals = 0;
    double p = 0, c = 0, f = 0;
    for (var log in logs) {
      cals += log.calories;
      p += log.proteinG;
      c += log.carbsG;
      f += log.fatG;
    }

    setState(() {
      _todayLogs = logs;
      _totalCalories = cals;
      _totalProtein = p;
      _totalCarbs = c;
      _totalFat = f;
      _isLoading = false;
    });
  }

  Future<void> _snapMeal() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final bytes = await xfile.readAsBytes();
      final llm = await LlmServiceFactory.create();
      
      final prompt = '''
You are an expert nutritionist. Estimate the nutritional content of the food in this image.
Please output ONLY a valid JSON object in this exact format:
{
  "food_name": "Name of food",
  "calories": 0,
  "protein_g": 0.0,
  "carbs_g": 0.0,
  "fat_g": 0.0
}
Do not include any markdown formatting, backticks, or other text. Just the raw JSON.
''';

      final response = await llm.generateOneShot(
        prompt,
        imageBytes: [bytes],
      );

      // Try to parse JSON
      final cleanJson = response.replaceAll(RegExp(r'```(?:json)?|```'), '').trim();
      final Map<String, dynamic> data = jsonDecode(cleanJson);

      await _db.insertFoodLog(FoodLog(
        id: const Uuid().v4(),
        date: DateTime.now().toIso8601String().split('T')[0],
        mealType: 'Snack', // Default, could be derived from time
        foodName: data['food_name'] ?? 'Unknown Meal',
        calories: (data['calories'] as num?)?.toInt() ?? 0,
        proteinG: (data['protein_g'] as num?)?.toDouble() ?? 0.0,
        carbsG: (data['carbs_g'] as num?)?.toDouble() ?? 0.0,
        fatG: (data['fat_g'] as num?)?.toDouble() ?? 0.0,
        imagePath: xfile.path,
        estimatedByAi: true,
        createdAt: DateTime.now(),
      ));

      _loadTodayData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to analyze image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton.filled(
            onPressed: _isAnalyzing ? null : _snapMeal,
            tooltip: 'Snap Meal',
            icon: const Icon(Icons.camera_alt_rounded, size: 20),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isAnalyzing
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('AI is analyzing your meal...'),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 120),
                  children: [
                    _buildMacroDashboard(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Today\'s Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _isAnalyzing ? null : _snapMeal,
                          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                          label: const Text('Snap Meal'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_todayLogs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.restaurant_menu_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text('No food logged today.'),
                              const SizedBox(height: 6),
                              const Text('Tap "Snap Meal" above to calculate calories with AI!', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._todayLogs.map((log) => _buildFoodLogItem(log)),
                  ],
                ),
    );
  }

  Widget _buildMacroDashboard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '$_totalCalories / $_targetCalories kcal',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroItem('Protein', _totalProtein, _targetProtein, Colors.blue),
              _buildMacroItem('Carbs', _totalCarbs, _targetCarbs, Colors.orange),
              _buildMacroItem('Fat', _totalFat, _targetFat, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, double current, double target, Color color) {
    final percent = (current / target).clamp(0.0, 1.0);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: percent,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 6,
              ),
            ),
            Text('${(percent * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text('${current.toInt()}g / ${target.toInt()}g', style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildFoodLogItem(FoodLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(log.foodName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${log.calories} kcal • ${log.proteinG.toInt()}g P • ${log.carbsG.toInt()}g C • ${log.fatG.toInt()}g F'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () async {
            await _db.deleteFoodLog(log.id);
            _loadTodayData();
          },
        ),
      ),
    );
  }
}
