import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Structured user profile and fitness memory persisted locally across all sessions.
class UserMemoryProfile {
  String? goal;
  List<String> equipment;
  List<String> injuries;
  List<String> preferences;
  Map<String, dynamic> customNotes;
  DateTime lastUpdated;

  UserMemoryProfile({
    this.goal,
    List<String>? equipment,
    List<String>? injuries,
    List<String>? preferences,
    Map<String, dynamic>? customNotes,
    DateTime? lastUpdated,
  })  : equipment = equipment ?? [],
        injuries = injuries ?? [],
        preferences = preferences ?? [],
        customNotes = customNotes ?? {},
        lastUpdated = lastUpdated ?? DateTime.now();

  factory UserMemoryProfile.fromJson(Map<String, dynamic> json) {
    return UserMemoryProfile(
      goal: json['goal'] as String?,
      equipment: (json['equipment'] as List?)?.map((e) => e.toString()).toList() ?? [],
      injuries: (json['injuries'] as List?)?.map((e) => e.toString()).toList() ?? [],
      preferences: (json['preferences'] as List?)?.map((e) => e.toString()).toList() ?? [],
      customNotes: (json['customNotes'] as Map?)?.cast<String, dynamic>() ?? {},
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'goal': goal,
        'equipment': equipment,
        'injuries': injuries,
        'preferences': preferences,
        'customNotes': customNotes,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  bool get isEmpty =>
      (goal == null || goal!.isEmpty) &&
      equipment.isEmpty &&
      injuries.isEmpty &&
      preferences.isEmpty &&
      customNotes.isEmpty;

  /// Compact representation designed to be injected into system instructions with minimal token overhead
  String toContextPrompt() {
    if (isEmpty) return '';
    final lines = <String>['[USER PROFILE & PERSISTENT MEMORY]'];
    if (goal != null && goal!.isNotEmpty) {
      lines.add('• Goal: $goal');
    }
    if (equipment.isNotEmpty) {
      lines.add('• Available Equipment: ${equipment.join(", ")}');
    }
    if (injuries.isNotEmpty) {
      lines.add('• Injuries / Limitations: ${injuries.join(", ")}');
    }
    if (preferences.isNotEmpty) {
      lines.add('• Preferences: ${preferences.join(", ")}');
    }
    if (customNotes.isNotEmpty) {
      customNotes.forEach((k, v) => lines.add('• $k: $v'));
    }
    return lines.join('\n');
  }
}

/// Service that persists and manages user_memory.json in App Documents directory
class UserMemoryService {
  static final UserMemoryService _instance = UserMemoryService._internal();
  factory UserMemoryService() => _instance;
  UserMemoryService._internal();

  UserMemoryProfile? _cachedProfile;
  File? _file;

  Future<File> get _memoryFile async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/user_memory.json');
    return _file!;
  }

  /// Read memory profile (cached in RAM for instant lookup)
  Future<UserMemoryProfile> getProfile() async {
    if (_cachedProfile != null) return _cachedProfile!;
    try {
      final f = await _memoryFile;
      if (await f.exists()) {
        final content = await f.readAsString();
        if (content.trim().isNotEmpty) {
          final map = jsonDecode(content) as Map<String, dynamic>;
          _cachedProfile = UserMemoryProfile.fromJson(map);
          return _cachedProfile!;
        }
      }
    } catch (e) {
      debugPrint('UserMemoryService getProfile error: $e');
    }
    _cachedProfile = UserMemoryProfile();
    return _cachedProfile!;
  }

  /// Update memory fields and save to disk
  Future<UserMemoryProfile> updateMemory({
    String? goal,
    List<String>? addEquipment,
    List<String>? removeEquipment,
    List<String>? addInjuries,
    List<String>? removeInjuries,
    List<String>? addPreferences,
    List<String>? removePreferences,
    Map<String, dynamic>? setNotes,
  }) async {
    final profile = await getProfile();

    if (goal != null && goal.isNotEmpty) {
      profile.goal = goal;
    }

    if (addEquipment != null) {
      for (final eq in addEquipment) {
        if (!profile.equipment.any((e) => e.toLowerCase() == eq.toLowerCase())) {
          profile.equipment.add(eq);
        }
      }
    }
    if (removeEquipment != null) {
      profile.equipment.removeWhere(
          (e) => removeEquipment.any((r) => r.toLowerCase() == e.toLowerCase()));
    }

    if (addInjuries != null) {
      for (final inj in addInjuries) {
        if (!profile.injuries.any((e) => e.toLowerCase() == inj.toLowerCase())) {
          profile.injuries.add(inj);
        }
      }
    }
    if (removeInjuries != null) {
      profile.injuries.removeWhere(
          (e) => removeInjuries.any((r) => r.toLowerCase() == e.toLowerCase()));
    }

    if (addPreferences != null) {
      for (final pref in addPreferences) {
        if (!profile.preferences.any((e) => e.toLowerCase() == pref.toLowerCase())) {
          profile.preferences.add(pref);
        }
      }
    }
    if (removePreferences != null) {
      profile.preferences.removeWhere(
          (e) => removePreferences.any((r) => r.toLowerCase() == e.toLowerCase()));
    }

    if (setNotes != null) {
      profile.customNotes.addAll(setNotes);
    }

    profile.lastUpdated = DateTime.now();
    _cachedProfile = profile;

    try {
      final f = await _memoryFile;
      await f.writeAsString(jsonEncode(profile.toJson()), flush: true);
    } catch (e) {
      debugPrint('UserMemoryService write error: $e');
    }

    return profile;
  }

  /// Clear memory file if requested
  Future<void> clearMemory() async {
    _cachedProfile = UserMemoryProfile();
    try {
      final f = await _memoryFile;
      if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('UserMemoryService clear error: $e');
    }
  }
}
