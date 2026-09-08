import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../ai/tts/qwen3_tts_service.dart';
import '../ai/audio/omni_duplex_controller.dart';
import 'package:image_picker/image_picker.dart';
import '../ai/local_llm_service.dart';
import '../ai/gym_coach_agent.dart';
import '../providers/ai_coach_provider.dart';
import '../widgets/pose_overlay.dart';
import '../widgets/stick_animator.dart';
import '../widgets/voice_spectrum_orb.dart';
import '../theme/app_colors.dart';
import 'ai_memory_dialog.dart';
import 'ai_chat_history_dialog.dart';
import 'home_screen.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});
  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  // ignore: prefer_final_fields
  bool _showPose = false;
  // ignore: prefer_final_fields
  bool _showStick = false;
  bool _isModelDownloaded = false;
  final ModelDownloadService _downloadService = ModelDownloadService();
  Future<ModelDownloadProgress>? _initialProgressFuture;

  StreamSubscription<bool>? _downloadStatusSub;

  final Qwen3TtsService _tts = Qwen3TtsService();
  final OmniDuplexController _omniController = OmniDuplexController();
  bool _isListening = false;
  String? _currentlySpeakingMessageId;

  // Omni Voice Experience State
  bool _isOmniVoiceActive = false;
  double _currentSoundLevel = 0.0;
  String _liveSpokenText = '';
  OmniDuplexState _omniState = OmniDuplexState.idle;
  StreamSubscription<OmniDuplexState>? _omniStateSub;
  StreamSubscription<double>? _omniSoundSub;
  StreamSubscription<String>? _omniSpokenSub;

  // Multimodal Image Attachment State
  Uint8List? _attachedImageBytes;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
    _initSpeechAndTts();
    _downloadStatusSub = _downloadService.statusStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _initSpeechAndTts() async {
    await _tts.initialize();
    _omniController.initialize(
      sendPromptHandler: (prompt, onChunk) async {
        if (!mounted) return;
        final provider = context.read<AiCoachProvider>();
        final img = _attachedImageBytes;
        if (mounted) setState(() => _attachedImageBytes = null);
        await provider.send(
          prompt,
          imageBytes: img != null ? [img] : null,
          onChunk: onChunk,
        );
      },
    );

    _omniStateSub = _omniController.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _omniState = state;
          _isListening = state == OmniDuplexState.listening || state == OmniDuplexState.userSpeaking;
          if (state == OmniDuplexState.speakingCoach) {
            _currentlySpeakingMessageId = 'omni_speaking';
          } else if (_currentlySpeakingMessageId == 'omni_speaking') {
            _currentlySpeakingMessageId = null;
          }
        });
      }
    });

    _omniSoundSub = _omniController.soundLevelStream.listen((level) {
      if (mounted) {
        setState(() => _currentSoundLevel = level);
      }
    });

    _omniSpokenSub = _omniController.liveSpokenTextStream.listen((text) {
      if (mounted) {
        setState(() => _liveSpokenText = text);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (mounted) {
          setState(() => _attachedImageBytes = bytes);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImagePickerSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  title: const Text('Take Photo (Camera)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Capture your posture, meal, or equipment for analysis'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.blueAccent),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select an existing photo from your library'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleOmniVoiceMode() async {
    if (_isOmniVoiceActive) {
      await _omniController.stopDuplexMode();
      await _tts.stop();
      if (mounted) {
        setState(() {
          _isOmniVoiceActive = false;
          _isListening = false;
          _liveSpokenText = '';
          _currentSoundLevel = 0.0;
          _currentlySpeakingMessageId = null;
        });
      }
      return;
    }

    setState(() {
      _isOmniVoiceActive = true;
      _liveSpokenText = '';
      _currentSoundLevel = 0.0;
    });
    final ok = await _omniController.startDuplexMode();
    if (!ok && mounted) {
      setState(() => _isOmniVoiceActive = false);
      final err = _omniController.error ?? 'Could not start voice mode';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  Future<void> _speak(String messageId, String text) async {
    if (_currentlySpeakingMessageId == messageId) {
      await _tts.stop();
      if (mounted) setState(() => _currentlySpeakingMessageId = null);
      return;
    }
    await _tts.stop();
    setState(() => _currentlySpeakingMessageId = messageId);
    _tts.speakText(text);
  }

  @override
  void dispose() {
    _downloadStatusSub?.cancel();
    _omniStateSub?.cancel();
    _omniSoundSub?.cancel();
    _omniSpokenSub?.cancel();
    _omniController.stopDuplexMode();
    _tts.stop();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage(AiCoachProvider provider) {
    final text = _ctrl.text.trim();
    final img = _attachedImageBytes;
    if (text.isEmpty && img == null) return;
    _ctrl.clear();
    setState(() => _attachedImageBytes = null);
    provider.send(
      text.isNotEmpty ? text : 'Please analyze this photo',
      imageBytes: img != null ? [img] : null,
    );
    _scrollToBottom();
  }

  Future<void> _checkModelStatus() async {
    _initialProgressFuture = _downloadService.getInitialProgress();
    final prog = await _initialProgressFuture!;
    if (mounted) {
      setState(() => _isModelDownloaded = prog.isCompleted);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (animated) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }
    });
  }

  void _stickToBottomIfNear() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        final pos = _scrollCtrl.position;
        // If user is within 250px of bottom, stick to bottom smoothly without fighting animations
        if (pos.maxScrollExtent - pos.pixels < 250) {
          pos.jumpTo(pos.maxScrollExtent);
        }
      }
    });
  }

  void _openMemoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AiMemoryDialog(),
    );
  }

  void _openHistoryDialog(BuildContext context, AiCoachProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AiChatHistoryDialog(
        currentSessionId: provider.currentSessionId,
        onSelectSession: (s) {
          provider.loadSession(s);
          _scrollToBottom();
        },
        onNewChat: () {
          provider.newSession();
          _scrollToBottom();
        },
        onDeleteSession: (sessionId) {
          provider.deleteSession(sessionId);
          _scrollToBottom();
        },
      ),
    );
  }

  IconData _toolChipIcon(String content) {
    if (content.contains('memory') ||
        content.contains('Memory') ||
        content.contains('USER PROFILE')) {
      return Icons.psychology_rounded;
    }
    if (content.contains('History') || content.contains('Personal Records')) {
      return Icons.bar_chart_rounded;
    }
    if (content.contains('Found') && content.contains('exercises')) {
      return Icons.search_rounded;
    }
    return Icons.fitness_center_rounded;
  }

  String _toolChipLabel(String content) {
    if (content.contains('memory') || content.contains('Memory')) {
      return 'Memory updated';
    }
    if (content.contains('No exercises found')) return 'No results found';
    if (content.contains('Found') && content.contains('exercises')) {
      final match = RegExp(r'Found \*\*(\d+)\*\*').firstMatch(content);
      final n = match?.group(1) ?? '?';
      return '$n exercises found';
    }
    if (content.contains('History') || content.contains('Personal Records')) {
      return 'Workout history loaded';
    }
    if (content.contains('### ')) return 'Exercise details loaded';
    return 'Tool result';
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiCoachProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (provider.isThinking) {
      _stickToBottomIfNear();
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        backgroundColor: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.6),
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'AI Coach',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              provider.currentSessionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.2,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Memory Viewer Icon
          IconButton(
            icon: const Icon(Icons.psychology_rounded),
            tooltip: 'View Persistent Memory',
            onPressed: () => _openMemoryDialog(context),
          ),
          // Chat History & Search Icon
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Chat Sessions & History',
            onPressed: () => _openHistoryDialog(context, provider),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0D0D1A), const Color(0xFF0A0A12)]
                : [const Color(0xFFF0F4FF), Colors.white],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Model Download Banner (REPP On-Device Multimodal AI)
              if (!_isModelDownloaded)
                _ModelDownloadBanner(
                  downloadService: _downloadService,
                  initialProgressFuture: _initialProgressFuture ?? _downloadService.getInitialProgress(),
                  isDark: isDark,
                  onCompleted: () {
                    if (mounted) {
                      setState(() => _isModelDownloaded = true);
                      context.read<AiCoachProvider>().reloadLlm();
                    }
                  },
                ),

              if (_showPose)
                SizedBox(
                  height: 180,
                  child: PoseOverlay(frame: provider.lastPose),
                ),
              if (_showStick)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Builder(builder: (context) {
                    final demo = StickAnimationData(
                      exerciseId: 'squat',
                      keyframes: [
                        StickKeyframe(t: 0, joints: {
                          'nose': const Offset(0.5, 0.15),
                          'shoulder_l': const Offset(0.42, 0.30),
                          'shoulder_r': const Offset(0.58, 0.30),
                          'elbow_l': const Offset(0.38, 0.45),
                          'elbow_r': const Offset(0.62, 0.45),
                          'hip_l': const Offset(0.45, 0.55),
                          'hip_r': const Offset(0.55, 0.55),
                          'knee_l': const Offset(0.44, 0.78),
                          'knee_r': const Offset(0.56, 0.78),
                          'ankle_l': const Offset(0.43, 0.95),
                          'ankle_r': const Offset(0.57, 0.95),
                        }),
                        StickKeyframe(t: 1, joints: {
                          'nose': const Offset(0.5, 0.22),
                          'shoulder_l': const Offset(0.42, 0.36),
                          'shoulder_r': const Offset(0.58, 0.36),
                          'elbow_l': const Offset(0.36, 0.52),
                          'elbow_r': const Offset(0.64, 0.52),
                          'hip_l': const Offset(0.43, 0.68),
                          'hip_r': const Offset(0.57, 0.68),
                          'knee_l': const Offset(0.42, 0.80),
                          'knee_r': const Offset(0.58, 0.80),
                          'ankle_l': const Offset(0.43, 0.95),
                          'ankle_r': const Offset(0.57, 0.95),
                        }),
                      ],
                    );
                    return StickAnimator(data: demo, height: 160);
                  }),
                ),
              if (_isOmniVoiceActive)
                Expanded(
                  child: _buildOmniVoiceView(context, provider, isDark),
                )
              else ...[
                if (provider.messages.isEmpty && !provider.isThinking)
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fitness_center_rounded,
                              size: 48,
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your AI Coach is ready',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ask to create a routine, explain an exercise,\nor start with voice or pose.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white24 : Colors.black26,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                )
              else
                Expanded(
                  child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: provider.messages.length,
              itemBuilder: (c, i) {
                final m = provider.messages[i];
                final isUser = m.role == 'user';
                final isTool = m.role == 'tool';
                final hasThinking = m.thinkingContent != null && m.thinkingContent!.isNotEmpty;
                final isLoading = !isUser && !isTool && m.content.isEmpty && !hasThinking;

                final isStreamingThisMsg =
                    provider.isThinking && i == provider.messages.length - 1 && !isUser && !isTool;

                final bubbleContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isUser && m.imageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          m.imageBytes!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (m.content.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (isTool) ...[
                      _ExpandableToolChip(
                        icon: _toolChipIcon(m.content),
                        label: _toolChipLabel(m.content),
                        content: m.content,
                        isDark: isDark,
                      ),
                    ],

                    // Thinking Block (Only shown once actual thinking tokens arrive, auto-collapsible)
                    if (hasThinking) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            m.isThinkingExpanded = !m.isThinkingExpanded;
                          });
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.psychology_outlined, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        m.content.isEmpty
                                            ? 'Thinking...'
                                            : 'Thought Process',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        (m.isThinkingExpanded || m.content.isEmpty)
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                  if (m.isThinkingExpanded || m.content.isEmpty) ...[
                                    const SizedBox(height: 6),
                                    if (isStreamingThisMsg)
                                      Text(
                                        m.thinkingContent!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.35,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                        ),
                                      )
                                    else
                                      MarkdownBody(
                                        data: m.thinkingContent!,
                                        styleSheet: MarkdownStyleSheet(
                                          p: TextStyle(
                                            fontSize: 11,
                                            height: 1.35,
                                            fontStyle: FontStyle.italic,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                          ),
                                          listBullet: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                          ),
                                          code: TextStyle(
                                            fontSize: 10.5,
                                            backgroundColor: isDark ? Colors.black26 : Colors.white54,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (isLoading)
                      _PulseShimmerLabel(
                        label: provider.phase == CoachGenerationPhase.thinking
                            ? 'Reasoning…'
                            : (provider.currentTps > 0
                                ? 'Generating · ${provider.currentTps.toStringAsFixed(1)} t/s'
                                : 'Generating…'),
                        isDark: isDark,
                      )
                    else if (!isTool && m.content.isNotEmpty) ...[
                      if (isStreamingThisMsg) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              provider.currentTps > 0
                                  ? 'Generating... ${provider.currentTps.toStringAsFixed(1)} t/s'
                                  : 'Generating...',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        MarkdownBody(
                          data: m.content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isUser ? Colors.black : (isDark ? Colors.grey.shade100 : Colors.black87),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _StreamingBlinkingCursor(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ] else ...[
                        MarkdownBody(
                          data: m.content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isUser ? Colors.black : null,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],

                    // Version switcher & action bar for Assistant (Undo, Regenerate, Switch Versions)
                    if (!isUser && !isTool && !isLoading) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.versions.length > 1) ...[
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.chevron_left_rounded, size: 18),
                              onPressed: m.activeVersionIndex > 0
                                  ? () => provider.switchMessageVersion(m, m.activeVersionIndex - 1)
                                  : null,
                            ),
                            Text(
                              '${m.activeVersionIndex + 1}/${m.versions.length}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.chevron_right_rounded, size: 18),
                              onPressed: m.activeVersionIndex < m.versions.length - 1
                                  ? () => provider.switchMessageVersion(m, m.activeVersionIndex + 1)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (i == provider.messages.length - 1 ||
                              (i == provider.messages.length - 2 && provider.messages.last.role == 'tool')) ...[
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => provider.regenerateResponse(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh_rounded, size: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Retry',
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => provider.undoLastMessage(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.undo_rounded, size: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Undo',
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => _speak(i.toString(), m.content),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _currentlySpeakingMessageId == i.toString()
                                        ? Icons.stop_rounded
                                        : Icons.volume_up_rounded,
                                    size: 13,
                                    color: _currentlySpeakingMessageId == i.toString()
                                        ? AppColors.primary
                                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _currentlySpeakingMessageId == i.toString() ? 'Stop' : 'Listen',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: _currentlySpeakingMessageId == i.toString() ? FontWeight.bold : FontWeight.normal,
                                      color: _currentlySpeakingMessageId == i.toString()
                                          ? AppColors.primary
                                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Edit user message button
                    if (isUser && !provider.isThinking) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            _ctrl.text = m.content;
                            provider.editAndResend(i, m.content);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, size: 11, color: Colors.black54),
                                SizedBox(width: 3),
                                Text(
                                  'Edit',
                                  style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (m.toolCall != null && m.toolCall!.tool == 'create_routine') ...[
                      const SizedBox(height: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: m.isToolApplied
                                ? AppColors.success.withValues(alpha: 0.85)
                                : Theme.of(context).colorScheme.primary,
                            foregroundColor: m.isToolApplied ? Colors.white : const Color(0xFF1A1A1A),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: m.isToolApplied
                              ? () => HomeScreen.switchTab(context, 0)
                              : () => provider.applyTool(m),
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Icon(
                              m.isToolApplied ? Icons.visibility_rounded : Icons.playlist_add_check_rounded,
                              size: 18,
                              key: ValueKey(m.isToolApplied),
                            ),
                          ),
                          label: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              m.isToolApplied ? 'Routine Saved! Tap to View' : 'Apply Routine',
                              key: ValueKey(m.isToolApplied),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );

                final bubbleWidget = isUser
                    ? Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: bubbleContent,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: isLoading
                                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                                : const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.85,
                            ),
                            decoration: BoxDecoration(
                              color: isTool
                                  ? (isDark
                                      ? AppColors.primary.withValues(alpha: 0.09)
                                      : AppColors.primary.withValues(alpha: 0.06))
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.07)
                                      : Colors.white.withValues(alpha: 0.72)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isTool
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : Colors.white.withValues(alpha: 0.6)),
                                width: 1.0,
                              ),
                            ),
                            child: bubbleContent,
                          ),
                        ),
                      );

                return RepaintBoundary(
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: bubbleWidget,
                  ),
                );
              },
            ),
          ),
          _buildInputBar(context, provider, isDark),
        ],
      ],
    ),
  ),
),
);
}

  Widget _buildInputBar(BuildContext context, AiCoachProvider provider, bool isDark) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.50)
                : Colors.white.withValues(alpha: 0.75),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image preview chip if user attached an image
                if (_attachedImageBytes != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _attachedImageBytes!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => setState(() => _attachedImageBytes = null),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Attached for Form / Food analysis',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Row(
                    children: [
                      // Photo / Image attachment button
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Attach Image (Form Check / Meal)',
                        style: IconButton.styleFrom(
                          backgroundColor: _attachedImageBytes != null
                              ? AppColors.primary.withValues(alpha: 0.22)
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                          foregroundColor: _attachedImageBytes != null
                              ? AppColors.primary
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        onPressed: !_isModelDownloaded ? null : () => _showImagePickerSheet(context, isDark),
                        icon: Icon(_attachedImageBytes != null ? Icons.image_rounded : Icons.add_photo_alternate_rounded, size: 19),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          enabled: _isModelDownloaded,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            hintText: _isModelDownloaded
                                ? (provider.isThinkingModeEnabled
                                    ? 'Ask with deep reasoning...'
                                    : 'Ask away...')
                                : 'Download model to start...',
                            prefixIcon: _isModelDownloaded
                                ? null
                                : const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                          ),
                          onSubmitted: (v) {
                            if (!_isModelDownloaded) return;
                            if (v.trim().isEmpty && _attachedImageBytes == null) return;
                            _sendMessage(provider);
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Lightbulb toggle button for Deep Thinking / Reasoning
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: provider.isThinkingModeEnabled
                            ? 'Reasoning: ON (Deep Thinking)'
                            : 'Reasoning: OFF (Fast Mode)',
                        style: IconButton.styleFrom(
                          backgroundColor: provider.isThinkingModeEnabled
                              ? AppColors.primary.withValues(alpha: 0.22)
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                          foregroundColor: provider.isThinkingModeEnabled
                              ? AppColors.primary
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        onPressed: !_isModelDownloaded ? null : () => provider.toggleThinkingMode(),
                        icon: Icon(
                          provider.isThinkingModeEnabled
                              ? Icons.lightbulb_rounded
                              : Icons.lightbulb_outline_rounded,
                          size: 20,
                          color: provider.isThinkingModeEnabled ? AppColors.primary : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Omni Voice Mode mic button
                      IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Omni Voice Mode',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: !_isModelDownloaded ? null : _toggleOmniVoiceMode,
                        icon: const Icon(Icons.mic_none_rounded, size: 20),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          minimumSize: const Size(38, 38),
                          backgroundColor: provider.isThinking
                              ? Colors.red.shade600
                              : null,
                          foregroundColor: provider.isThinking ? Colors.white : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (!_isModelDownloaded)
                            ? null
                            : () {
                                if (provider.isThinking) {
                                  provider.cancelGeneration();
                                  return;
                                }
                                if (_ctrl.text.trim().isEmpty && _attachedImageBytes == null) return;
                                _sendMessage(provider);
                              },
                        child: Icon(provider.isThinking ? Icons.stop_rounded : Icons.send, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOmniVoiceView(BuildContext context, AiCoachProvider provider, bool isDark) {
    VoiceOrbState orbState = VoiceOrbState.idle;
    if (_omniState == OmniDuplexState.userSpeaking) {
      orbState = VoiceOrbState.listening;
    } else if (_omniState == OmniDuplexState.thinking || provider.phase == CoachGenerationPhase.thinking || provider.phase == CoachGenerationPhase.generating) {
      orbState = VoiceOrbState.thinking;
    } else if (_omniState == OmniDuplexState.speakingCoach || _currentlySpeakingMessageId != null) {
      orbState = VoiceOrbState.speaking;
    } else if (_isListening) {
      orbState = VoiceOrbState.listening;
    }

    ChatMessage? lastUserMsg;
    ChatMessage? lastAssistantMsg;
    for (int i = provider.messages.length - 1; i >= 0; i--) {
      if (lastAssistantMsg == null && provider.messages[i].role == 'assistant') {
        lastAssistantMsg = provider.messages[i];
      }
      if (lastUserMsg == null && provider.messages[i].role == 'user') {
        lastUserMsg = provider.messages[i];
      }
      if (lastUserMsg != null && lastAssistantMsg != null) break;
    }

    String statusLabel = 'Listening to you...';
    if (_omniState == OmniDuplexState.userSpeaking) {
      statusLabel = 'Listening to you...';
    } else if (_omniState == OmniDuplexState.thinking || provider.phase == CoachGenerationPhase.thinking) {
      statusLabel = 'Analyzing & Thinking...';
    } else if (provider.phase == CoachGenerationPhase.generating) {
      statusLabel = 'Generating Response...';
    } else if (_omniState == OmniDuplexState.speakingCoach || _currentlySpeakingMessageId != null) {
      statusLabel = 'Coach Speaking...';
    } else if (!_isListening) {
      statusLabel = 'Tap mic below to start';
    }

    return SafeArea(
      child: Column(
        children: [
          // Omni Voice Top Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Exit to Text Chat',
                  onPressed: _toggleOmniVoiceMode,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isListening ? const Color(0xFF00E5FF) : Colors.grey,
                        shape: BoxShape.circle,
                        boxShadow: _isListening
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'OMNI VOICE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(OmniDuplexController().isTtsMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                  tooltip: OmniDuplexController().isTtsMuted ? 'Unmute TTS' : 'Mute TTS',
                  onPressed: () {
                    setState(() {
                      OmniDuplexController().isTtsMuted = !OmniDuplexController().isTtsMuted;
                      if (OmniDuplexController().isTtsMuted) {
                         _tts.stop();
                         _currentlySpeakingMessageId = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),

        // 3D Fluid Glowing Spectrum Orb (Hero Section)
        Expanded(
          flex: 5,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceSpectrumOrb(
                  size: 210,
                  state: orbState,
                  soundLevel: _currentSoundLevel,
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    statusLabel,
                    key: ValueKey(statusLabel),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Conversation Bubbles below the spectrum: User right, AI left
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              reverse: true,
              children: [
                // AI Response (Left Bubble)
                if (lastAssistantMsg != null && lastAssistantMsg.content.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.85,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: MarkdownBody(
                        data: lastAssistantMsg.content,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            color: isDark ? Colors.grey.shade100 : Colors.black87,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),

                // User Input (Right Bubble)
                if (_liveSpokenText.isNotEmpty || (lastUserMsg != null && lastUserMsg.content.isNotEmpty))
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.80,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7B1FA2), Color(0xFFD500F9)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isListening)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.mic, size: 14, color: Colors.white),
                            ),
                          Flexible(
                            child: Text(
                              _liveSpokenText.isNotEmpty ? _liveSpokenText : (lastUserMsg?.content ?? ''),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Bottom Voice Controller Bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Switch to Text Mode
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: _toggleOmniVoiceMode,
                icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                label: const Text('Text Chat', style: TextStyle(fontSize: 12)),
              ),

              // Big Center Mic Action Button
              GestureDetector(
                onTap: () async {
                  if (_isListening) {
                    await _omniController.stopDuplexMode();
                    if (mounted) setState(() => _isListening = false);
                  } else {
                    final ok = await _omniController.startDuplexMode();
                    if (!ok && context.mounted) {
                      final err = _omniController.error ?? 'Could not start voice mode';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err)),
                      );
                    }
                  }
                },
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isListening
                          ? [const Color(0xFFFF1744), const Color(0xFFD500F9)]
                          : [const Color(0xFF7B1FA2), const Color(0xFF00E5FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? const Color(0xFFFF1744) : const Color(0xFF00E5FF)).withValues(alpha: 0.4),
                        blurRadius: 18,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),

              // Interrupt / Cancel Speech
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  if (provider.isThinking) {
                    provider.cancelGeneration();
                  }
                  _omniController.stopDuplexMode();
                  _tts.stop();
                  setState(() {
                    _isListening = false;
                    _currentlySpeakingMessageId = null;
                  });
                },
                icon: const Icon(Icons.stop_circle_outlined, size: 18, color: Colors.redAccent),
                label: const Text('Stop', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}

class _StreamingBlinkingCursor extends StatefulWidget {
  final Color color;
  const _StreamingBlinkingCursor({required this.color});

  @override
  State<_StreamingBlinkingCursor> createState() => _StreamingBlinkingCursorState();
}

class _StreamingBlinkingCursorState extends State<_StreamingBlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 7,
        height: 14,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}

class _PulseShimmerLabel extends StatefulWidget {
  final String label;
  final bool isDark;
  const _PulseShimmerLabel({required this.label, required this.isDark});

  @override
  State<_PulseShimmerLabel> createState() => _PulseShimmerLabelState();
}

class _PulseShimmerLabelState extends State<_PulseShimmerLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_pulse),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableToolChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final String content;
  final bool isDark;

  const _ExpandableToolChip({
    required this.icon,
    required this.label,
    required this.content,
    required this.isDark,
  });

  @override
  State<_ExpandableToolChip> createState() => _ExpandableToolChipState();
}

class _ExpandableToolChipState extends State<_ExpandableToolChip>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _heightFactor = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _expanded = !_expanded);
            if (_expanded) {
              _ctrl.forward();
            } else {
              _ctrl.reverse();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 13, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _heightFactor,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MarkdownBody(
              data: widget.content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: widget.isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
                code: TextStyle(
                  fontSize: 10.5,
                  backgroundColor: widget.isDark ? Colors.black26 : Colors.white54,
                  color: AppColors.primary,
                ),
                h3: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelDownloadBanner extends StatefulWidget {
  final ModelDownloadService downloadService;
  final Future<ModelDownloadProgress> initialProgressFuture;
  final bool isDark;
  final VoidCallback onCompleted;

  const _ModelDownloadBanner({
    required this.downloadService,
    required this.initialProgressFuture,
    required this.isDark,
    required this.onCompleted,
  });

  @override
  State<_ModelDownloadBanner> createState() => _ModelDownloadBannerState();
}

class _ModelDownloadBannerState extends State<_ModelDownloadBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  bool _showStepsDetails = false;
  bool _requiresWifi = false;

  @override
  void initState() {
    super.initState();
    _requiresWifi = widget.downloadService.requiresWifi;
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Widget _buildStepItem({
    required LiteRtModelEntry entry,
    required bool isCompleted,
    required bool isActive,
    required int downloadedBytes,
    required bool isDark,
  }) {
    final double stepProg = isCompleted
        ? 1.0
        : (isActive
            ? (downloadedBytes / entry.sizeBytes).clamp(0.0, 1.0)
            : 0.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? (isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.03))
            : (isActive
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isCompleted
                  ? AppColors.success.withValues(alpha: 0.3)
                  : (isDark ? Colors.white10 : Colors.black12)),
        ),
      ),
      child: Row(
        children: [
          // Step Icon / Status
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? AppColors.success
                  : (isActive
                      ? AppColors.primary
                      : (isDark ? Colors.white12 : Colors.black12)),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : (isActive
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          '${entry.stepIndex}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        )),
            ),
          ),
          const SizedBox(width: 10),
          // Model info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                        color: isActive
                            ? AppColors.primary
                            : (isCompleted
                                ? (isDark ? Colors.grey.shade200 : Colors.grey.shade800)
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      ),
                    ),
                    Text(
                      entry.sizeFormatted,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.tag,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    if (isActive)
                      Text(
                        '${(stepProg * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    else if (isCompleted)
                      const Text(
                        'Ready ✓',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ModelDownloadProgress>(
      future: widget.initialProgressFuture,
      builder: (context, initialSnapshot) {
        return StreamBuilder<ModelDownloadProgress>(
          stream: widget.downloadService.progressStream,
          initialData: widget.downloadService.lastProgress ?? initialSnapshot.data,
          builder: (context, snapshot) {
            final prog = snapshot.data ?? initialSnapshot.data ?? widget.downloadService.lastProgress;
            final isDownloading = prog?.isDownloading ?? widget.downloadService.isDownloading;
            final hasPartial = prog != null && prog.downloadedBytes > 0 && !prog.isCompleted;
            final filePct = prog?.currentFilePercent ?? 0;
            final overallPct = prog?.overallPercent ?? 0;
            final fileProg = prog?.currentFileProgress ?? 0.0;
            final overallProg = prog?.progress ?? 0.0;
            final isDone = prog?.isCompleted == true;

            if (isDone) {
              WidgetsBinding.instance.addPostFrameCallback((_) => widget.onCompleted());
            }

            final Color accentColor = prog?.error != null
                ? AppColors.error
                : (isDone
                    ? AppColors.success
                    : (hasPartial && !isDownloading
                        ? Colors.orange
                        : AppColors.primary));

            final currentStep = prog?.currentStep ?? 1;

            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withValues(alpha: isDownloading ? 0.6 : 0.25),
                      width: isDownloading ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: widget.isDark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              isDone
                                  ? Icons.check_circle_rounded
                                  : (isDownloading
                                      ? Icons.downloading_rounded
                                      : Icons.auto_awesome_rounded),
                              size: 18,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isDone
                                          ? 'REPP LiteRT AI Suite Ready'
                                          : (isDownloading
                                              ? 'Downloading AI Suite [Step $currentStep/5]'
                                              : (hasPartial
                                                  ? 'AI Download Paused'
                                                  : 'REPP On-Device AI Suite')),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDone ? AppColors.success : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isDone
                                      ? 'LFM 2.5 3B VLM + Whisper + S1-mini + Qwen3-TTS'
                                      : (isDownloading
                                          ? '${prog?.currentModelName ?? "Loading..."} (${prog?.currentModelTag ?? "LiteRT"})'
                                          : '4 On-Device Models · 3.83 GB · 100% Offline'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Control Action Buttons
                          if (!isDownloading && !isDone) ...[
                            if (hasPartial)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                tooltip: 'Restart from 0%',
                                onPressed: widget.downloadService.restartDownload,
                              ),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                backgroundColor: hasPartial
                                    ? Colors.orange.withValues(alpha: 0.2)
                                    : AppColors.primary.withValues(alpha: 0.15),
                              ),
                              onPressed: () {
                                widget.downloadService.startDownload(requireWifi: _requiresWifi);
                              },
                              icon: Icon(
                                hasPartial ? Icons.play_arrow_rounded : Icons.download_rounded,
                                size: 15,
                                color: hasPartial ? Colors.orange : AppColors.primary,
                              ),
                              label: Text(
                                hasPartial ? 'Resume' : 'Download',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: hasPartial ? Colors.orange : AppColors.primary,
                                ),
                              ),
                            ),
                          ] else if (isDownloading) ...[
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                backgroundColor: Colors.red.withValues(alpha: 0.15),
                              ),
                              onPressed: widget.downloadService.pauseDownload,
                              icon: const Icon(Icons.pause_rounded, size: 15, color: Colors.redAccent),
                              label: const Text(
                                'Pause',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Progress Bar & Real-Time Stats
                      if (isDownloading || hasPartial) ...[
                        const SizedBox(height: 12),
                        // Current File Progress Bar
                        AnimatedBuilder(
                          animation: _shimmerCtrl,
                          builder: (context, child) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  LinearProgressIndicator(
                                    value: fileProg,
                                    minHeight: 10,
                                    backgroundColor: widget.isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDownloading ? AppColors.primary : Colors.orange,
                                    ),
                                  ),
                                  if (isDownloading)
                                    Positioned.fill(
                                      child: FractionallySizedBox(
                                        widthFactor: fileProg,
                                        alignment: Alignment.centerLeft,
                                        child: ShaderMask(
                                          shaderCallback: (rect) {
                                            final shimX = _shimmerCtrl.value;
                                            return LinearGradient(
                                              begin: Alignment(-1 + shimX * 2, 0),
                                              end: Alignment(shimX * 2, 0),
                                              colors: const [
                                                Colors.transparent,
                                                Colors.white38,
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.5, 1.0],
                                            ).createShader(rect);
                                          },
                                          child: Container(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),

                        // Active File Stats Badges Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Current Active File Downloaded
                            Expanded(
                              child: Text(
                                'Step $currentStep/5: $filePct% (${prog?.currentFileDownloadedFormatted ?? "0 MB"} / ${prog?.currentFileTotalFormatted ?? "..."})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: widget.isDark ? Colors.grey.shade200 : Colors.grey.shade900,
                                ),
                              ),
                            ),
                            if (isDownloading)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Speed badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.bolt_rounded, size: 11, color: AppColors.primary),
                                        const SizedBox(width: 2),
                                        Text(
                                          prog?.speedFormatted ?? '-- MB/s',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // ETA badge
                                  Text(
                                    prog?.etaFormatted ?? 'Calculating...',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              )
                            else if (hasPartial)
                              const Text(
                                'Paused',
                                style: TextStyle(fontSize: 10.5, color: Colors.orange, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Total Suite Progress Bar & Label
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: overallProg,
                                  minHeight: 4,
                                  backgroundColor: widget.isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.05),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    (isDownloading ? AppColors.primary : Colors.orange).withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Suite: $overallPct% (${prog?.downloadedFormatted ?? "0 MB"} / ${prog?.totalFormatted ?? "3.83 GB"})',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ] else if (prog?.error != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                prog?.error ?? 'Download failed. Check connection and retry.',
                                style: const TextStyle(fontSize: 11, color: AppColors.error),
                              ),
                            ),
                            TextButton(
                              onPressed: () => widget.downloadService.startDownload(requireWifi: _requiresWifi),
                              child: const Text('Retry', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],

                      // Expandable Step-by-Step Suite Details
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() => _showStepsDetails = !_showStepsDetails);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _showStepsDetails
                                    ? 'Hide Suite Model Details'
                                    : 'View All 5 Model Files (VLM, ASR, S1, TTS)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              Icon(
                                _showStepsDetails
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_showStepsDetails) ...[
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: ModelDownloadService.suiteEntries.map((e) {
                                final isEntryDone = isDone || widget.downloadService.isEntryCompleted(e);
                                final isEntryActive = isDownloading && prog?.currentStep == e.stepIndex;
                                final dlBytes = isEntryActive
                                    ? (prog?.currentFileDownloadedBytes ?? 0)
                                    : widget.downloadService.getDownloadedBytesForEntry(e.id);

                                return _buildStepItem(
                                  entry: e,
                                  isCompleted: isEntryDone,
                                  isActive: isEntryActive,
                                  downloadedBytes: dlBytes,
                                  isDark: widget.isDark,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // WiFi only toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _requiresWifi ? Icons.wifi_rounded : Icons.cell_tower_rounded,
                                  size: 14,
                                  color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _requiresWifi ? 'Download on Wi-Fi Only' : 'Allow Cellular Data',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: _requiresWifi,
                              activeTrackColor: AppColors.primary,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (val) {
                                setState(() {
                                  _requiresWifi = val;
                                  widget.downloadService.requiresWifi = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

