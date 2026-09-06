import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'gym_coach_agent.dart';
import 'tools/gym_tools.dart';

/// Represents a single stored chat session
class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime lastUpdatedAt;
  List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
        'messages': messages
            .map((m) => {
                  'role': m.role,
                  'content': m.content,
                  'isToolApplied': m.isToolApplied,
                  'thinkingContent': m.thinkingContent,
                  'versions': m.versions,
                  'activeVersionIndex': m.activeVersionIndex,
                  if (m.imageBytes != null) 'imageBytes': base64Encode(m.imageBytes!),
                  if (m.toolCall != null)
                    'toolCall': {
                      'tool': m.toolCall!.tool,
                      'arguments': m.toolCall!.arguments,
                      'raw': m.toolCall!.raw,
                    },
                })
            .toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMsgs = (json['messages'] as List?) ?? [];
    final msgs = rawMsgs.map((m) {
      final map = m as Map<String, dynamic>;
      ToolCall? call;
      if (map['toolCall'] != null) {
        final tc = map['toolCall'] as Map<String, dynamic>;
        call = ToolCall(
          tool: tc['tool']?.toString() ?? '',
          arguments: (tc['arguments'] as Map?)?.cast<String, dynamic>() ?? {},
          raw: tc['raw']?.toString() ?? '',
        );
      }
      final vers = (map['versions'] as List?)?.map((e) => e.toString()).toList();
      Uint8List? imgBytes;
      if (map['imageBytes'] != null) {
        try {
          imgBytes = base64Decode(map['imageBytes'].toString());
        } catch (_) {}
      }
      return ChatMessage(
        role: map['role']?.toString() ?? 'user',
        content: map['content']?.toString() ?? '',
        isToolApplied: map['isToolApplied'] == true,
        toolCall: call,
        imageBytes: imgBytes,
        thinkingContent: map['thinkingContent']?.toString(),
        versions: vers,
        activeVersionIndex: (map['activeVersionIndex'] as int?) ?? 0,
      );
    }).toList();

    return ChatSession(
      id: json['id']?.toString() ?? const Uuid().v4(),
      title: json['title']?.toString() ?? 'New Workout Chat',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastUpdatedAt: json['lastUpdatedAt'] != null
          ? DateTime.tryParse(json['lastUpdatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      messages: msgs,
    );
  }

  /// Automatically derive/update title dynamically based on conversational context
  void autoUpdateTitle() {
    final userMsgs = messages.where((m) => m.role == 'user' && m.content.trim().isNotEmpty).toList();
    if (userMsgs.isEmpty) {
      title = 'New Workout Chat';
      return;
    }

    // Check if tools were used for specific routines/exercises
    for (final m in messages.reversed) {
      if (m.toolCall != null) {
        if (m.toolCall!.tool == 'create_routine') {
          final rName = m.toolCall!.arguments['name']?.toString();
          if (rName != null && rName.isNotEmpty) {
            title = 'Routine: $rName';
            return;
          }
        } else if (m.toolCall!.tool == 'get_exercise_details' || m.toolCall!.tool == 'get_exercise_history') {
          final exId = m.toolCall!.arguments['exerciseId']?.toString();
          if (exId != null && exId.isNotEmpty) {
            final readable = exId.replaceAll('__', ' (').replaceAll('_', ' ').trim();
            final clean = readable.endsWith(')') ? readable : '$readable)';
            title = 'Exercise: ${clean.replaceAll(')', '')}';
            return;
          }
        }
      }
    }

    // If conversation grew, synthesize topic from latest turn + first turn
    final first = userMsgs.first.content.trim();
    final latest = userMsgs.last.content.trim();

    if (userMsgs.length >= 3 && first.toLowerCase() != latest.toLowerCase()) {
      final summary = _cleanSnippet(latest);
      if (summary.isNotEmpty) {
        title = summary;
        return;
      }
    }

    title = _cleanSnippet(first);
  }

  static String _cleanSnippet(String text) {
    String clean = text
        .replaceAll(RegExp(r'[#*_`\n\r]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.length > 36) {
      clean = '${clean.substring(0, 36).trim()}...';
    }
    if (clean.isEmpty) return 'Workout Chat';
    return clean[0].toUpperCase() + clean.substring(1);
  }
}

/// Service to save, load, search, and manage chat sessions on device
class ChatSessionService {
  static final ChatSessionService _instance = ChatSessionService._internal();
  factory ChatSessionService() => _instance;
  ChatSessionService._internal();

  File? _file;
  List<ChatSession>? _cachedSessions;

  Future<File> get _sessionsFile async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/chat_sessions.json');
    return _file!;
  }

  Future<List<ChatSession>> loadSessions() async {
    if (_cachedSessions != null) return _cachedSessions!;
    try {
      final f = await _sessionsFile;
      if (await f.exists()) {
        final str = await f.readAsString();
        if (str.trim().isNotEmpty) {
          final list = jsonDecode(str) as List;
          _cachedSessions = list
              .map((s) => ChatSession.fromJson(s as Map<String, dynamic>))
              .toList();
          _sortByLastUpdated();
          return _cachedSessions!;
        }
      }
    } catch (e) {
      debugPrint('ChatSessionService load error: $e');
    }
    _cachedSessions = [];
    return _cachedSessions!;
  }

  void _sortByLastUpdated() {
    _cachedSessions?.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
  }

  Future<void> saveSession(ChatSession session) async {
    final list = await loadSessions();
    session.lastUpdatedAt = DateTime.now();
    session.autoUpdateTitle();

    final idx = list.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      list[idx] = session;
    } else {
      list.insert(0, session);
    }
    _sortByLastUpdated();
    await _persist();
  }

  Future<void> deleteSession(String sessionId) async {
    final list = await loadSessions();
    list.removeWhere((s) => s.id == sessionId);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final f = await _sessionsFile;
      final jsonList = (_cachedSessions ?? []).map((s) => s.toJson()).toList();
      await f.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      debugPrint('ChatSessionService persist error: $e');
    }
  }

  /// Search sessions by title or message content, optionally filtered by last updated date range
  List<ChatSession> search({
    String query = '',
    DateTime? filterDate,
  }) {
    if (_cachedSessions == null) return [];
    final q = query.trim().toLowerCase();

    return _cachedSessions!.where((s) {
      // Date filter based on last updated
      if (filterDate != null) {
        final sameDay = s.lastUpdatedAt.year == filterDate.year &&
            s.lastUpdatedAt.month == filterDate.month &&
            s.lastUpdatedAt.day == filterDate.day;
        if (!sameDay) return false;
      }

      if (q.isEmpty) return true;

      // Check title match
      if (s.title.toLowerCase().contains(q)) return true;

      // Check message contents match
      for (final m in s.messages) {
        if (m.content.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }
}
