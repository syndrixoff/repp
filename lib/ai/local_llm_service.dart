import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_flutter_gemma/genkit_flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'audio/whisper_asr_service.dart' show WhisperAsrService;
import 'audio/s1_cleanup_service.dart' show S1CleanupService;
import 'tts/gemma_speech_tts_service.dart' show GemmaSpeechTtsService;

/// Multimodal input bundle for on-device Gemma 4 E2B inference
class MultimodalInput {
  final String text;
  final List<Uint8List>? imageBytes;
  final Uint8List? audioBytes;
  final List<Uint8List>? videoFrames;
  final String? poseContext;

  const MultimodalInput({
    required this.text,
    this.imageBytes,
    this.audioBytes,
    this.videoFrames,
    this.poseContext,
  });
}

/// Abstract service - swap Mock <-> Fllama without touching callers.
abstract class LocalLlmService {
  Future<void> initialize();
  Future<bool> get isModelReady;
  Stream<String> generate(
    String prompt, {
    String? systemPrompt,
    List<Uint8List>? imageBytes,
    Uint8List? audioBytes,
    List<Uint8List>? videoFrames,
    String? poseContext,
    bool isThinking = false,
  });
  Future<String> generateOneShot(
    String prompt, {
    String? systemPrompt,
    List<Uint8List>? imageBytes,
    Uint8List? audioBytes,
    List<Uint8List>? videoFrames,
    String? poseContext,
    bool isThinking = false,
  });
  Future<void> warmup();
  void unloadAllModels();
  void dispose();
}

/// Model entry specification in the REPP on-device LiteRT AI suite
class LiteRtModelEntry {
  final String id;
  final String name;
  final String tag;
  final String filename;
  final String url;
  final int sizeBytes;
  final int stepIndex; // 1-based position in the suite
  final bool isCore; // true for primary VLM
  final bool isBundled; // true if packaged inside app assets (no download needed)
  final bool isEngineManaged; // true if installed via FlutterGemma builders
  // into engine storage (not modelDir) — completion is checked via
  // hasActiveStt()/hasActiveTts(), not file existence.

  const LiteRtModelEntry({
    required this.id,
    required this.name,
    required this.tag,
    required this.filename,
    required this.url,
    required this.sizeBytes,
    required this.stepIndex,
    this.isCore = false,
    this.isBundled = false,
    this.isEngineManaged = false,
  });

