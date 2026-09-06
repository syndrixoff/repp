import 'dart:async';
import 'dart:typed_data';
import '../services/exercise_service.dart';
import 'local_llm_service.dart';
import 'memory/user_memory_service.dart';
import 'tools/gym_tools.dart';

class ChatMessage {
  final String role; // user / assistant / tool
  String content;
  ToolCall? toolCall;
  final Uint8List? imageBytes;
  final Uint8List? audioBytes;
  final List<Uint8List>? videoFrames;
  bool isToolApplied;
  String? thinkingContent;
  bool isThinkingExpanded;
  List<String> versions;
  int activeVersionIndex;

  ChatMessage({
    required this.role,
    required this.content,
    this.toolCall,
    this.imageBytes,
    this.audioBytes,
    this.videoFrames,
    this.isToolApplied = false,
    this.thinkingContent,
    this.isThinkingExpanded = false,
    List<String>? versions,
    this.activeVersionIndex = 0,
  }) : versions = versions ?? [content];

  void addVersion(String newContent) {
    versions.add(newContent);
    activeVersionIndex = versions.length - 1;
    content = newContent;
  }

  void switchVersion(int index) {
    if (index >= 0 && index < versions.length) {
      activeVersionIndex = index;
      content = versions[index];
    }
  }
}

class GymCoachAgent {
  final LocalLlmService llm;
  final ExerciseService exerciseService;
  final UserMemoryService _memory = UserMemoryService();

  GymCoachAgent({required this.llm, ExerciseService? exerciseService})
      : exerciseService = exerciseService ?? ExerciseService();

  Future<String> _systemPrompt() async {
    final profile = await _memory.getProfile();
    final memoryBlock = profile.toContextPrompt();

    return '''
You are REPP Coach, an encouraging, knowledgeable, and witty on-device fitness coach.
Design routines, explain How-To exercise form, check user PRs/history, remember profile/equipment, and motivate.
${memoryBlock.isNotEmpty ? '$memoryBlock\n' : ''}
CRITICAL INSTRUCTION FOR WORKOUT ROUTINES:
When the user asks to create, design, or generate a workout plan, routine, or program, you MUST create it using the create_routine tool.
Write your friendly advice in conversational text, and append the create_routine tool call as a JSON block:
```json
{
  "tool": "create_routine",
  "arguments": {
    "name": "Routine Name",
    "goal": "hypertrophy",
    "days_per_week": 3,
    "exercises": [
      {"exerciseId": "bench_press", "targetSets": 4, "targetReps": 8},
      {"exerciseId": "incline_dumbbell_press", "targetSets": 3, "targetReps": 10}
    ]
  }
}
```

TOOLS:
- create_routine: {"name":"...", "goal":"hypertrophy|strength|endurance", "days_per_week":3, "exercises":[{"exerciseId":"...","targetSets":4,"targetReps":8}]}
- search_exercises: {"query":"...", "muscle":"...", "equipment":"..."}
- get_exercise_details: {"exerciseId":"bench_press__barbell_"}
- get_exercise_history: {"exerciseId":"bench_press__barbell_"}
- update_user_memory: {"goal":"...", "add_equipment":[...], "add_injuries":[...], "add_preferences":[...]}
Filters: Muscles (Chest, Back, Shoulders, Biceps, Triceps, Forearms, Quadriceps, Hamstrings, Glutes, Calves, Abs); Equipment (Barbell, Dumbbell, Machine, Cable, Kettlebell, Resistance Band, None).
For math/off-topic, answer concisely with a witty remark pivoting back to training.
''';
  }

  String _buildUserPrompt(String user, {List<ChatMessage>? history}) {
    final buf = StringBuffer();
    if (history != null && history.isNotEmpty) {
      // Exclude raw tool outputs from prompt history to save context and speed up prefill
      final valid = history.where((h) => h.content.trim().isNotEmpty && h.role != 'tool').toList();
      // Sliding window: keep up to last 6 user/assistant turns
      final window = valid.skip((valid.length - 6).clamp(0, valid.length));
      for (final h in window) {
        buf.writeln('${h.role}: ${h.content}');
      }
    }
    buf.writeln('user: $user');
    return buf.toString();
  }

  Stream<String> chat(
    String user, {
    String? poseContext,
    List<ChatMessage>? history,
    List<Uint8List>? imageBytes,
    Uint8List? audioBytes,
    List<Uint8List>? videoFrames,
    bool isThinking = false,
  }) async* {
    final sys = await _systemPrompt();
    final prompt = _buildUserPrompt(user, history: history);
    yield* llm.generate(
      prompt,
      systemPrompt: sys,
      imageBytes: imageBytes,
      audioBytes: audioBytes,
      videoFrames: videoFrames,
      poseContext: null,
      isThinking: isThinking,
    );
  }

  Future<String> chatOneShot(
    String user, {
    String? poseContext,
    List<ChatMessage>? history,
    List<Uint8List>? imageBytes,
    Uint8List? audioBytes,
    List<Uint8List>? videoFrames,
    bool isThinking = false,
  }) async {
    final sys = await _systemPrompt();
    final prompt = _buildUserPrompt(user, history: history);
    return llm.generateOneShot(
      prompt,
      systemPrompt: sys,
      imageBytes: imageBytes,
      audioBytes: audioBytes,
      videoFrames: videoFrames,
      poseContext: null,
      isThinking: isThinking,
    );
  }
}
