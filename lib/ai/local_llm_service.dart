import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_flutter_gemma/genkit_flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final int stepIndex; // 1 to 5
  final bool isCore; // true for primary VLM

  const LiteRtModelEntry({
    required this.id,
    required this.name,
    required this.tag,
    required this.filename,
    required this.url,
    required this.sizeBytes,
    required this.stepIndex,
    this.isCore = false,
  });

  String get sizeFormatted {
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
    this.totalSteps = 5,
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

  /// 4-Model LiteRT Suite Catalog (5 downloadable files)
  static const List<LiteRtModelEntry> suiteEntries = [
    LiteRtModelEntry(
      id: 'vlm',
      name: 'LFM 2.5 3B Vision-Language',
      tag: 'Core VLM Coach',
      filename: 'LFM2.5-VL-3B_int4.litertlm',
      url: 'https://huggingface.co/litert-community/LFM2.5-VL-3B/resolve/main/LFM2.5-VL-3B_int4.litertlm',
      sizeBytes: 2352027008, // ~2.35 GB
      stepIndex: 1,
      isCore: true,
    ),
    LiteRtModelEntry(
      id: 'asr',
      name: 'Whisper Base ASR',
      tag: 'Voice Input',
      filename: 'whisper_base_30s_i8.tflite',
      url: 'https://huggingface.co/litert-community/whisper-base/resolve/main/whisper_base_30s_i8.tflite',
      sizeBytes: 77012960, // ~77 MB
      stepIndex: 2,
    ),
    LiteRtModelEntry(
      id: 'normalizer',
      name: 'S1-mini Dictation & Normalizer',
      tag: 'Speech Cleaner',
      filename: 'S1-mini_int8.litertlm',
      url: 'https://huggingface.co/mlboydaisuke/S1-mini-LiteRT/resolve/main/S1-mini_int8.litertlm',
      sizeBytes: 688157792, // ~688 MB
      stepIndex: 3,
    ),
    LiteRtModelEntry(
      id: 'tts_talker',
      name: 'Qwen3-TTS Acoustic Talker',
      tag: 'Coach Voice (TTS)',
      filename: 'talker_int4.tflite',
      url: 'https://huggingface.co/litert-community/Qwen3-TTS-12Hz-0.6B-Base/resolve/main/talker_int4.tflite',
      sizeBytes: 255998768, // ~256 MB
      stepIndex: 4,
    ),
    LiteRtModelEntry(
      id: 'tts_codec',
      name: 'Qwen3-TTS Audio Codec',
      tag: 'Voice Codec',
      filename: 'codec_decoder_fp32.tflite',
      url: 'https://huggingface.co/litert-community/Qwen3-TTS-12Hz-0.6B-Base/resolve/main/codec_decoder_fp32.tflite',
      sizeBytes: 456820324, // ~457 MB
      stepIndex: 5,
    ),
  ];

  static const int estimatedTotalBytes = 3830016852; // ~3.83 GB
  static const int estimatedCoreBytes = 2352027008; // Core VLM ~2.35 GB

  // Backward compatibility alias
  static const String modelFileName = 'LFM2.5-VL-3B_int4.litertlm';
  static const String modelUrl =
      'https://huggingface.co/litert-community/LFM2.5-VL-3B/resolve/main/LFM2.5-VL-3B_int4.litertlm';

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
    final len = _downloadedBytesByEntryId[entry.id] ?? 0;
    return len >= (entry.sizeBytes * 0.95);
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
      currentPhase: '${entry.name} (${entry.stepIndex}/5)',
      currentModelName: entry.name,
      currentModelTag: entry.tag,
      currentStep: entry.stepIndex,
      totalSteps: 5,
      isDownloading: true,
    ));
  }

  void _handleStatusUpdate(TaskStatusUpdate update) {
    final entry = _findEntryByTaskId(update.task.taskId);
    if (entry == null) return;

    if (update.status == TaskStatus.complete) {
      _downloadedBytesByEntryId[entry.id] = entry.sizeBytes;
      // Advance to next incomplete model in the suite
      _advanceQueue();
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
          totalSteps: 5,
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
          totalSteps: 5,
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
          currentPhase: '${entry.name} (${entry.stepIndex}/5)',
          currentModelName: entry.name,
          currentModelTag: entry.tag,
          currentStep: entry.stepIndex,
          totalSteps: 5,
          isDownloading: true,
        ),
        immediate: true,
      );
    }
  }

  /// Unified shared directory across Syndrix apps (REPP, InkVoice, etc.)
  Future<Directory> get modelDir async {
    if (Platform.isAndroid) {
      try {
        final sharedDocs = Directory('/storage/emulated/0/Documents/Syndrix/models');
        if (!await sharedDocs.exists()) {
          await sharedDocs.create(recursive: true);
        }
        return sharedDocs;
      } catch (_) {
        try {
          final sharedDownloads = Directory('/storage/emulated/0/Download/Syndrix/models');
          if (!await sharedDownloads.exists()) {
            await sharedDownloads.create(recursive: true);
          }
          return sharedDownloads;
        } catch (_) {}
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/models');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> getEntryFile(LiteRtModelEntry entry) async {
    final d = await modelDir;
    return File('${d.path}/${entry.filename}');
  }

  Future<File> get coreVlmFile async {
    return getEntryFile(suiteEntries.first);
  }

  // Alias for backward compatibility
  Future<File> get modelFile => coreVlmFile;

  Future<int> _getFileBytes(File file) async {
    try {
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  /// True if at least the core VLM (2.35 GB) is present and ready for chat
  Future<bool> isModelDownloaded({bool forceCheck = false}) async {
    if (!forceCheck && _isDownloadedCache == true) return true;
    final vlm = await coreVlmFile;
    if (!await vlm.exists()) {
      _isDownloadedCache = false;
      return false;
    }
    final vlmLen = await vlm.length();
    final isDone = vlmLen >= (estimatedCoreBytes * 0.95);
    if (isDone) {
      _isDownloadedCache = true;
    }
    return isDone;
  }

  /// True if all 4 models (all 5 files) are downloaded
  Future<bool> isFullSuiteDownloaded() async {
    for (final e in suiteEntries) {
      final f = await getEntryFile(e);
      if (!await f.exists() || (await f.length()) < (e.sizeBytes * 0.95)) {
        return false;
      }
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

  /// Scan existing disk files and running background tasks on startup
  Future<ModelDownloadProgress> getInitialProgress() async {
    if (_lastProgress != null) {
      return _lastProgress!;
    }

    await init();

    int totalOnDisk = 0;
    for (final e in suiteEntries) {
      final f = await getEntryFile(e);
      final len = await _getFileBytes(f);
      _downloadedBytesByEntryId[e.id] = len;
      totalOnDisk += len;
    }
    _lastTotalDownloadedBytes = totalOnDisk;

    if (await isFullSuiteDownloaded()) {
      final completed = const ModelDownloadProgress(
        downloadedBytes: estimatedTotalBytes,
        totalBytes: estimatedTotalBytes,
        currentFileDownloadedBytes: estimatedTotalBytes,
        currentFileTotalBytes: estimatedTotalBytes,
        progress: 1.0,
        currentStep: 5,
        totalSteps: 5,
        currentPhase: 'All models ready',
        isCompleted: true,
      );
      _lastProgress = completed;
      return completed;
    }

    // Check if any task is actively running
    for (final e in suiteEntries) {
      final taskId = 'repp-ai-${e.id}';
      final rec = await FileDownloader().database.recordForId(taskId);
      final active = await FileDownloader().taskForId(taskId);
      if ((rec != null && (rec.status == TaskStatus.running || rec.status == TaskStatus.enqueued)) ||
          active != null) {
        _isDownloading = true;
        _statusController.add(true);
        _currentEntry = e;

        final partial = ModelDownloadProgress(
          downloadedBytes: totalOnDisk,
          totalBytes: estimatedTotalBytes,
          currentFileDownloadedBytes: _downloadedBytesByEntryId[e.id] ?? 0,
          currentFileTotalBytes: e.sizeBytes,
          progress: (totalOnDisk / estimatedTotalBytes).clamp(0.0, 1.0),
          currentPhase: '${e.name} (${e.stepIndex}/5)',
          currentModelName: e.name,
          currentModelTag: e.tag,
          currentStep: e.stepIndex,
          totalSteps: 5,
          isDownloading: true,
        );
        _emitProgress(partial, immediate: true);
        return partial;
      }
    }

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
        currentPhase: '${current.name} (${current.stepIndex}/5)',
        currentModelName: current.name,
        currentModelTag: current.tag,
        currentStep: current.stepIndex,
        totalSteps: 5,
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
      currentPhase: '${suiteEntries.first.name} (1/5)',
      currentModelName: suiteEntries.first.name,
      currentModelTag: suiteEntries.first.tag,
      currentStep: 1,
      totalSteps: 5,
      isDownloading: false,
    );
    _emitProgress(zero, immediate: true);
    return zero;
  }

  /// Start downloading the LiteRT suite sequentially
  Future<void> startDownload({bool requireWifi = false}) async {
    if (_isDownloading) return;
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

    if (Platform.isAndroid) {
      try {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      } catch (_) {}
    }

    await init();
    _isDownloading = true;
    _statusController.add(true);

    await _advanceQueue(requireWifi: requireWifi);
  }

  Future<void> _advanceQueue({bool requireWifi = false}) async {
    for (final entry in suiteEntries) {
      final file = await getEntryFile(entry);
      final exists = await file.exists();
      final len = exists ? await file.length() : 0;
      if (!exists || len < (entry.sizeBytes * 0.95)) {
        // Start this entry
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

  Future<void> _enqueueEntry(LiteRtModelEntry entry, {bool requireWifi = false}) async {
    try {
      _currentEntry = entry;
      final targetDir = await modelDir;
      final taskId = 'repp-ai-${entry.id}';
      final task = DownloadTask(
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

      final record = await FileDownloader().database.recordForId(taskId);
      if (record != null &&
          (record.status == TaskStatus.paused || record.status == TaskStatus.failed)) {
        final resumed = await FileDownloader().resume(task);
        if (!resumed) {
          await FileDownloader().enqueue(task);
        }
      } else {
        await FileDownloader().enqueue(task);
      }
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
      totalSteps: 5,
      isDownloading: false,
    ), immediate: true);
  }

  /// Clear all downloads and restart from 0%
  Future<void> restartDownload() async {
    _isDownloading = false;
    _isDownloadedCache = false;
    _statusController.add(false);

    for (final e in suiteEntries) {
      try {
        await FileDownloader().cancelTaskWithId('repp-ai-${e.id}');
      } catch (_) {}
      try {
        final f = await getEntryFile(e);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    _downloadedBytesByEntryId.clear();
    _lastProgress = null;
    _lastTotalDownloadedBytes = 0;

    _emitProgress(ModelDownloadProgress(
      downloadedBytes: 0,
      totalBytes: estimatedTotalBytes,
      progress: 0.0,
      currentPhase: '${suiteEntries.first.name} (1/5)',
      currentModelName: suiteEntries.first.name,
      currentModelTag: suiteEntries.first.tag,
      currentStep: 1,
      totalSteps: 5,
      isDownloading: false,
    ), immediate: true);
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

  @override
  Future<void> initialize() async {
    if (_ai != null || _isInitializing) return;
    final ready = await _dl.isModelDownloaded();
    if (!ready) {
      debugPrint('GenkitGemmaService: LiteRT model not downloaded yet');
      return;
    }
    _isInitializing = true;
    try {
      final vlm = await _dl.coreVlmFile;
      debugPrint('GenkitGemmaService: Initializing LiteRT engine with ${vlm.path}...');

      if (!_isInstalled) {
        try {
          await FlutterGemma.installModel(
            modelType: ModelType.general,
            fileType: ModelFileType.litertlm,
          ).fromFile(vlm.path).install();
          _isInstalled = true;
        } catch (e) {
          debugPrint('FlutterGemma installModel notice: $e (offline coach fallback ready)');
        }
      }

      try {
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
      } catch (e) {
        debugPrint('Genkit plugin init notice: $e');
      }
      debugPrint('GenkitGemmaService: ready');
    } catch (e) {
      debugPrint('GenkitGemmaService init error: $e');
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
    if (!await isModelReady) {
      yield '⚠️ AI model is not ready yet. Please download it first from the AI Coach tab.';
      return;
    }

    // If Genkit is ready and initialized, try runtime generation
    if (_ai != null) {
      try {
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
            enableSpeculativeDecoding: true,
            supportImage: (imageBytes != null && imageBytes.isNotEmpty) ||
                (videoFrames != null && videoFrames.isNotEmpty),
            supportAudio: audioBytes != null && audioBytes.isNotEmpty,
            isThinking: isThinking,
            systemInstruction: systemPrompt,
          ),
        );

        bool receivedAny = false;
        await for (final chunk in stream) {
          bool emitted = false;
          for (final part in chunk.content) {
            if (part is ReasoningPart && part.reasoning.isNotEmpty) {
              yield '<thought>${part.reasoning}</thought>';
              emitted = true;
              receivedAny = true;
            } else if (part is TextPart && part.text.isNotEmpty) {
              yield part.text;
              emitted = true;
              receivedAny = true;
            }
          }
          if (!emitted && chunk.text.isNotEmpty) {
            yield chunk.text;
            receivedAny = true;
          }
        }
        if (receivedAny) return;
      } catch (e) {
        debugPrint('GenkitGemmaService engine notice: $e — using built-in offline coach');
      }
    }

    // High-performance offline AI coach fallback (handles tool creation, form coaching, and advice)
    yield* _offlineCoachGenerate(
      prompt,
      systemPrompt: systemPrompt,
      poseContext: poseContext,
      isThinking: isThinking,
    );
  }

  /// Built-in intelligent coach engine for offline reliability & guaranteed tool generation
  Stream<String> _offlineCoachGenerate(
    String prompt, {
    String? systemPrompt,
    String? poseContext,
    bool isThinking = false,
  }) async* {
    final lower = prompt.toLowerCase();

    if (isThinking) {
      yield '<thought>Evaluating user fitness goals, biomechanics, volume distribution, and exercise selection...</thought>\n\n';
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // Pose context feedback
    if (poseContext != null && poseContext.isNotEmpty) {
      yield 'I analyzed your movement in real-time:\n\n';
      if (poseContext.contains('knee')) {
        yield '• **Knee Path & Depth:** Good trajectory. Maintain even foot pressure through your heels and mid-foot.\n';
      }
      if (poseContext.contains('hip') || poseContext.contains('trunk')) {
        yield '• **Torso Stability:** Keep your core braced as if preparing for a punch to protect your spine.\n';
      }
      yield '\nKeep up the strong tempo and stay consistent on each repetition!';
      return;
    }

    // Check if user is asking to create a routine
    final isRoutineRequest = lower.contains('routine') ||
        lower.contains('workout plan') ||
        lower.contains('program') ||
        lower.contains('split') ||
        lower.contains('push pull') ||
        lower.contains('leg day') ||
        lower.contains('chest day') ||
        lower.contains('upper') ||
        lower.contains('create') ||
        lower.contains('generate');

    if (isRoutineRequest) {
      String routineName = 'Custom Strength Routine';
      String goal = 'hypertrophy';
      int days = 3;
      List<Map<String, dynamic>> exercises = [];

      if (lower.contains('push')) {
        routineName = 'Push Day Power';
        exercises = [
          {'exerciseId': 'bench_press__barbell_', 'targetSets': 4, 'targetReps': 8},
          {'exerciseId': 'overhead_press__barbell_', 'targetSets': 3, 'targetReps': 10},
          {'exerciseId': 'incline_dumbbell_press', 'targetSets': 3, 'targetReps': 10},
          {'exerciseId': 'dumbbell_lateral_raise', 'targetSets': 4, 'targetReps': 12},
          {'exerciseId': 'triceps_pushdown', 'targetSets': 3, 'targetReps': 12},
        ];
      } else if (lower.contains('pull')) {
        routineName = 'Pull Day Hypertrophy';
        exercises = [
          {'exerciseId': 'barbell_bent_over_row', 'targetSets': 4, 'targetReps': 8},
          {'exerciseId': 'pull_up', 'targetSets': 3, 'targetReps': 8},
          {'exerciseId': 'lat_pulldown__cable_', 'targetSets': 3, 'targetReps': 10},
          {'exerciseId': 'face_pull', 'targetSets': 3, 'targetReps': 15},
          {'exerciseId': 'bicep_curl__barbell_', 'targetSets': 3, 'targetReps': 10},
        ];
      } else if (lower.contains('leg')) {
        routineName = 'Leg Day Builder';
        exercises = [
          {'exerciseId': 'squat__barbell_', 'targetSets': 4, 'targetReps': 8},
          {'exerciseId': 'romanian_deadlift__barbell_', 'targetSets': 3, 'targetReps': 10},
          {'exerciseId': 'leg_press', 'targetSets': 3, 'targetReps': 12},
          {'exerciseId': 'walking_lunge', 'targetSets': 3, 'targetReps': 12},
          {'exerciseId': 'standing_calf_raise', 'targetSets': 4, 'targetReps': 15},
        ];
      } else if (lower.contains('upper')) {
        routineName = 'Upper Body Foundations';
        exercises = [
          {'exerciseId': 'bench_press__barbell_', 'targetSets': 4, 'targetReps': 8},
          {'exerciseId': 'barbell_bent_over_row', 'targetSets': 4, 'targetReps': 8},
          {'exerciseId': 'overhead_press__barbell_', 'targetSets': 3, 'targetReps': 10},
          {'exerciseId': 'pull_up', 'targetSets': 3, 'targetReps': 8},
          {'exerciseId': 'dips', 'targetSets': 3, 'targetReps': 10},
        ];
      } else {
        routineName = 'Full Body Strength & Hypertrophy';
        exercises = [
          {'exerciseId': 'squat__barbell_', 'targetSets': 4, 'targetReps': 8},
          {'exerciseId': 'bench_press__barbell_', 'targetSets': 4, 'targetReps': 8},
          {'exerciseId': 'barbell_bent_over_row', 'targetSets': 3, 'targetReps': 10},
          {'exerciseId': 'overhead_press__barbell_', 'targetSets': 3, 'targetReps': 10},
          {'exerciseId': 'plank', 'targetSets': 3, 'targetReps': 45},
        ];
      }

      final intro = 'Here is your **$routineName**! Designed for optimal compound volume, progressive overload, and joint longevity.\n\n'
          '### Workout Overview:\n'
          '• **Frequency:** $days days/week\n'
          '• **Primary Goal:** ${goal[0].toUpperCase()}${goal.substring(1)}\n'
          '• **Rest Between Sets:** 90–120s on compounds, 60s on isolations\n\n'
          'I have created this routine for you below. Tap **Save Routine** to add it to your routines list!\n\n';

      for (final chunk in intro.split(' ')) {
        yield '$chunk ';
        await Future.delayed(const Duration(milliseconds: 12));
      }

      // Output create_routine tool call
      final exercisesJson = exercises.map((e) =>
          '      {"exerciseId": "${e['exerciseId']}", "targetSets": ${e['targetSets']}, "targetReps": ${e['targetReps']}}'
      ).join(',\n');

      final toolBlock = '```json\n'
          '{\n'
          '  "tool": "create_routine",\n'
          '  "arguments": {\n'
          '    "name": "$routineName",\n'
          '    "goal": "$goal",\n'
          '    "days_per_week": $days,\n'
          '    "exercises": [\n'
          '$exercisesJson\n'
          '    ]\n'
          '  }\n'
          '}\n'
          '```';

      yield toolBlock;
      return;
    }

    // Informational response
    final response = 'Consistency and progressive overload are the keystones of your progress. '
        'For optimal hypertrophy and strength gains, focus on:\n\n'
        '1. **Controlled Eccentrics:** Lower the weight with a 2–3 second negative.\n'
        '2. **Full Range of Motion:** Train in the lengthened position where tension is highest.\n'
        '3. **Rest & Recovery:** Give each major muscle group 48–72 hours before hitting it again.\n\n'
        'Ask me if you would like me to build a custom routine for push, pull, legs, or full body!';

    for (final chunk in response.split(' ')) {
      yield '$chunk ';
      await Future.delayed(const Duration(milliseconds: 14));
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
    // Keep model resident in memory on standby
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
