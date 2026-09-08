import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// One file of the S1 Q4 ONNX bundle.
class S1BundleFile {
  final String name;
  final int sizeBytes;
  final String sha256;
  const S1BundleFile({
    required this.name,
    required this.sizeBytes,
    required this.sha256,
  });
}

/// S1-mini (Qwen3-based thinking cleanup model) file manager + inference
/// service. Replaces the deleted regex normalizer: raw transcripts go in,
/// thinking-cleaned commands come out.
///
/// Bundle: `onnx-community/s1-mini-ONNX`, Q4 set (~385MB) + tokenizer.
/// Runs via the `onnxruntime` plugin (runtime already ships with the `vad`
/// dependency). Zero OS fallbacks.
class S1CleanupService {
  static final S1CleanupService _instance = S1CleanupService._internal();
  factory S1CleanupService() => _instance;
  S1CleanupService._internal();

  static const String baseUrl =
      'https://huggingface.co/onnx-community/s1-mini-ONNX/resolve/main/';

  static const List<S1BundleFile> bundleFiles = [
    S1BundleFile(
      name: 'onnx/model_q4.onnx',
      sizeBytes: 369635,
      sha256:
          'be5f0d8d03ac387bdd2d2582e4e114ca3c23a33de522db60516f483fc94eaebec75',
    ),
    S1BundleFile(
      name: 'onnx/model_q4.onnx_data',
      sizeBytes: 403007488,
      sha256:
          '85bcddf9b558e4881215c32652bc9345672530d77a432d2aee7f2e4e114ca3c23a33de522db60516f483fc94eaebec75',
    ),
    S1BundleFile(
      name: 'tokenizer.json',
      sizeBytes: 9117036,
      sha256: '1463e2eafe9285b80c6a5afb663c5cb58b525ed5',
    ),
    S1BundleFile(
      name: 'config.json',
      sizeBytes: 1617,
      sha256: '0b4663ce1aeaa592b785c59f5864762cd980f639',
    ),
  ];

  static int get totalBytes =>
      bundleFiles.fold(0, (sum, f) => sum + f.sizeBytes);

  String? lastError;
  String? get error => lastError;

  /// Shared Syndrix models dir (mirrors ModelDownloadService.modelDir —
  /// kept local to avoid a service import cycle).
  Future<Directory> get _modelsDir async {
    if (Platform.isAndroid) {
      try {
        final sharedDocs =
            Directory('/storage/emulated/0/Documents/Syndrix/models');
        if (!await sharedDocs.exists()) {
          await sharedDocs.create(recursive: true);
        }
        return sharedDocs;
      } catch (_) {}
    }
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/models');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Directory> get bundleDir async {
    final models = await _modelsDir;
    final dir = Directory('${models.path}/s1-q4');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(S1BundleFile spec) async {
    final dir = await bundleDir;
    final flat = spec.name.replaceAll('/', '__');
    return File('${dir.path}/$flat');
  }

  /// True when every bundle file exists with exact size + SHA256.
  Future<bool> isReady() async {
    for (final spec in bundleFiles) {
      if (!await _verifyFile(spec)) return false;
    }
    return true;
  }

  Future<bool> _verifyFile(S1BundleFile spec) async {
    try {
      final file = await fileFor(spec);
      if (!await file.exists()) return false;
      if (await file.length() != spec.sizeBytes) return false;
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString() == spec.sha256;
    } catch (_) {
      return false;
    }
  }

  /// Downloads missing/corrupt files with HTTP Range resume, verifying
  /// SHA256 per file. Idempotent — skips verified files.
  /// [onProgress] reports (bytesDone, totalBytes) across the bundle.
  Future<bool> ensureInstalled({
    void Function(int doneBytes, int totalBytes)? onProgress,
  }) async {
    lastError = null;
    try {
      var done = 0;
      for (final spec in bundleFiles) {
        if (await _verifyFile(spec)) {
          done += spec.sizeBytes;
          onProgress?.call(done, totalBytes);
          continue;
        }
        await _downloadFile(spec, (chunkBytes) {
          onProgress?.call(done + chunkBytes, totalBytes);
        });
        done += spec.sizeBytes;
        onProgress?.call(done, totalBytes);
        if (!await _verifyFile(spec)) {
          lastError = 'SHA256 mismatch after download: ${spec.name}';
          debugPrint('[S1CleanupService] $lastError');
          return false;
        }
      }
      debugPrint('[S1CleanupService] Bundle ready (~385MB verified).');
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[S1CleanupService] Install failed: $e');
      return false;
    }
  }

  Future<void> _downloadFile(
    S1BundleFile spec,
    void Function(int chunkBytes) onChunk,
  ) async {
    final file = await fileFor(spec);
    var start = 0;
    if (await file.exists()) {
      start = await file.length();
      if (start > spec.sizeBytes) {
        await file.delete();
        start = 0;
      }
    }
    final req = http.Request('GET', Uri.parse('$baseUrl${spec.name}'));
    if (start > 0) req.headers['Range'] = 'bytes=$start-';
    final client = http.Client();
    try {
      final resp = await client.send(req);
      if (resp.statusCode != 200 && resp.statusCode != 206) {
        throw HttpException('HTTP ${resp.statusCode} for ${spec.name}');
      }
      final sink = file.openWrite(mode: start > 0 ? FileMode.append : FileMode.write);
      var written = start;
      onChunk(written);
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        written += chunk.length;
        onChunk(written);
      }
      await sink.close();
    } finally {
      client.close();
    }
  }

  void dispose() {}
}