  String get sizeFormatted {
    if (isBundled) return '2.3 MB (In-App)';
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

/// Download progress state with multi-model suite tracking
class ModelDownloadProgress {
  final int downloadedBytes;
  final int totalBytes;
  final int currentFileDownloadedBytes;
  final int currentFileTotalBytes;
  final double progress; // 0.0 - 1.0
  final double speedBytesPerSecond;
  final int? etaSeconds;
  final String? currentPhase;
  final String? currentModelName;
  final String? currentModelTag;
  final int currentStep;
  final int totalSteps;
  final bool isDownloading;
  final bool isCompleted;
  final String? error;

  const ModelDownloadProgress({
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.currentFileDownloadedBytes = 0,
    this.currentFileTotalBytes = 0,
    this.progress = 0.0,
    this.speedBytesPerSecond = 0.0,
    this.etaSeconds,
    this.currentPhase,
    this.currentModelName,
    this.currentModelTag,
    this.currentStep = 1,
    this.totalSteps = 6,
    this.isDownloading = false,
    this.isCompleted = false,
    this.error,
  });

  String get speedFormatted {
    if (speedBytesPerSecond <= 0) return '-- MB/s';
    if (speedBytesPerSecond >= 1024 * 1024) {
      return '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speedBytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
  }

  String get etaFormatted {
    if (etaSeconds == null || etaSeconds! <= 0) return 'Calculating...';
    if (etaSeconds! >= 3600) {
      final hours = etaSeconds! ~/ 3600;
      final minutes = (etaSeconds! % 3600) ~/ 60;
      return '${hours}h ${minutes}m left';
    } else if (etaSeconds! >= 60) {
      final minutes = etaSeconds! ~/ 60;
      final seconds = etaSeconds! % 60;
      return '${minutes}m ${seconds}s left';
    } else {
      return '${etaSeconds}s left';
    }
  }

  String get downloadedFormatted {
    if (downloadedBytes >= 1024 * 1024 * 1024) {
      return '${(downloadedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  String get totalFormatted {
    if (totalBytes >= 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  double get currentFileProgress {
    if (currentFileTotalBytes <= 0) return 0.0;
    return (currentFileDownloadedBytes / currentFileTotalBytes).clamp(0.0, 1.0);
  }

  int get currentFilePercent => (currentFileProgress * 100).toInt();

  int get overallPercent => (progress * 100).toInt();

  String get currentFileDownloadedFormatted {
    if (currentFileDownloadedBytes >= 1024 * 1024 * 1024) {
      return '${(currentFileDownloadedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(currentFileDownloadedBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  String get currentFileTotalFormatted {
    if (currentFileTotalBytes >= 1024 * 1024 * 1024) {
      return '${(currentFileTotalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(currentFileTotalBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

/// Handles on-device LiteRT model suite downloading with sequential queue,
/// HTTP Range resume, ETA, background service, and persistent progress.
class ModelDownloadService {
  static final ModelDownloadService _instance = ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;
  ModelDownloadService._internal();

  /// 3-Model on-device suite: Gemma 4 E2B core (file) + Silero VAD (bundled)
  /// + moonshine STT + Qwen3-TTS (both engine-managed via FlutterGemma
  /// builders into engine storage). Zero OS fallbacks.
  static const List<LiteRtModelEntry> suiteEntries = [
    LiteRtModelEntry(
      id: 'vlm',
      name: 'Gemma 4 E2B Multimodal',
      tag: 'Core Multimodal Coach',
      filename: 'gemma-4-E2B-it.litertlm',
      url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
      sizeBytes: 2708471808, // ~2.52 GB
      stepIndex: 1,
      isCore: true,
    ),
    LiteRtModelEntry(
      id: 'vad',
      name: 'Silero VAD v5 (ONNX)',
      tag: 'Voice Activity Filter (In-App)',
      filename: 'silero_vad_v5.onnx',
      url: '',
      sizeBytes: 2300000, // ~2.3 MB (bundled in assets)
      stepIndex: 2,
      isBundled: true,
    ),
    LiteRtModelEntry(
      id: 'stt',
      name: 'Moonshine Tiny (STT)',
      tag: 'Voice Input (flutter_gemma engine)',
      filename: 'moonshine_tiny_5s_f32.tflite',
      url: 'https://huggingface.co/litert-community/moonshine-tiny/resolve/main/moonshine_tiny_5s_f32.tflite',
      // 109,373,140 model bytes exact (HF blobs API) + ~1.2MB tokenizer.json
      sizeBytes: 110600000, // ~105 MB bundle
      stepIndex: 3,
      isEngineManaged: true,
    ),
    LiteRtModelEntry(
      id: 'tts',
      name: 'Inflect-Nano-v2 (LiteRT)',
      tag: 'Coach Voice (flutter_gemma engine)',
      filename: 'inflect-nano-bundle',
      url: 'https://huggingface.co/sasha-denisov/inflect-nano-v2-litert/resolve/main/',
      // Exact manifest sum (HF blobs APIs): enc_fp16 1,782,268 +
      // dec_fp16 6,375,948 + config 2,071 + dict.gz 1,762,038 +
      // dp_g2p_fp16 25,785,872 + g2p_meta 1,904
      sizeBytes: 35710101, // ~34 MB bundle
      stepIndex: 4,
      isEngineManaged: true,
    ),
    LiteRtModelEntry(
      id: 's1',
      name: 'S1-mini Q4 (ONNX)',
      tag: 'Thinking Cleanup (onnxruntime)',
      filename: 's1-q4-bundle',
      url: 'https://huggingface.co/onnx-community/s1-mini-ONNX/resolve/main/',
      // Exact file sum (HF blobs API): model_q4.onnx 369,635 +
      // model_q4.onnx_data 403,007,488 + tokenizer.json 9,117,036 +
      // config.json 1,617. SHA256-verified per file by S1CleanupService.
      sizeBytes: 412495776, // ~394 MB bundle
      stepIndex: 5,
    ),
  ];

  static const int estimatedTotalBytes = 3269577685; // ~3.05 GB
  static const int estimatedCoreBytes = 2708471808; // Core Gemma 4 E2B ~2.52 GB

  // Backward compatibility alias
  static const String modelFileName = 'gemma-4-E2B-it.litertlm';
  static const String modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  final StreamController<ModelDownloadProgress> _progressController =
      StreamController<ModelDownloadProgress>.broadcast();
  Stream<ModelDownloadProgress> get progressStream => _progressController.stream;

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  ModelDownloadProgress? _lastProgress;
  ModelDownloadProgress? get lastProgress => _lastProgress;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;
  final Map<String, int> _downloadedBytesByEntryId = {};
  int _lastTotalDownloadedBytes = 0;

  bool? _isDownloadedCache;
  bool get isDownloaded => _isDownloadedCache ?? false;

  DateTime? _lastProgressEmitTime;
  DownloadTask? _currentTask;
  LiteRtModelEntry? _currentEntry;
  bool _initialized = false;

  bool requiresWifi = false;

  int getDownloadedBytesForEntry(String id) => _downloadedBytesByEntryId[id] ?? 0;

  bool isEntryCompleted(LiteRtModelEntry entry) {
    if (entry.isBundled) return true;
    final len = _downloadedBytesByEntryId[entry.id] ?? 0;
    return len >= (entry.sizeBytes * 0.95);
  }

  Future<void> _ensureAndroidPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {}

    try {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    } catch (_) {}
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await FileDownloader().configure(
        globalConfig: [
          (Config.runInForeground, Config.always),
        ],
      );

      FileDownloader().configureNotification(
        running: const TaskNotification(
          'REPP AI Suite: {displayName}',
          '{progress} ({networkSpeed}) · {timeRemaining} remaining',
        ),
        complete: const TaskNotification(
          'REPP AI Suite Ready ✓',
          'All on-device LiteRT models downloaded & ready offline',
        ),
        error: const TaskNotification(
          'REPP AI Download Paused',
          '{displayName} interrupted. Tap to resume',
        ),
        paused: const TaskNotification(
          'REPP AI Download Paused',
          '{displayName} paused. Tap to resume',
        ),
        progressBar: true,
      );

      FileDownloader().registerCallbacks(
        taskStatusCallback: _handleStatusUpdate,
        taskProgressCallback: _handleProgressUpdate,
      );

      FileDownloader().updates.listen((update) {
        if (update is TaskProgressUpdate) {
          _handleProgressUpdate(update);
        } else if (update is TaskStatusUpdate) {
          _handleStatusUpdate(update);
        }
      });

      await FileDownloader().start(
        doTrackTasks: true,
        doRescheduleKilledTasks: true,
      );
    } catch (e) {
      debugPrint('ModelDownloadService init error: $e');
    }
  }

  LiteRtModelEntry? _findEntryByTaskId(String taskId) {
    for (final e in suiteEntries) {
      if ('repp-ai-${e.id}' == taskId) return e;
    }
    return null;
  }

  void _handleProgressUpdate(TaskProgressUpdate update) {
    final entry = _findEntryByTaskId(update.task.taskId);
    if (entry == null) return;

    _currentEntry = entry;
    final taskProg = update.progress >= 0.0 ? update.progress.clamp(0.0, 1.0) : 0.0;
    final fileDownloaded = (taskProg * entry.sizeBytes).round();
    _downloadedBytesByEntryId[entry.id] = fileDownloaded;

    int totalDownloaded = 0;
    for (final e in suiteEntries) {
      totalDownloaded += _downloadedBytesByEntryId[e.id] ?? 0;
    }
    totalDownloaded = totalDownloaded.clamp(0, estimatedTotalBytes);
    _lastTotalDownloadedBytes = totalDownloaded;

    final overallProg = (totalDownloaded / estimatedTotalBytes).clamp(0.0, 1.0);

    if (!_isDownloading) {
      _isDownloading = true;
      _statusController.add(true);
    }

    final speedBytes =
        update.networkSpeed > 0 ? (update.networkSpeed * 1024 * 1024) : 0.0;
    final etaSec =
        update.timeRemaining.inSeconds > 0 ? update.timeRemaining.inSeconds : null;

    _emitProgress(ModelDownloadProgress(
      downloadedBytes: totalDownloaded,
      totalBytes: estimatedTotalBytes,
      currentFileDownloadedBytes: fileDownloaded,
      currentFileTotalBytes: entry.sizeBytes,
      progress: overallProg,
      speedBytesPerSecond: speedBytes,
      etaSeconds: etaSec,
      currentPhase: '${entry.name} (${entry.stepIndex}/${suiteEntries.length})',
      currentModelName: entry.name,
      currentModelTag: entry.tag,
      currentStep: entry.stepIndex,
      totalSteps: suiteEntries.length,
      isDownloading: true,
    ));
  }

  void _handleStatusUpdate(TaskStatusUpdate update) {
    final entry = _findEntryByTaskId(update.task.taskId);
    if (entry == null) return;

    if (update.status == TaskStatus.complete) {
      _downloadedBytesByEntryId[entry.id] = entry.sizeBytes;
      unawaited(() async {
        await _syncCompletedFile(entry);
        await _advanceQueue();
      }());
    } else if (update.status == TaskStatus.paused ||
        update.status == TaskStatus.canceled) {
      _isDownloading = false;
      _statusController.add(false);
      _emitProgress(
        ModelDownloadProgress(
          downloadedBytes: _lastTotalDownloadedBytes,
          totalBytes: estimatedTotalBytes,
          currentFileDownloadedBytes: _downloadedBytesByEntryId[entry.id] ?? 0,
          currentFileTotalBytes: entry.sizeBytes,
          progress: (_lastTotalDownloadedBytes / estimatedTotalBytes).clamp(0.0, 1.0),
          currentPhase: 'Paused at ${entry.name}',
          currentModelName: entry.name,
          currentModelTag: entry.tag,
          currentStep: entry.stepIndex,
          totalSteps: suiteEntries.length,
          isDownloading: false,
        ),
        immediate: true,
      );
    } else if (update.status == TaskStatus.failed) {
      _isDownloading = false;
      _statusController.add(false);
      _emitProgress(
        ModelDownloadProgress(
          downloadedBytes: _lastTotalDownloadedBytes,
          totalBytes: estimatedTotalBytes,
          error: 'Download failed for ${entry.name}. Tap retry.',
          currentModelName: entry.name,
          currentModelTag: entry.tag,
          currentStep: entry.stepIndex,
          totalSteps: suiteEntries.length,
          isDownloading: false,
        ),
        immediate: true,
      );
    } else if (update.status == TaskStatus.running ||
        update.status == TaskStatus.enqueued) {
      if (!_isDownloading) {
        _isDownloading = true;
        _statusController.add(true);
      }
      _emitProgress(
        ModelDownloadProgress(
          downloadedBytes: _lastTotalDownloadedBytes,
          totalBytes: estimatedTotalBytes,
          currentFileDownloadedBytes: _downloadedBytesByEntryId[entry.id] ?? 0,
          currentFileTotalBytes: entry.sizeBytes,
          progress: (_lastTotalDownloadedBytes / estimatedTotalBytes).clamp(0.0, 1.0),
          currentPhase: '${entry.name} (${entry.stepIndex}/${suiteEntries.length})',
          currentModelName: entry.name,
          currentModelTag: entry.tag,
          currentStep: entry.stepIndex,
          totalSteps: suiteEntries.length,
          isDownloading: true,
        ),
        immediate: true,
      );
    }
  }

  Directory? _cachedModelDir;

  /// Unified shared directory across Syndrix apps (REPP, InkVoice, etc.)
  Future<Directory> get modelDir async {
    if (_cachedModelDir != null) {
      return _cachedModelDir!;
    }
    if (Platform.isAndroid) {
      try {
        final sharedDocs = Directory('/storage/emulated/0/Documents/Syndrix/models');
        if (!await sharedDocs.exists()) {
          await sharedDocs.create(recursive: true);
        }
        _cachedModelDir = sharedDocs;
        return sharedDocs;
      } catch (_) {
        try {
          final sharedDownloads = Directory('/storage/emulated/0/Download/Syndrix/models');
          if (!await sharedDownloads.exists()) {
            await sharedDownloads.create(recursive: true);
          }
          _cachedModelDir = sharedDownloads;
          return sharedDownloads;
        } catch (_) {}
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/models');
    if (!await d.exists()) await d.create(recursive: true);
    _cachedModelDir = d;
    return d;
  }

  Future<File> getEntryFile(LiteRtModelEntry entry) async {
    final d = await entryDir(entry);
    final fresh = File('${d.path}/${entry.filename}');
    // Legacy fallback: on devices that deny the move (no all-files access),
    // keep using the valid flat-layout file instead of re-downloading GBs.
    try {
      if (!await fresh.exists()) {
        final models = await modelDir;
        final legacy = File('${models.path}/${entry.filename}');
        if (await legacy.exists() &&
            await legacy.length() >= (entry.sizeBytes * 0.95)) {
          return legacy;
        }
      }
    } catch (_) {}
    return fresh;
  }

  /// Per-model subfolder: models/gemma-4-e2b/, models/moonshine-tiny/, …
  Future<Directory> entryDir(LiteRtModelEntry entry) async {
    final d = await modelDir;
    final sub = _subdirFor(entry.id);
    final dir = Directory('${d.path}/$sub');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _subdirFor(String entryId) {
    switch (entryId) {
      case 'vlm':
        return 'gemma-4-e2b';
      case 'vad':
        return 'silero-vad';
      case 'stt':
        return 'moonshine-tiny';
      case 'tts':
        return 'inflect-nano';
      case 's1':
        return 's1-mini-q4';
      default:
        return entryId;
    }
  }

  /// One-time migration from the old flat layout (`models/<file>`) to
  /// per-model subfolders. Moves valid files instead of re-downloading.
  Future<void> _migrateEntryFiles(LiteRtModelEntry entry) async {
    try {
      final d = await modelDir;
      final target = await entryDir(entry);
      final fresh = File('${target.path}/${entry.filename}');
      if (await fresh.exists()) return;
      final legacy = File('${d.path}/${entry.filename}');
      if (await legacy.exists()) {
        await legacy.rename(fresh.path);
        debugPrint('[ModelDownloadService] Migrated ${entry.id} to subfolder.');
      }
    } catch (e) {
      debugPrint('[ModelDownloadService] Migration notice: $e');
    }
  }

  /// Core VLM model file (Gemma 4 only, zero fallbacks)
  Future<File> get coreVlmFile async {
    return getEntryFile(suiteEntries.first);
  }

  // Alias for backward compatibility
  Future<File> get modelFile => coreVlmFile;

  Future<File> get vadFile async {
    final entry = suiteEntries.firstWhere((e) => e.id == 'vad');
    return getEntryFile(entry);
  }

  /// True when the engine-managed STT bundle (moonshine) is installed.
  /// Guarded — FlutterGemma may be uninitialized (e.g. unit tests).
  Future<bool> get isSttEngineReady async {
    try {
      return FlutterGemma.hasActiveStt();
    } catch (_) {
      return false;
    }
  }

  /// True when the engine-managed TTS bundle (Qwen3-TTS) is installed.
  Future<bool> get isTtsEngineReady async {
    try {
      return FlutterGemma.hasActiveTts();
    } catch (_) {
      return false;
    }
  }

  Future<int> _getFileBytes(File file) async {
    try {
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  /// Verify integrity of a specific model entry on disk
  Future<bool> verifyEntryIntegrity(LiteRtModelEntry entry) async {
    if (entry.isBundled) return true;
    if (entry.isEngineManaged) return isEngineEntryReady(entry);
    if (entry.id == 's1') return S1CleanupService().isReady();
    final f = await getEntryFile(entry);
    if (!await f.exists()) return false;
    final len = await _getFileBytes(f);
    return len >= (entry.sizeBytes * 0.95);
  }

  /// Engine-managed entries (STT/TTS) live in flutter_gemma storage —
  /// readiness is the active-model flag, not a file on disk.
  Future<bool> isEngineEntryReady(LiteRtModelEntry entry) async {
    if (entry.id == 'stt') return isSttEngineReady;
    if (entry.id == 'tts') return isTtsEngineReady;
    return false;
  }

  /// True if all 4 models in the suite (all 5 files) are present and verified on disk
  Future<bool> isModelDownloaded({bool forceCheck = false}) async {
    if (!forceCheck && _isDownloadedCache == true) return true;
    final valid = await isFullSuiteDownloaded();
    if (valid) {
      _isDownloadedCache = true;
      return true;
    }
    _isDownloadedCache = false;
    return false;
  }

  /// True if the full suite (core file + bundled + engine-managed) is ready
  Future<bool> isFullSuiteDownloaded() async {
    for (final e in suiteEntries) {
      if (e.isBundled) continue;
      await _migrateEntryFiles(e);
      if (e.isEngineManaged) {
        if (!await isEngineEntryReady(e)) return false;
        continue;
      }
      if (e.id == 's1') {
        if (!await S1CleanupService().isReady()) return false;
        continue;
      }
      final f = await getEntryFile(e);
      if (!await f.exists()) return false;
      final len = await _getFileBytes(f);
      if (len < (e.sizeBytes * 0.95)) return false;
    }
    return true;
  }

  void _emitProgress(ModelDownloadProgress progress, {bool immediate = false}) {
    _lastProgress = progress;
    if (progress.isCompleted) {
      _isDownloadedCache = true;
    }
    final now = DateTime.now();
    if (!immediate && _lastProgressEmitTime != null) {
      if (now.difference(_lastProgressEmitTime!).inMilliseconds < 250) {
        return;
      }
    }
    _lastProgressEmitTime = now;
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  /// Scan existing disk files (including existing models after app reinstall)
  Future<ModelDownloadProgress> getInitialProgress() async {
    if (_lastProgress != null) {
      return _lastProgress!;
    }

    await init();

    int totalOnDisk = 0;
    bool allValid = true;

    for (final e in suiteEntries) {
      if (e.isBundled) {
        _downloadedBytesByEntryId[e.id] = e.sizeBytes;
        totalOnDisk += e.sizeBytes;
        continue;
      }
      await _migrateEntryFiles(e);
      if (e.isEngineManaged) {
        final ready = await isEngineEntryReady(e);
        final len = ready ? e.sizeBytes : 0;
        _downloadedBytesByEntryId[e.id] = len;
        totalOnDisk += len;
        if (!ready) allValid = false;
        continue;
      }
      if (e.id == 's1') {
        final ready = await S1CleanupService().isReady();
        final len = ready ? e.sizeBytes : 0;
        _downloadedBytesByEntryId[e.id] = len;
        totalOnDisk += len;
        if (!ready) allValid = false;
        continue;
      }
      final f = await getEntryFile(e);
      int len = 0;
      try {
        if (await f.exists()) {
          len = await f.length();
        }
      } catch (_) {}
      _downloadedBytesByEntryId[e.id] = len;
      totalOnDisk += len;
      if (len < (e.sizeBytes * 0.95)) {
        allValid = false;
      }
    }
    _lastTotalDownloadedBytes = totalOnDisk;

    // If all models already exist on disk from previous install, mark ready instantly with 0 downloads needed
    if (allValid) {
      _isDownloadedCache = true;
      final completed = const ModelDownloadProgress(
        downloadedBytes: estimatedTotalBytes,
        totalBytes: estimatedTotalBytes,
        currentFileDownloadedBytes: estimatedTotalBytes,
        currentFileTotalBytes: estimatedTotalBytes,
        progress: 1.0,
        currentStep: 5,
        totalSteps: 5,
        currentPhase: 'All models verified on device',
        isCompleted: true,
      );
      _lastProgress = completed;
      return completed;
    }

    // Check if any task is actively running with fast timeout so it never hangs
    try {
      for (final e in suiteEntries) {
        if (e.isBundled) continue;
        final taskId = 'repp-ai-${e.id}';
        final rec = await FileDownloader()
            .database
            .recordForId(taskId)
            .timeout(const Duration(milliseconds: 300), onTimeout: () => null);
        if (rec != null &&
            (rec.status == TaskStatus.running || rec.status == TaskStatus.enqueued)) {
          _isDownloading = true;
          _statusController.add(true);
          _currentEntry = e;

          final partial = ModelDownloadProgress(
            downloadedBytes: totalOnDisk,
            totalBytes: estimatedTotalBytes,
            currentFileDownloadedBytes: _downloadedBytesByEntryId[e.id] ?? 0,
            currentFileTotalBytes: e.sizeBytes,
            progress: (totalOnDisk / estimatedTotalBytes).clamp(0.0, 1.0),
            currentPhase: '${e.name} (${e.stepIndex}/${suiteEntries.length})',
            currentModelName: e.name,
            currentModelTag: e.tag,
            currentStep: e.stepIndex,
            totalSteps: suiteEntries.length,
            isDownloading: true,
          );
          _emitProgress(partial, immediate: true);
          return partial;
        }
      }
    } catch (_) {}

    if (totalOnDisk > 0) {
      final prog = (totalOnDisk / estimatedTotalBytes).clamp(0.0, 1.0);
      LiteRtModelEntry current = suiteEntries.first;
      for (final e in suiteEntries) {
        final fLen = _downloadedBytesByEntryId[e.id] ?? 0;
        if (fLen < (e.sizeBytes * 0.95)) {
          current = e;
          break;
        }
      }

      final partial = ModelDownloadProgress(
        downloadedBytes: totalOnDisk,
        totalBytes: estimatedTotalBytes,
        currentFileDownloadedBytes: _downloadedBytesByEntryId[current.id] ?? 0,
        currentFileTotalBytes: current.sizeBytes,
        progress: prog,
        currentPhase: '${current.name} (${current.stepIndex}/${suiteEntries.length})',
        currentModelName: current.name,
        currentModelTag: current.tag,
        currentStep: current.stepIndex,
        totalSteps: suiteEntries.length,
        isDownloading: false,
      );
      _emitProgress(partial, immediate: true);
      return partial;
    }

    final zero = ModelDownloadProgress(
      downloadedBytes: 0,
      totalBytes: estimatedTotalBytes,
      currentFileDownloadedBytes: 0,
      currentFileTotalBytes: suiteEntries.first.sizeBytes,
      progress: 0.0,
      currentPhase: '${suiteEntries.first.name} (1/${suiteEntries.length})',
      currentModelName: suiteEntries.first.name,
      currentModelTag: suiteEntries.first.tag,
      currentStep: 1,
      totalSteps: suiteEntries.length,
      isDownloading: false,
    );
    _emitProgress(zero, immediate: true);
    return zero;
  }

  /// Rescan storage for models without deleting anything
  Future<ModelDownloadProgress> rescanDisk() async {
    _cachedModelDir = null;
    _isDownloadedCache = null;
    _lastProgress = null;
    final prog = await getInitialProgress();
    _emitProgress(prog, immediate: true);
    return prog;
  }

  /// Start downloading the LiteRT suite sequentially
  Future<void> startDownload({bool requireWifi = false}) async {
    if (_isDownloading) return;

    if (Platform.isAndroid) {
      await _ensureAndroidPermissions();
    }

    if (await isFullSuiteDownloaded()) {
      _isDownloadedCache = true;
      _emitProgress(const ModelDownloadProgress(
        downloadedBytes: estimatedTotalBytes,
        totalBytes: estimatedTotalBytes,
        progress: 1.0,
        currentStep: 5,
        totalSteps: 5,
        currentPhase: 'All models ready',
        isCompleted: true,
      ), immediate: true);
      return;
    }

    await init();
    _isDownloading = true;
    _statusController.add(true);

    // Immediate UI feedback
    _emitProgress(ModelDownloadProgress(
      downloadedBytes: _lastTotalDownloadedBytes,
      totalBytes: estimatedTotalBytes,
      currentFileDownloadedBytes: 0,
      currentFileTotalBytes: suiteEntries.first.sizeBytes,
      progress: (_lastTotalDownloadedBytes / estimatedTotalBytes).clamp(0.0, 1.0),
      currentPhase: 'Connecting to Hugging Face...',
      currentModelName: suiteEntries.first.name,
      currentModelTag: suiteEntries.first.tag,
      currentStep: 1,
      totalSteps: suiteEntries.length,
      isDownloading: true,
    ), immediate: true);

    await _advanceQueue(requireWifi: requireWifi);
  }

  Future<void> _advanceQueue({bool requireWifi = false}) async {
    for (final entry in suiteEntries) {
      if (entry.isBundled) {
        _downloadedBytesByEntryId[entry.id] = entry.sizeBytes;
        continue;
      }
      if (entry.isEngineManaged) {
        if (await isEngineEntryReady(entry)) {
          _downloadedBytesByEntryId[entry.id] = entry.sizeBytes;
          continue;
        }
        await _installEngineEntry(entry);
        return;
      }
      if (entry.id == 's1') {
        if (await S1CleanupService().isReady()) {
          _downloadedBytesByEntryId[entry.id] = entry.sizeBytes;
          continue;
        }
        await _installS1Entry(entry);
        return;
      }
      await _migrateEntryFiles(entry);
      final file = await getEntryFile(entry);
      final exists = await file.exists();
      final len = exists ? await file.length() : 0;
      if (!exists || len < (entry.sizeBytes * 0.95)) {
        await _enqueueEntry(entry, requireWifi: requireWifi);
        return;
      } else {
        _downloadedBytesByEntryId[entry.id] = entry.sizeBytes;
      }
    }

    // All entries complete!
    _isDownloading = false;
    _isDownloadedCache = true;
    _statusController.add(false);
    _emitProgress(
      const ModelDownloadProgress(
        downloadedBytes: estimatedTotalBytes,
        totalBytes: estimatedTotalBytes,
        currentFileDownloadedBytes: estimatedTotalBytes,
        currentFileTotalBytes: estimatedTotalBytes,
        progress: 1.0,
        currentStep: 5,
        totalSteps: 5,
        currentPhase: 'All models ready',
        isCompleted: true,
      ),
      immediate: true,
    );
  }

  /// Installs an engine-managed entry (STT/TTS) via FlutterGemma builders
  /// into engine storage, mapping installer progress into suite progress.
  /// Installs are idempotent — already-installed bundles are skipped.
  Future<void> _installEngineEntry(LiteRtModelEntry entry) async {
    _currentEntry = entry;

    void emitOverall(int entryBytes) {
      _downloadedBytesByEntryId[entry.id] = entryBytes;
      int total = 0;
      for (final e in suiteEntries) {
        total += _downloadedBytesByEntryId[e.id] ?? 0;
      }
      total = total.clamp(0, estimatedTotalBytes);
      _lastTotalDownloadedBytes = total;
      _emitProgress(ModelDownloadProgress(
        downloadedBytes: total,
        totalBytes: estimatedTotalBytes,
        currentFileDownloadedBytes: entryBytes,
        currentFileTotalBytes: entry.sizeBytes,
        progress: (total / estimatedTotalBytes).clamp(0.0, 1.0),
        currentPhase: 'Installing ${entry.name} (${entry.stepIndex}/${suiteEntries.length})...',
        currentModelName: entry.name,
        currentModelTag: entry.tag,
        currentStep: entry.stepIndex,
        totalSteps: suiteEntries.length,
        isDownloading: true,
      ), immediate: true);
    }

    try {
      if (entry.id == 'stt') {
        // STT via OUR http downloader into modelDir (proven path), then
        // registered with the engine from local files. This avoids the
        // engine installer's network layer, which verified 0-byte files
        // on-device (shared background_downloader state).
        final dir = await modelDir;
        final sttDir = Directory('${dir.path}/moonshine-tiny');
        if (!await sttDir.exists()) await sttDir.create(recursive: true);
        // Migrate legacy flat files into the subfolder (best-effort: on
        // devices without all-files access the move fails and callers
        // below fall back to the legacy flat paths).
        for (final legacyName in [
          'moonshine_tiny_5s_f32.tflite',
          'moonshine_tiny_tokenizer.json',
        ]) {
          final legacy = File('${dir.path}/$legacyName');
          final fresh = File('${sttDir.path}/$legacyName');
          try {
            if (await legacy.exists() && !await fresh.exists()) {
              await legacy.rename(fresh.path);
            }
          } catch (_) {}
        }
        Future<File> sttLocal(String name, int minBytes) async {
          final fresh = File('${sttDir.path}/$name');
          try {
            if (await fresh.exists() && await fresh.length() >= minBytes) {
              return fresh;
            }
            final legacy = File('${dir.path}/$name');
            if (await legacy.exists() && await legacy.length() >= minBytes) {
              return legacy;
            }
          } catch (_) {}
          return fresh;
        }

        final modelFile = await sttLocal(
          'moonshine_tiny_5s_f32.tflite',
          (109373140 * 0.95).round(),
        );
        final tokFile = await sttLocal('moonshine_tiny_tokenizer.json', 1024);
        const modelBytes = 109373140;
        await _fetchUrl(
          WhisperAsrService.modelUrl,
          modelFile,
          modelBytes,
          (done, total) => emitOverall(
            ((done / total) * modelBytes).round().clamp(0, entry.sizeBytes),
          ),
        );
        await _fetchUrl(
          WhisperAsrService.tokenizerUrl,
          tokFile,
          0, // tokenizer size varies by revision — accept non-empty JSON
          (done, total) {
            final mapped = modelBytes + done;
            emitOverall(mapped > entry.sizeBytes ? entry.sizeBytes : mapped);
          },
        );
        final tokText = await tokFile.readAsString();
        if (!tokText.contains('"vocab"') && !tokText.contains('tokens')) {
          // Stale/corrupt tokenizer (e.g. partial pre-fix download):
          // delete once and pull fresh, then re-validate.
          try {
            await tokFile.delete();
          } catch (_) {}
          await _fetchUrl(
            WhisperAsrService.tokenizerUrl,
            tokFile,
            0,
          (done, total) => emitOverall(
            done > entry.sizeBytes ? entry.sizeBytes : done,
          ),
          );
          final retryText = await tokFile.readAsString();
          if (!retryText.contains('"vocab"') &&
              !retryText.contains('tokens')) {
            throw StateError('Moonshine tokenizer failed validation');
          }
        }
        await FlutterGemma.installStt()
            .modelFromFile(modelFile.path)
            .tokenizerFromFile(tokFile.path)
            .ofType(SttModelType.moonshine)
            .install();
      } else if (entry.id == 'tts') {
        await FlutterGemma.installTts()
            .fromNetwork(GemmaSpeechTtsService.bundleBaseUrl)
            .ofType(TtsModelType.qwen3)
            .withProgress((p) =>
                emitOverall(((p / 100) * entry.sizeBytes).round()))
            .install();
      }
      _downloadedBytesByEntryId[entry.id] = entry.sizeBytes;
      await _advanceQueue();
    } catch (e) {
      debugPrint('Error installing ${entry.name}: $e');
      _isDownloading = false;
      _statusController.add(false);
      _emitProgress(ModelDownloadProgress(
        downloadedBytes: _lastTotalDownloadedBytes,
        totalBytes: estimatedTotalBytes,
        error: e.toString(),
        isDownloading: false,
      ), immediate: true);
    }
  }

  /// Installs the S1 Q4 bundle via S1CleanupService (multi-file, SHA256
  /// per file), mapping progress into suite progress. Idempotent.
  Future<void> _installS1Entry(LiteRtModelEntry entry) async {
    _currentEntry = entry;
    try {
      final ok = await S1CleanupService().ensureInstalled(
        onProgress: (done, total) {
          _downloadedBytesByEntryId[entry.id] =
              ((done / total) * entry.sizeBytes).round();
          int grand = 0;
          for (final e in suiteEntries) {
            grand += _downloadedBytesByEntryId[e.id] ?? 0;
          }
          grand = grand.clamp(0, estimatedTotalBytes);
          _lastTotalDownloadedBytes = grand;
          _emitProgress(ModelDownloadProgress(
            downloadedBytes: grand,
            totalBytes: estimatedTotalBytes,
            currentFileDownloadedBytes:
                _downloadedBytesByEntryId[entry.id] ?? 0,
            currentFileTotalBytes: entry.sizeBytes,
            progress: (grand / estimatedTotalBytes).clamp(0.0, 1.0),
            currentPhase:
                'Installing ${entry.name} (${entry.stepIndex}/${suiteEntries.length})...',
            currentModelName: entry.name,
            currentModelTag: entry.tag,
            currentStep: entry.stepIndex,
            totalSteps: suiteEntries.length,
            isDownloading: true,
          ), immediate: true);
        },
      );
      if (!ok) throw StateError(S1CleanupService().error ?? 'S1 install failed');
      _downloadedBytesByEntryId[entry.id] = entry.sizeBytes;
      await _advanceQueue();
    } catch (e) {
      debugPrint('Error installing ${entry.name}: $e');
      _isDownloading = false;
      _statusController.add(false);
      _emitProgress(ModelDownloadProgress(
        downloadedBytes: _lastTotalDownloadedBytes,
        totalBytes: estimatedTotalBytes,
        error: e.toString(),
        isDownloading: false,
      ), immediate: true);
    }
  }

  /// Plain-await http download with Range resume + size verify.
  /// [expectedBytes] <= 0 skips the size check (revision-varying files) but
  /// still resumes partial files; a complete local file is returned as-is.
  Future<void> _fetchUrl(
    String url,
    File file,
    int expectedBytes,
    void Function(int done, int total)? onProgress,
  ) async {
    var start = 0;
    if (await file.exists()) {
      start = await file.length();
      if (start > 0 && (expectedBytes <= 0 || start == expectedBytes)) {
        // Complete (or revision-varying) file already on disk.
        onProgress?.call(start, start);
        return;
      }
      if (expectedBytes > 0 && start > expectedBytes) {
        await file.delete();
        start = 0;
      }
    }
    final req = http.Request('GET', Uri.parse(url));
    if (start > 0) req.headers['Range'] = 'bytes=$start-';
    final client = http.Client();
    try {
      final resp = await client.send(req);
      if (resp.statusCode != 200 && resp.statusCode != 206) {
        throw HttpException('HTTP ${resp.statusCode} for $url');
      }
      final total = resp.contentLength != null && resp.contentLength! > 0
          ? (resp.statusCode == 206 ? start : 0) + resp.contentLength!
          : (expectedBytes > 0 ? expectedBytes : start + 1);
      final sink = file.openWrite(
        mode: start > 0 ? FileMode.append : FileMode.write,
      );
      var written = start;
      onProgress?.call(written, total);
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        written += chunk.length;
        onProgress?.call(written, total);
      }
      await sink.close();
      if (expectedBytes > 0) {
        final len = await file.length();
        if ((len - expectedBytes).abs() > (expectedBytes * 0.05).ceil()) {
          throw StateError('Size mismatch for $url: $len vs $expectedBytes');
        }
      } else if (await file.length() == 0) {
        throw StateError('Empty download for $url');
      }
    } finally {
      client.close();
    }
  }

  Future<void> _enqueueEntry(LiteRtModelEntry entry, {bool requireWifi = false}) async {
    try {
      _currentEntry = entry;
      final targetDir = await entryDir(entry);
      final taskId = 'repp-ai-${entry.id}';
      
      DownloadTask task = DownloadTask(
        taskId: taskId,
        url: entry.url,
        filename: entry.filename,
        directory: targetDir.path,
        baseDirectory: BaseDirectory.root,
        updates: Updates.statusAndProgress,
        requiresWiFi: requireWifi,
        retries: 5,
        allowPause: true,
        priority: 0,
        displayName: entry.name,
        headers: {
          'Known-Content-Length': '${entry.sizeBytes}',
        },
      );
      _currentTask = task;

      bool enqueued = false;
      try {
        final record = await FileDownloader().database.recordForId(taskId);
        if (record != null &&
            (record.status == TaskStatus.paused || record.status == TaskStatus.failed)) {
          final resumed = await FileDownloader().resume(task);
          if (resumed) enqueued = true;
        }
        if (!enqueued) {
          enqueued = await FileDownloader().enqueue(task);
        }
      } catch (e) {
        debugPrint('Direct enqueue notice: $e');
      }

      if (!enqueued) {
        debugPrint('BaseDirectory.root enqueue failed. Falling back to applicationDocuments...');
        final fallbackTask = DownloadTask(
          taskId: taskId,
          url: entry.url,
          filename: entry.filename,
          directory: 'models',
          baseDirectory: BaseDirectory.applicationDocuments,
          updates: Updates.statusAndProgress,
          requiresWiFi: requireWifi,
          retries: 5,
          allowPause: true,
          priority: 0,
          displayName: entry.name,
          headers: {
            'Known-Content-Length': '${entry.sizeBytes}',
          },
        );
        _currentTask = fallbackTask;
        enqueued = await FileDownloader().enqueue(fallbackTask);
        debugPrint('Fallback enqueue result: $enqueued');
      }

      _emitProgress(ModelDownloadProgress(
        downloadedBytes: _lastTotalDownloadedBytes,
        totalBytes: estimatedTotalBytes,
        currentFileDownloadedBytes: _downloadedBytesByEntryId[entry.id] ?? 0,
        currentFileTotalBytes: entry.sizeBytes,
        progress: (_lastTotalDownloadedBytes / estimatedTotalBytes).clamp(0.0, 1.0),
        currentPhase: 'Downloading ${entry.name} (${entry.stepIndex}/${suiteEntries.length})...',
        currentModelName: entry.name,
        currentModelTag: entry.tag,
        currentStep: entry.stepIndex,
        totalSteps: suiteEntries.length,
        isDownloading: true,
      ), immediate: true);
    } catch (e) {
      debugPrint('Error enqueuing ${entry.name}: $e');
      if (!_isDownloading) return;
      _isDownloading = false;
      _statusController.add(false);
      _emitProgress(ModelDownloadProgress(
        downloadedBytes: _lastTotalDownloadedBytes,
        totalBytes: estimatedTotalBytes,
        error: e.toString(),
        isDownloading: false,
      ), immediate: true);
    }
  }

  Future<void> _syncCompletedFile(LiteRtModelEntry entry) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final localFile = File('${docs.path}/models/${entry.filename}');
      final sharedFile = await getEntryFile(entry);
      if (await localFile.exists() && localFile.path != sharedFile.path) {
        if (!await sharedFile.parent.exists()) {
          await sharedFile.parent.create(recursive: true);
        }
        await localFile.copy(sharedFile.path);
        debugPrint('Synced ${entry.filename} to shared models directory');
      }
    } catch (e) {
      debugPrint('Sync completed file notice: $e');
    }
  }

  /// Pause current background download
  Future<void> pauseDownload() async {
    _isDownloading = false;
    _statusController.add(false);

    try {
      if (_currentTask != null) {
        await FileDownloader().pause(_currentTask!);
      } else {
        for (final e in suiteEntries) {
          final t = await FileDownloader().taskForId('repp-ai-${e.id}');
          if (t is DownloadTask) {
            await FileDownloader().pause(t);
          }
        }
      }
    } catch (_) {}

    _emitProgress(ModelDownloadProgress(
      downloadedBytes: _lastTotalDownloadedBytes,
      totalBytes: estimatedTotalBytes,
      currentFileDownloadedBytes: _currentEntry != null ? (_downloadedBytesByEntryId[_currentEntry!.id] ?? 0) : 0,
      currentFileTotalBytes: _currentEntry?.sizeBytes ?? estimatedTotalBytes,
      progress: (_lastTotalDownloadedBytes / estimatedTotalBytes).clamp(0.0, 1.0),
      currentPhase: 'Paused',
      currentModelName: _currentEntry?.name,
      currentModelTag: _currentEntry?.tag,
      currentStep: _currentEntry?.stepIndex ?? 1,
      totalSteps: suiteEntries.length,
      isDownloading: false,
    ), immediate: true);
  }

  /// Cancel any running tasks and restart download without deleting files
  Future<void> restartDownload() async {
    _isDownloading = false;
    _isDownloadedCache = false;
    _statusController.add(false);

    for (final e in suiteEntries) {
      try {
        await FileDownloader().cancelTaskWithId('repp-ai-${e.id}');
      } catch (_) {}
    }

    _downloadedBytesByEntryId.clear();
    _lastProgress = null;
    _lastTotalDownloadedBytes = 0;

    await startDownload();
  }
}

/// Genkit on-device AI service with offline coach intelligence fallback
class GenkitGemmaService implements LocalLlmService {
  static final GenkitGemmaService _instance = GenkitGemmaService._internal();
  factory GenkitGemmaService() => _instance;
  GenkitGemmaService._internal();

  final ModelDownloadService _dl = ModelDownloadService();
  Genkit? _ai;
  bool _isInitializing = false;
  bool _isInstalled = false;
  String? _installedModelPath;
  String? _initError;
  Timer? _idleTimer;
  bool _isWarmedUp = false;

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 10), () {
      debugPrint('[GenkitGemmaService] 10 minutes idle elapsed without chat activity. Unloading models to free memory...');
      unloadAllModels();
    });
  }

  /// Cleans out internal channel tokens emitted by LiteRT-LM reasoning models
  static String sanitizeChannelTokens(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll(RegExp(r'<\|?channel\|?>[<|channel>]*thought', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\|?channel\|?>[<|channel>]*call', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\|?channel\|?>[<|channel>]*response', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\|?channel\|?>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<channel\|?>', caseSensitive: false), '');
  }

  @override
  Future<void> warmup() async {
    _resetIdleTimer();
    if (_isWarmedUp && _ai != null) return;

    final ready = await isModelReady;
    if (!ready) return;

    if (_ai == null) {
      await initialize();
    }

    if (_ai != null && !_isWarmedUp) {
      try {
        debugPrint('[GenkitGemmaService] Warming up Gemma engine session in background...');
        final warmupStream = _ai!.generateStream(
          model: flutterGemma.model('repp-ai-engine'),
          prompt: 'hi',
          config: FlutterGemmaModelOptions(
            maxTokens: 1,
            temperature: 0.1,
            preferredBackend: 'gpu',
          ),
        );
        await for (final _ in warmupStream) {
          break;
        }
        _isWarmedUp = true;
        debugPrint('[GenkitGemmaService] Gemma engine pre-warmed successfully.');
      } catch (e) {
        debugPrint('[GenkitGemmaService] Warmup notice: $e');
      }
    }
  }

  @override
  void unloadAllModels() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _ai = null;
    _isInstalled = false;
    _installedModelPath = null;
    _isWarmedUp = false;
    debugPrint('[GenkitGemmaService] All on-device models successfully unloaded from memory.');
  }

  @override
  Future<void> initialize() async {
    if (_ai != null || _isInitializing) return;

    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }

    final ready = await _dl.isModelDownloaded();
    if (!ready) {
      debugPrint('GenkitGemmaService: LiteRT model not downloaded yet');
      return;
    }
    _isInitializing = true;
    _initError = null;
    try {
      final vlm = await _dl.coreVlmFile;
      debugPrint('GenkitGemmaService: Initializing LiteRT engine with ${vlm.path}...');

      if (!_isInstalled || _installedModelPath != vlm.path) {
        try {
          await FlutterGemma.installModel(
            modelType: ModelType.general,
            fileType: ModelFileType.litertlm,
          ).fromFile(vlm.path).install();
          _isInstalled = true;
          _installedModelPath = vlm.path;
        } catch (e) {
          debugPrint('FlutterGemma installModel notice: $e');
        }
      }

      _ai = Genkit(
        plugins: [
          GenkitFlutterGemmaPlugin(
            models: [
              FlutterGemmaModelConfig(
                name: 'repp-ai-engine',
                modelType: ModelType.general,
                fileType: ModelFileType.litertlm,
              ),
            ],
          ),
        ],
      );
      _resetIdleTimer();
      debugPrint('GenkitGemmaService: ready');
    } catch (e, st) {
      _initError = '$e';
      debugPrint('GenkitGemmaService init error: $e\n$st');
    } finally {
      _isInitializing = false;
    }
  }

  @override
  Future<bool> get isModelReady async {
    return await _dl.isModelDownloaded();
  }

  @override
  Stream<String> generate(
    String prompt, {
    String? systemPrompt,
    List<Uint8List>? imageBytes,
    Uint8List? audioBytes,
    List<Uint8List>? videoFrames,
    String? poseContext,
    bool isThinking = false,
  }) async* {
    _resetIdleTimer();

    if (!await isModelReady) {
      yield '⚠️ AI model is not downloaded yet. Please download it from the banner at the top of AI Coach tab.';
      return;
    }

    if (_ai == null) {
      await initialize();
    }

    if (_ai == null) {
      yield '⚠️ On-Device Inference Error: ${_initError ?? "Engine not initialized. Please ensure the model file is accessible."}';
      return;
    }

    try {
      final vlm = await _dl.coreVlmFile;
      final isGemma = vlm.path.toLowerCase().contains('gemma');

      final fullPrompt = poseContext != null && poseContext.isNotEmpty
          ? '[PoseContext: $poseContext]\n$prompt'
          : prompt;

      final stream = _ai!.generateStream(
        model: flutterGemma.model('repp-ai-engine'),
        prompt: fullPrompt,
        config: FlutterGemmaModelOptions(
          maxTokens: 1536,
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          preferredBackend: 'gpu',
          enableSpeculativeDecoding: isGemma,
          supportImage: (imageBytes != null && imageBytes.isNotEmpty) ||
              (videoFrames != null && videoFrames.isNotEmpty),
          supportAudio: audioBytes != null && audioBytes.isNotEmpty,
          isThinking: isThinking,
          systemInstruction: systemPrompt,
        ),
      );

      bool inThoughtChannel = false;
      bool receivedAny = false;

      await for (final chunk in stream) {
        bool handled = false;
        for (final part in chunk.content) {
          if (part is ReasoningPart && part.reasoning.isNotEmpty) {
            final cleaned = sanitizeChannelTokens(part.reasoning);
            if (cleaned.isNotEmpty) {
              if (!inThoughtChannel) {
                yield '<thought>';
                inThoughtChannel = true;
              }
              yield cleaned;
              handled = true;
              receivedAny = true;
            }
          } else if (part is TextPart && part.text.isNotEmpty) {
            if (inThoughtChannel) {
              yield '</thought>\n\n';
              inThoughtChannel = false;
            }
            final cleaned = sanitizeChannelTokens(part.text);
            if (cleaned.isNotEmpty) {
              yield cleaned;
              handled = true;
              receivedAny = true;
            }
          }
        }

        if (!handled && chunk.text.isNotEmpty) {
          final raw = chunk.text;
          if (raw.contains('<|channel|>thought') ||
              raw.contains('<channel|><|channel>thought') ||
              raw.contains('<channel>thought')) {
            if (!inThoughtChannel) {
              yield '<thought>';
              inThoughtChannel = true;
            }
          }

          if (raw.contains('<|channel|>response') ||
              raw.contains('<channel|>response') ||
              raw.contains('<|channel|>call')) {
            if (inThoughtChannel) {
              yield '</thought>\n\n';
              inThoughtChannel = false;
            }
          }

          final cleaned = sanitizeChannelTokens(raw);
          if (cleaned.isNotEmpty) {
            yield cleaned;
            receivedAny = true;
          }
        }
      }

      if (inThoughtChannel) {
        yield '</thought>\n\n';
      }

      if (!receivedAny) {
        yield '⚠️ On-device model produced no output for this prompt. Please retry.';
      }
    } catch (e, st) {
      debugPrint('Genkit live inference error: $e\n$st');
      yield '⚠️ Live On-Device Inference Error: $e';
    }
  }

  @override
  Future<String> generateOneShot(
    String prompt, {
    String? systemPrompt,
    List<Uint8List>? imageBytes,
    Uint8List? audioBytes,
    List<Uint8List>? videoFrames,
    String? poseContext,
    bool isThinking = false,
  }) async {
    _resetIdleTimer();
    final buf = StringBuffer();
    await for (final c in generate(
      prompt,
      systemPrompt: systemPrompt,
      imageBytes: imageBytes,
      audioBytes: audioBytes,
      videoFrames: videoFrames,
      poseContext: poseContext,
      isThinking: isThinking,
    )) {
      buf.write(c);
    }
    return buf.toString();
  }

  @override
  void dispose() {
    // Keep model resident in background memory; 10-minute idle timer handles cleanup
  }
}

/// Factory — always returns the active GenkitGemmaService.
class LlmServiceFactory {
  static Future<LocalLlmService> create() async {
    final s = GenkitGemmaService();
    await s.initialize();
    return s;
  }
}
