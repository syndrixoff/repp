import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../ai/local_llm_service.dart';
import '../ai/gym_coach_agent.dart';
import '../ai/pose_service.dart';
import '../ai/tool_executor.dart';
import '../ai/chat_session_service.dart';
import '../ai/tools/gym_tools.dart';
import '../providers/routine_provider.dart';

enum CoachGenerationPhase { idle, thinking, generating }

class AiCoachProvider extends ChangeNotifier {
  final RoutineProvider routineProvider;
  LocalLlmService? _llm;
  GymCoachAgent? _agent;
  ToolExecutor? _executor;
  final PoseService poseService;
  final ChatSessionService _sessionService = ChatSessionService();

  List<ChatMessage> messages = [];
  String currentSessionId = const Uuid().v4();
  String currentSessionTitle = 'New Workout Chat';
  DateTime currentSessionLastUpdated = DateTime.now();

  bool isThinking = false;
  bool isThinkingModeEnabled = false;
  CoachGenerationPhase phase = CoachGenerationPhase.idle;
  String? lastToolMessage;
  PoseFrame? lastPose;

  void toggleThinkingMode() {
    isThinkingModeEnabled = !isThinkingModeEnabled;
    notifyListeners();
  }

  // Live generation & streaming metrics
  int _tokenCount = 0;
  DateTime? _firstTokenAt;
  DateTime _lastNotificationTime = DateTime.fromMillisecondsSinceEpoch(0);

  double get currentTps {
    if (_firstTokenAt == null || _tokenCount == 0) return 0.0;
    final elapsedMs = DateTime.now().difference(_firstTokenAt!).inMilliseconds;
    if (elapsedMs <= 100) return 0.0;
    return _tokenCount / (elapsedMs / 1000.0);
  }

  void _resetMetrics() {
    _tokenCount = 0;
    _firstTokenAt = null;
    _lastNotificationTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _recordChunkAndNotify(String chunk, {bool force = false}) {
    if (_firstTokenAt == null) {
      _firstTokenAt = DateTime.now();
      _tokenCount = 0;
    }
    final tokens = (chunk.length / 3.8).ceil().clamp(1, 10);
    _tokenCount += tokens;

    final now = DateTime.now();
    // Throttle to max 40-50 UI updates per second (>= 22ms) or on word boundary/force
    if (force ||
        now.difference(_lastNotificationTime).inMilliseconds >= 22 ||
        chunk.endsWith(' ') ||
        chunk.endsWith('\n')) {
      _lastNotificationTime = now;
      notifyListeners();
    }
  }

  void _updateStreamingMessage(ChatMessage msg, String raw) {
    if (raw.contains('<thought>')) {
      final parts = raw.split('</thought>');
      if (parts.length > 1) {
        msg.thinkingContent = parts[0].replaceAll('<thought>', '').trim();
        msg.content = parts.sublist(1).join('</thought>').trimLeft();
      } else {
        msg.thinkingContent = parts[0].replaceAll('<thought>', '');
        msg.content = '';
      }
    } else {
      msg.content = raw;
    }
  }

  AiCoachProvider({required this.routineProvider, PoseService? poseService})
      : poseService = poseService ?? StubPoseService() {
    _init();
  }

  Future<void> _init() async {
    _llm = await LlmServiceFactory.create();
    _agent = GymCoachAgent(llm: _llm!);
    _executor = ToolExecutor(routineProvider: routineProvider);
    poseService.poseStream.listen((f) {
      lastPose = f;
      notifyListeners();
    });
    
    // Load most recent session if available, else initialize welcome
    final sessions = await _sessionService.loadSessions();
    if (sessions.isNotEmpty) {
      loadSession(sessions.first);
    } else {
      newSession();
    }
  }

  void newSession() {
    currentSessionId = const Uuid().v4();
    currentSessionTitle = 'New Workout Chat';
    currentSessionLastUpdated = DateTime.now();
    messages = [];
    notifyListeners();
  }

  void loadSession(ChatSession session) {
    currentSessionId = session.id;
    currentSessionTitle = session.title;
    currentSessionLastUpdated = session.lastUpdatedAt;
    messages = List.from(session.messages);
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    await _sessionService.deleteSession(sessionId);
    if (currentSessionId == sessionId) {
      newSession();
    } else {
      notifyListeners();
    }
  }

  Future<void> _persistCurrentSession() async {
    final session = ChatSession(
      id: currentSessionId,
      title: currentSessionTitle,
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      messages: List.from(messages),
    );
    await _sessionService.saveSession(session);
    currentSessionTitle = session.title;
    currentSessionLastUpdated = session.lastUpdatedAt;
    notifyListeners();
  }

  /// Reload LLM service (swaps from Mock to native Fllama once weights are downloaded)
  Future<void> reloadLlm() async {
    _llm?.dispose();
    _llm = await LlmServiceFactory.create();
    _agent = GymCoachAgent(llm: _llm!);
    notifyListeners();
  }

  bool _cancelRequested = false;

  void cancelGeneration() {
    if (!isThinking) return;
    _cancelRequested = true;
    isThinking = false;
    phase = CoachGenerationPhase.idle;
    if (messages.isNotEmpty && messages.last.role == 'assistant' && messages.last.content.isEmpty) {
      messages.removeLast();
    }
    notifyListeners();
  }

  /// Undo the last turn (removes assistant response + last user message)
  void undoLastMessage() {
    if (isThinking || messages.isEmpty) return;
    // If the last message is tool output, remove it
    while (messages.isNotEmpty && messages.last.role == 'tool') {
      messages.removeLast();
    }
    // Remove assistant message
    if (messages.isNotEmpty && messages.last.role == 'assistant') {
      messages.removeLast();
    }
    // Remove user message
    if (messages.isNotEmpty && messages.last.role == 'user') {
      messages.removeLast();
    }
    notifyListeners();
    _persistCurrentSession();
  }

  /// Regenerate the last assistant response (creates a new version)
  Future<void> regenerateResponse() async {
    if (isThinking || messages.isEmpty) return;
    // Find the last user message
    int lastUserIdx = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'user') {
        lastUserIdx = i;
        break;
      }
    }
    if (lastUserIdx == -1) return;

