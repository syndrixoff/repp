import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'repp.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Exercises table (for custom exercises)
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        equipment TEXT,
        primary_muscle TEXT,
        secondary_muscles TEXT,
        video_url TEXT,
        thumbnail_url TEXT,
        is_custom INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Routines table
    await db.execute('''
      CREATE TABLE routines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        scheduled_weekdays TEXT,
        created_at TEXT NOT NULL,
        last_used_at TEXT,
        times_used INTEGER DEFAULT 0
      )
    ''');

    // Routine exercises table
    await db.execute('''
      CREATE TABLE routine_exercises (
        id TEXT PRIMARY KEY,
        routine_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        exercise_order INTEGER NOT NULL,
        target_sets INTEGER DEFAULT 3,
        target_reps INTEGER,
        target_weight REAL,
        target_duration REAL,
        notes TEXT,
        superset_id TEXT,
        set_types TEXT,
        FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
      )
    ''');

    // Workouts table
    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        notes TEXT,
        routine_id TEXT,
        is_template INTEGER DEFAULT 0,
        paused_seconds INTEGER DEFAULT 0
      )
    ''');

    // Workout exercises table
    await db.execute('''
      CREATE TABLE workout_exercises (
        id TEXT PRIMARY KEY,
        workout_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        exercise_order INTEGER NOT NULL,
        notes TEXT,
        superset_id TEXT,
        FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE
      )
    ''');

    // Workout sets table
    await db.execute('''
      CREATE TABLE workout_sets (
        id TEXT PRIMARY KEY,
        workout_exercise_id TEXT NOT NULL,
        set_number INTEGER NOT NULL,
        weight REAL,
        reps INTEGER,
        duration REAL,
        distance REAL,
        is_warmup INTEGER DEFAULT 0,
        is_drop_set INTEGER DEFAULT 0,
        is_failure INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 0,
        notes TEXT,
        completed_at TEXT,
        FOREIGN KEY (workout_exercise_id) REFERENCES workout_exercises(id) ON DELETE CASCADE
      )
    ''');

    // Personal records table
    await db.execute('''
      CREATE TABLE personal_records (
        id TEXT PRIMARY KEY,
        exercise_id TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        type INTEGER NOT NULL,
        value REAL NOT NULL,
        secondary_value REAL,
        achieved_at TEXT NOT NULL,
        workout_id TEXT,
        set_id TEXT,
        notes TEXT
      )
    ''');

    // Player stats table (gamification)
    await db.execute('''
      CREATE TABLE player_stats (
        id TEXT PRIMARY KEY DEFAULT 'main',
        level INTEGER DEFAULT 0,
        total_xp INTEGER DEFAULT 0,
        current_streak INTEGER DEFAULT 0,
        longest_streak INTEGER DEFAULT 0,
        muscle_xp TEXT DEFAULT '{}',
        last_workout_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // XP log table
    await db.execute('''
      CREATE TABLE xp_log (
        id TEXT PRIMARY KEY,
        workout_id TEXT,
        amount INTEGER NOT NULL,
        source TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Food logs table
    await db.execute('''
      CREATE TABLE food_logs (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        food_name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL,
        fat_g REAL NOT NULL,
        quantity_g REAL,
        image_path TEXT,
        estimated_by_ai INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Daily nutrition targets table
    await db.execute('''
      CREATE TABLE daily_nutrition_targets (
        date TEXT PRIMARY KEY,
        target_calories INTEGER NOT NULL,
        target_protein INTEGER NOT NULL,
        target_carbs INTEGER NOT NULL,
        target_fat INTEGER NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute(
      'CREATE INDEX idx_workout_exercises_workout ON workout_exercises(workout_id)',
    );
    await db.execute(
      'CREATE INDEX idx_workout_sets_exercise ON workout_sets(workout_exercise_id)',
    );
    await db.execute(
      'CREATE INDEX idx_routine_exercises_routine ON routine_exercises(routine_id)',
    );
    await db.execute(
      'CREATE INDEX idx_personal_records_exercise ON personal_records(exercise_id)',
    );
    await db.execute('CREATE INDEX idx_workouts_date ON workouts(start_time)');
    await db.execute('CREATE INDEX idx_xp_log_date ON xp_log(created_at)');
    await db.execute('CREATE INDEX idx_food_logs_date ON food_logs(date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE routine_exercises ADD COLUMN set_types TEXT',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS player_stats (
          id TEXT PRIMARY KEY DEFAULT 'main',
          level INTEGER DEFAULT 0,
          total_xp INTEGER DEFAULT 0,
          current_streak INTEGER DEFAULT 0,
          longest_streak INTEGER DEFAULT 0,
          muscle_xp TEXT DEFAULT '{}',
          last_workout_date TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS xp_log (
          id TEXT PRIMARY KEY,
          workout_id TEXT,
          amount INTEGER NOT NULL,
          source TEXT NOT NULL,
          details TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_xp_log_date ON xp_log(created_at)',
      );
      // Seed initial player stats row
      await db.insert('player_stats', {
        'id': 'main',
        'level': 0,
        'total_xp': 0,
        'current_streak': 0,
        'longest_streak': 0,
        'muscle_xp': '{}',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE routines ADD COLUMN scheduled_weekdays TEXT',
      );
      // Existing routines default to every day.
      await db.rawUpdate(
        "UPDATE routines SET scheduled_weekdays = '1,2,3,4,5,6,7' WHERE scheduled_weekdays IS NULL OR scheduled_weekdays = ''",
      );
    }

    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE workouts ADD COLUMN paused_seconds INTEGER DEFAULT 0',
      );
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS food_logs (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          meal_type TEXT NOT NULL,
          food_name TEXT NOT NULL,
          calories INTEGER NOT NULL,
          protein_g REAL NOT NULL,
          carbs_g REAL NOT NULL,
          fat_g REAL NOT NULL,
          quantity_g REAL,
          image_path TEXT,
          estimated_by_ai INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_nutrition_targets (
          date TEXT PRIMARY KEY,
          target_calories INTEGER NOT NULL,
          target_protein INTEGER NOT NULL,
          target_carbs INTEGER NOT NULL,
          target_fat INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_logs_date ON food_logs(date)');
    }
  }

  // ============ Exercise Methods ============

  Future<void> insertCustomExercise(Exercise exercise) async {
    final db = await database;
    await db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getCustomExercises() async {
    final db = await database;
    final maps = await db.query('exercises', where: 'is_custom = 1');
    return maps.map((map) => Exercise.fromMap(map)).toList();
  }

  Future<void> deleteCustomExercise(String id) async {
    final db = await database;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // ============ Routine Methods ============

  Future<void> insertRoutine(Routine routine) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('routines', routine.toMap());
      for (final exercise in routine.exercises) {
        await txn.insert('routine_exercises', exercise.toMap(routine.id));
      }
    });
  }

  Future<void> updateRoutine(Routine routine) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'routines',
        routine.toMap(),
        where: 'id = ?',
        whereArgs: [routine.id],
      );
      // Delete existing exercises and re-insert
      await txn.delete(
        'routine_exercises',
        where: 'routine_id = ?',
        whereArgs: [routine.id],
      );
      for (final exercise in routine.exercises) {
        await txn.insert('routine_exercises', exercise.toMap(routine.id));
      }
    });
  }

  Future<List<Routine>> getAllRoutines() async {
    final db = await database;
    final routineMaps = await db.query('routines', orderBy: 'created_at DESC');

    List<Routine> routines = [];
    for (final routineMap in routineMaps) {
      final exerciseMaps = await db.query(
        'routine_exercises',
        where: 'routine_id = ?',
        whereArgs: [routineMap['id']],
        orderBy: 'exercise_order ASC',
      );
      final exercises = exerciseMaps
          .map((m) => RoutineExercise.fromMap(m))
          .toList();
      routines.add(Routine.fromMap(routineMap, exercises));
    }
    return routines;
  }

  Future<Routine?> getRoutine(String id) async {
    final db = await database;
    final routineMaps = await db.query(
      'routines',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (routineMaps.isEmpty) return null;

    final exerciseMaps = await db.query(
      'routine_exercises',
      where: 'routine_id = ?',
      whereArgs: [id],
      orderBy: 'exercise_order ASC',
    );
    final exercises = exerciseMaps
        .map((m) => RoutineExercise.fromMap(m))
        .toList();
    return Routine.fromMap(routineMaps.first, exercises);
  }

  Future<void> deleteRoutine(String id) async {
    final db = await database;
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRoutineUsage(String routineId) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE routines
      SET times_used = times_used + 1, last_used_at = ?
      WHERE id = ?
    ''',
      [DateTime.now().toIso8601String(), routineId],
    );
  }

  // ============ Workout Methods ============

  Future<void> insertWorkout(Workout workout) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('workouts', workout.toMap());
      for (final exercise in workout.exercises) {
        await txn.insert('workout_exercises', exercise.toMap(workout.id));
        for (final set in exercise.sets) {
          await txn.insert('workout_sets', set.toMap(exercise.id));
        }
      }
    });
  }

  Future<void> updateWorkout(Workout workout) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'workouts',
        workout.toMap(),
        where: 'id = ?',
        whereArgs: [workout.id],
      );

      // Delete existing exercises and sets
      final existingExercises = await txn.query(
        'workout_exercises',
        where: 'workout_id = ?',
        whereArgs: [workout.id],
      );
      for (final ex in existingExercises) {
        await txn.delete(
          'workout_sets',
          where: 'workout_exercise_id = ?',
          whereArgs: [ex['id']],
        );
      }
      await txn.delete(
        'workout_exercises',
        where: 'workout_id = ?',
        whereArgs: [workout.id],
      );

      // Re-insert exercises and sets
      for (final exercise in workout.exercises) {
        await txn.insert('workout_exercises', exercise.toMap(workout.id));
        for (final set in exercise.sets) {
          await txn.insert('workout_sets', set.toMap(exercise.id));
        }
      }
    });
  }

  Future<Workout?> getWorkout(String id) async {
    final db = await database;
    final workoutMaps = await db.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (workoutMaps.isEmpty) return null;

    final exercises = await _getWorkoutExercises(db, id);
    return Workout.fromMap(workoutMaps.first, exercises);
  }

  Future<List<WorkoutExercise>> _getWorkoutExercises(
    Database db,
    String workoutId,
  ) async {
    final exerciseMaps = await db.query(
      'workout_exercises',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'exercise_order ASC',
    );

    List<WorkoutExercise> exercises = [];
    for (final exMap in exerciseMaps) {
      final setMaps = await db.query(
        'workout_sets',
        where: 'workout_exercise_id = ?',
        whereArgs: [exMap['id']],
        orderBy: 'set_number ASC',
      );
      final sets = setMaps.map((m) => WorkoutSet.fromMap(m)).toList();
      exercises.add(WorkoutExercise.fromMap(exMap, sets));
    }
    return exercises;
  }

  Future<List<Workout>> getAllWorkouts({int? limit, int? offset}) async {
    final db = await database;
    final workoutMaps = await db.query(
      'workouts',
      where: 'is_template = 0',
      orderBy: 'start_time DESC',
      limit: limit,
      offset: offset,
    );

    List<Workout> workouts = [];
    for (final workoutMap in workoutMaps) {
      final exercises = await _getWorkoutExercises(
        db,
        workoutMap['id'] as String,
      );
      workouts.add(Workout.fromMap(workoutMap, exercises));
    }
    return workouts;
  }

  Future<List<Workout>> getWorkoutsInRange(DateTime start, DateTime end) async {
    final db = await database;
    final workoutMaps = await db.query(
      'workouts',
      where: 'is_template = 0 AND start_time >= ? AND start_time <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'start_time DESC',
    );

    List<Workout> workouts = [];
    for (final workoutMap in workoutMaps) {
      final exercises = await _getWorkoutExercises(
        db,
        workoutMap['id'] as String,
      );
      workouts.add(Workout.fromMap(workoutMap, exercises));
    }
    return workouts;
  }

  Future<Workout?> getActiveWorkout() async {
    final db = await database;
    final workoutMaps = await db.query(
      'workouts',
      where: 'is_template = 0 AND end_time IS NULL',
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (workoutMaps.isEmpty) return null;

    final exercises = await _getWorkoutExercises(
      db,
      workoutMaps.first['id'] as String,
    );
    return Workout.fromMap(workoutMaps.first, exercises);
  }

  Future<void> deleteWorkout(String id) async {
    final db = await database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getWorkoutCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM workouts WHERE is_template = 0',
    );
    return result.first['count'] as int;
  }

  // ============ Personal Records Methods ============

  Future<void> insertPersonalRecord(PersonalRecord pr) async {
    final db = await database;
    await db.insert('personal_records', pr.toMap());
  }

  Future<List<PersonalRecord>> getPersonalRecordsForExercise(
    String exerciseId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'personal_records',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'achieved_at DESC',
    );
    return maps.map((m) => PersonalRecord.fromMap(m)).toList();
  }

  Future<List<PersonalRecord>> getAllPersonalRecords() async {
    final db = await database;
    final maps = await db.query(
      'personal_records',
      orderBy: 'achieved_at DESC',
    );
    return maps.map((m) => PersonalRecord.fromMap(m)).toList();
  }

  Future<PersonalRecord?> getBestPRForExercise(
    String exerciseId,
    PRType type,
  ) async {
    final db = await database;
    final maps = await db.query(
      'personal_records',
      where: 'exercise_id = ? AND type = ?',
      whereArgs: [exerciseId, type.index],
      orderBy: 'value DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PersonalRecord.fromMap(maps.first);
  }

  Future<void> deletePersonalRecord(String id) async {
    final db = await database;
    await db.delete('personal_records', where: 'id = ?', whereArgs: [id]);
  }

  /// Get historical completed workout sets for an exercise
  Future<List<Map<String, dynamic>>> getExerciseHistoryLogs(
    String exerciseIdOrName, {
    int limit = 15,
  }) async {
    final db = await database;
    final queryLower = exerciseIdOrName.toLowerCase().trim();
    final maps = await db.rawQuery('''
      SELECT 
        w.id as workout_id,
        w.name as workout_name,
        w.start_time,
        we.exercise_id,
        we.exercise_name,
        ws.set_number,
        ws.weight,
        ws.reps,
        ws.duration,
        ws.is_completed,
        ws.is_warmup,
        ws.is_drop_set
      FROM workouts w
      JOIN workout_exercises we ON we.workout_id = w.id
      JOIN workout_sets ws ON ws.workout_exercise_id = we.id
      WHERE (we.exercise_id = ? OR LOWER(we.exercise_name) LIKE ? OR LOWER(we.exercise_id) LIKE ?)
        AND w.is_template = 0
        AND ws.is_completed = 1
      ORDER BY w.start_time DESC, ws.set_number ASC
      LIMIT ?
    ''', [exerciseIdOrName, '%$queryLower%', '%$queryLower%', limit * 10]);
    return maps;
  }

  // ============ Statistics Methods ============

  Future<Map<String, dynamic>> getWorkoutStats() async {
    final db = await database;

    // Total workouts
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM workouts WHERE is_template = 0 AND end_time IS NOT NULL',
    );
    final totalWorkouts = totalResult.first['count'] as int;

    // Total volume
    final volumeResult = await db.rawQuery('''
      SELECT SUM(ws.weight * ws.reps) as total_volume
      FROM workout_sets ws
      JOIN workout_exercises we ON ws.workout_exercise_id = we.id
      JOIN workouts w ON we.workout_id = w.id
      WHERE w.is_template = 0 AND w.end_time IS NOT NULL AND ws.is_completed = 1
    ''');
    final totalVolume =
        (volumeResult.first['total_volume'] as num?)?.toDouble() ?? 0.0;

    // Total sets completed
    final setsResult = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM workout_sets ws
      JOIN workout_exercises we ON ws.workout_exercise_id = we.id
      JOIN workouts w ON we.workout_id = w.id
      WHERE w.is_template = 0 AND w.end_time IS NOT NULL AND ws.is_completed = 1
    ''');
    final totalSets = setsResult.first['count'] as int;

    // Average workout duration
    final durationResult = await db.rawQuery('''
      SELECT AVG(
        (julianday(end_time) - julianday(start_time)) * 24 * 60
      ) as avg_duration
      FROM workouts
      WHERE is_template = 0 AND end_time IS NOT NULL
    ''');
    final avgDurationMinutes =
        (durationResult.first['avg_duration'] as num?)?.toDouble() ?? 0.0;

    // This week's workouts
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartStr = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    ).toIso8601String();
    final thisWeekResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM workouts
      WHERE is_template = 0 AND end_time IS NOT NULL AND start_time >= ?
    ''',
      [weekStartStr],
    );
    final thisWeekWorkouts = thisWeekResult.first['count'] as int;

    return {
      'total_workouts': totalWorkouts,
      'total_volume': totalVolume,
      'total_sets': totalSets,
      'avg_duration_minutes': avgDurationMinutes,
      'this_week_workouts': thisWeekWorkouts,
    };
  }

  Future<List<Map<String, dynamic>>> getExerciseHistory(
    String exerciseId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT
        w.id as workout_id,
        w.name as workout_name,
        w.start_time,
        we.id as workout_exercise_id,
        ws.weight,
        ws.reps,
        ws.duration,
        ws.is_completed
      FROM workout_sets ws
      JOIN workout_exercises we ON ws.workout_exercise_id = we.id
      JOIN workouts w ON we.workout_id = w.id
      WHERE we.exercise_id = ? AND w.is_template = 0 AND w.end_time IS NOT NULL
      ORDER BY w.start_time DESC, ws.set_number ASC
    ''',
      [exerciseId],
    );
  }

  Future<List<Map<String, dynamic>>> getVolumeByMuscleGroup(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    // This would need exercise muscle data joined - simplified version
    return await db.rawQuery(
      '''
      SELECT
        DATE(w.start_time) as date,
        SUM(ws.weight * ws.reps) as volume
      FROM workout_sets ws
      JOIN workout_exercises we ON ws.workout_exercise_id = we.id
      JOIN workouts w ON we.workout_id = w.id
      WHERE w.is_template = 0 AND w.end_time IS NOT NULL
        AND w.start_time >= ? AND w.start_time <= ?
        AND ws.is_completed = 1
      GROUP BY DATE(w.start_time)
      ORDER BY date ASC
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
  }

  // ============ Player Stats Methods ============

  Future<PlayerStats?> getPlayerStats() async {
    final db = await database;
    final maps = await db.query(
      'player_stats',
      where: 'id = ?',
      whereArgs: ['main'],
    );
    if (maps.isEmpty) return null;
    return PlayerStats.fromMap(maps.first);
  }

  Future<void> upsertPlayerStats(PlayerStats stats) async {
    final db = await database;
    await db.insert(
      'player_stats',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertXPLog(XPLog log) async {
    final db = await database;
    await db.insert('xp_log', log.toMap());
  }

  Future<List<XPLog>> getRecentXPLogs({int limit = 20}) async {
    final db = await database;
    final maps = await db.query(
      'xp_log',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((m) => XPLog.fromMap(m)).toList();
  }

  // ============ Utility Methods ============

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('workout_sets');
      await txn.delete('workout_exercises');
      await txn.delete('workouts');
      await txn.delete('routine_exercises');
      await txn.delete('routines');
      await txn.delete('personal_records');
      await txn.delete('exercises');
      await txn.delete('xp_log');

      // Recreate the single baseline player stats row so XP state is fully reset.
      await txn.delete('player_stats');
      await txn.insert('player_stats', {
        'id': 'main',
        'level': 0,
        'total_xp': 0,
        'current_streak': 0,
        'longest_streak': 0,
        'muscle_xp': '{}',
        'last_workout_date': null,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  // ============ Food & Nutrition Methods ============

  Future<void> insertFoodLog(FoodLog log) async {
    final db = await database;
    await db.insert('food_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FoodLog>> getFoodLogsForDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'food_logs',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => FoodLog.fromMap(m)).toList();
  }

  Future<void> deleteFoodLog(String id) async {
    final db = await database;
    await db.delete('food_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveDailyNutritionTarget(DailyNutritionTarget target) async {
    final db = await database;
    await db.insert('daily_nutrition_targets', target.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DailyNutritionTarget?> getDailyNutritionTarget(String date) async {
    final db = await database;
    final maps = await db.query(
      'daily_nutrition_targets',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (maps.isEmpty) return null;
    return DailyNutritionTarget.fromMap(maps.first);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
