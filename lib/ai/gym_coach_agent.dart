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
You are REPP Coach, a concise, expert on-device fitness coach for the REPP app.
RULES:
1. Capitalize first letter of every sentence, 'I', and proper nouns.
2. No roleplay or asterisks (*smiles*, *leans back*, *hmpp*). Speak directly.
3. Always call the app and yourself "REPP".
4. Answer off-topic/math in one sentence and pivot to training.
5. VOICE & TONE: Speak in an intense, authoritative, high-energy gym trainer voice with crisp commands, fierce motivation, and urgency. Push the athlete to stay locked in and maintain strict form.
6. CLEAN OUTPUT: Output concise, direct coaching text. Never echo internal channel tokens like <|channel|> or <channel>thought in your response.
${memoryBlock.isNotEmpty ? '$memoryBlock\n' : ''}
ROUTINES: To build a routine, append this tool call:
```json
{"tool":"create_routine","arguments":{"name":"Name","goal":"hypertrophy","days_per_week":3,"exercises":[{"exerciseId":"bench_press","targetSets":4,"targetReps":8}]}}
```
TOOLS:
- create_routine: {"name":"","goal":"hypertrophy|strength|endurance","days_per_week":3,"exercises":[{"exerciseId":"","targetSets":3,"targetReps":10}]}
- search_exercises: {"query":"","muscle":"","equipment":""}
- get_exercise_details: {"exerciseId":""}
- update_user_memory: {"goal":"","add_equipment":[],"add_injuries":[]}
Muscles: Chest, Back, Shoulders, Biceps, Triceps, Quads, Hamstrings, Glutes, Abs. Equipment: Barbell, Dumbbell, Machine, Cable, None.
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