    final userText = messages[lastUserIdx].content;
    // Check if there is an assistant response after this user message
    ChatMessage? targetAssistantMsg;
    if (lastUserIdx + 1 < messages.length && messages[lastUserIdx + 1].role == 'assistant') {
      targetAssistantMsg = messages[lastUserIdx + 1];
    }

    // Clean any trailing tools after assistant
    while (messages.length > lastUserIdx + 2) {
      messages.removeLast();
    }

    // Truncate history up to user message for agent input
    final historyContext = messages.sublist(0, lastUserIdx);

    _cancelRequested = false;
    isThinking = true;
    phase = CoachGenerationPhase.thinking;
    _resetMetrics();
    notifyListeners();

    final buf = StringBuffer();

    try {
      if (targetAssistantMsg == null) {
        targetAssistantMsg = ChatMessage(role: 'assistant', content: '');
        messages.add(targetAssistantMsg);
      } else {
        targetAssistantMsg.content = '';
        targetAssistantMsg.thinkingContent = null;
      }

      await for (final chunk in _agent!.chat(
        userText,
        history: historyContext,
        isThinking: isThinkingModeEnabled,
      )) {
        if (_cancelRequested) break;
        if (phase != CoachGenerationPhase.generating) {
          phase = CoachGenerationPhase.generating;
        }

        buf.write(chunk);
        _updateStreamingMessage(targetAssistantMsg, buf.toString());
        _recordChunkAndNotify(chunk);
      }

      if (_cancelRequested) return;
      _recordChunkAndNotify('', force: true);

      final fullRaw = buf.toString();
      final call = ToolCall.tryParse(fullRaw);
      final cleanText = ToolCall.stripToolCall(fullRaw);

      targetAssistantMsg.toolCall = call;
      targetAssistantMsg.addVersion(cleanText.isNotEmpty ? cleanText : (call != null ? 'Applying request...' : fullRaw));
      _extractThinkingIfPresent(targetAssistantMsg, fullRaw);

      // Auto-execute tools
      const autoTools = {
        'search_exercises',
        'get_exercise_details',
        'get_exercise_history',
        'update_user_memory',
        'get_user_memory',
        'explain_exercise',
        'create_routine',
        'search_web',
        'lookup_food',
      };
      if (call != null && autoTools.contains(call.tool) && _executor != null) {
        final res = await _executor!.execute(call);
        targetAssistantMsg.isToolApplied = true;
        messages.add(ChatMessage(
          role: 'tool',
          content: res.success ? '✅ ${res.message}' : '❌ ${res.message}',
        ));
      }
    } catch (e) {
      targetAssistantMsg?.addVersion('Error: $e');
    } finally {
      isThinking = false;
      phase = CoachGenerationPhase.idle;
      notifyListeners();
      await _persistCurrentSession();
    }
  }

  /// Edit a user message and re-run conversation from that point
  Future<void> editAndResend(int messageIndex, String newText) async {
    if (isThinking || messageIndex < 0 || messageIndex >= messages.length) return;
    if (messages[messageIndex].role != 'user') return;

    // Truncate all messages after this edited message
    messages[messageIndex].content = newText;
    while (messages.length > messageIndex + 1) {
      messages.removeLast();
    }
    notifyListeners();

    // Now run generation for this message
    final historyContext = messages.sublist(0, messageIndex);
    _cancelRequested = false;
    isThinking = true;
    phase = CoachGenerationPhase.thinking;
    _resetMetrics();
    notifyListeners();

    final buf = StringBuffer();

    try {
      final assistantMsg = ChatMessage(role: 'assistant', content: '');
      messages.add(assistantMsg);

      await for (final chunk in _agent!.chat(
        newText,
        history: historyContext,
        isThinking: isThinkingModeEnabled,
      )) {
        if (_cancelRequested) break;
        if (phase != CoachGenerationPhase.generating) {
          phase = CoachGenerationPhase.generating;
        }

        buf.write(chunk);
        _updateStreamingMessage(assistantMsg, buf.toString());
        _recordChunkAndNotify(chunk);
      }

      if (_cancelRequested) return;
      _recordChunkAndNotify('', force: true);

      final fullRaw = buf.toString();
      final call = ToolCall.tryParse(fullRaw);
      final cleanText = ToolCall.stripToolCall(fullRaw);

      assistantMsg.toolCall = call;
      assistantMsg.content = cleanText.isNotEmpty ? cleanText : (call != null ? 'Applying request...' : fullRaw);
      _extractThinkingIfPresent(assistantMsg, fullRaw);
      assistantMsg.versions = [assistantMsg.content];
      assistantMsg.activeVersionIndex = 0;

      const autoTools = {
        'search_exercises',
        'get_exercise_details',
        'get_exercise_history',
        'update_user_memory',
        'get_user_memory',
        'explain_exercise',
        'create_routine',
        'search_web',
        'lookup_food',
      };
      if (call != null && autoTools.contains(call.tool) && _executor != null) {
        final res = await _executor!.execute(call);
        assistantMsg.isToolApplied = true;
        messages.add(ChatMessage(
          role: 'tool',
          content: res.success ? '✅ ${res.message}' : '❌ ${res.message}',
        ));
      }
    } catch (e) {
      if (messages.isNotEmpty && messages.last.role == 'assistant') {
        messages.last.content = 'Error: $e';
      }
    } finally {
      isThinking = false;
      phase = CoachGenerationPhase.idle;
      notifyListeners();
      await _persistCurrentSession();
    }
  }

  void switchMessageVersion(ChatMessage msg, int versionIndex) {
    msg.switchVersion(versionIndex);
    notifyListeners();
    _persistCurrentSession();
  }

  String? activeVoiceTranscript;

  void updateActiveVoiceTranscript(String text) {
    activeVoiceTranscript = text;
    notifyListeners();
  }

  void clearActiveVoiceTranscript() {
    activeVoiceTranscript = null;
    notifyListeners();
  }

  Future<void> send(String text, {List<Uint8List>? imageBytes}) async {
    if (text.trim().isEmpty || _agent == null) return;
    activeVoiceTranscript = null;
    final historyContext = List<ChatMessage>.from(messages);
    messages.add(ChatMessage(
      role: 'user',
      content: text,
      imageBytes: imageBytes != null && imageBytes.isNotEmpty ? imageBytes.first : null,
    ));
    _cancelRequested = false;
    isThinking = true;
    phase = CoachGenerationPhase.thinking;
    _resetMetrics();
    lastToolMessage = null;
    notifyListeners();

    final buf = StringBuffer();

    try {
      final assistantMsg = ChatMessage(role: 'assistant', content: '');
      messages.add(assistantMsg);

      await for (final chunk in _agent!.chat(
        text,
        history: historyContext,
        imageBytes: imageBytes,
        isThinking: isThinkingModeEnabled,
      )) {
        if (_cancelRequested) break;
        if (phase != CoachGenerationPhase.generating) {
          phase = CoachGenerationPhase.generating;
        }

        buf.write(chunk);
        _updateStreamingMessage(assistantMsg, buf.toString());
        _recordChunkAndNotify(chunk);
      }

      if (_cancelRequested) return;
      _recordChunkAndNotify('', force: true);

      final fullRaw = buf.toString();
      final call = ToolCall.tryParse(fullRaw);
      final cleanText = ToolCall.stripToolCall(fullRaw);

      assistantMsg.toolCall = call;
      assistantMsg.content = cleanText.isNotEmpty ? cleanText : (call != null ? 'Applying request...' : fullRaw);
      _extractThinkingIfPresent(assistantMsg, fullRaw);
      assistantMsg.versions = [assistantMsg.content];
      assistantMsg.activeVersionIndex = 0;

      // Auto-execute query and memory tools (search, details, history, memory, create_routine)
      const autoTools = {
        'search_exercises',
        'get_exercise_details',
        'get_exercise_history',
        'update_user_memory',
        'get_user_memory',
        'explain_exercise',
        'create_routine',
        'search_web',
        'lookup_food',
      };
      if (call != null && autoTools.contains(call.tool) && _executor != null) {
        final res = await _executor!.execute(call);
        assistantMsg.isToolApplied = true;
        messages.add(ChatMessage(
          role: 'tool',
          content: res.success ? '✅ ${res.message}' : '❌ ${res.message}',
        ));
      }
    } catch (e) {
      if (messages.isNotEmpty && messages.last.role == 'assistant') {
        messages.last.content = 'Error: $e';
      }
    } finally {
      isThinking = false;
      phase = CoachGenerationPhase.idle;
      notifyListeners();
      await _persistCurrentSession();
    }
  }

  void _extractThinkingIfPresent(ChatMessage msg, String raw) {
    final match = RegExp(r'<(?:thought|think)>([\s\S]*?)<\/(?:thought|think)>').firstMatch(raw);
    if (match != null) {
      msg.thinkingContent = match.group(1)?.trim();
      final cleaned = raw.replaceAll(RegExp(r'<(?:thought|think)>[\s\S]*?<\/(?:thought|think)>'), '').trim();
      final cleanText = ToolCall.stripToolCall(cleaned);
      if (cleanText.isNotEmpty) {
        msg.content = cleanText;
        if (msg.versions.isNotEmpty && msg.activeVersionIndex < msg.versions.length) {
          msg.versions[msg.activeVersionIndex] = cleanText;
        }
      }
    }
  }

  Future<void> applyTool(ChatMessage message) async {
    final call = message.toolCall;
    if (call == null || _executor == null || message.isToolApplied) return;

    final res = await _executor!.execute(call);
    message.isToolApplied = true;
    lastToolMessage = res.message;
    messages.add(ChatMessage(
      role: 'tool',
      content: res.success ? '✅ ${res.message}' : '❌ ${res.message}',
    ));
    notifyListeners();
    await _persistCurrentSession();
  }

  Future<void> togglePose(bool enable) async {
    if (enable) {
      await poseService.start();
    } else {
      await poseService.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    poseService.dispose();
    _llm?.dispose();
    super.dispose();
  }
}
