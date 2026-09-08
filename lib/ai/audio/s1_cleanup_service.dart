import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 's1_ort_ffi.dart';
import 's1_tokenizer.dart';

/// One file of the S1 Q4 ONNX bundle. Empty [sha256] means HF publishes
/// no content hash (small non-LFS files) — then [mustContain] substring
/// plus exact size is the integrity check.
class S1BundleFile {
  final String name;
  final int sizeBytes;
  final String sha256;
  final String mustContain;
  const S1BundleFile({
    required this.name,
    required this.sizeBytes,
    this.sha256 = '',
    this.mustContain = '',
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
          'be5f0d8d03ac387bdd2d2582e4e114ca3c23a44b70bf03be609844542107745c',
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
      mustContain: '"vocab"',
    ),
    S1BundleFile(
      name: 'config.json',
      sizeBytes: 1617,
      mustContain: '"architectures"',
    ),
  ];

  static int get totalBytes =>
      bundleFiles.fold(0, (sum, f) => sum + f.sizeBytes);

  String? lastError;
  String? get error => lastError;

  OrtSession? _session;
  S1Tokenizer? _tokenizer;
  S1IoLayout? _layout;
  bool _sessionFailed = false;

  bool get isSessionReady => _session != null && _tokenizer != null;

  /// Cleanup prompt: thinking-off rewrite. S1 applies self-corrections
  /// ("scratch that"), drops fillers, outputs one clean command only.
  static const String systemPrompt =
      'Rewrite the gym voice command as one clean line. Apply any '
      'self-corrections (text after "scratch that", "I mean", "no wait" '
      'replaces what came before). Remove filler words. Output ONLY the '
      'clean command, no quotes, no commentary.';

  static const int _maxPromptTokens = 256;
  static const int _maxNewTokens = 48;

  // Qwen3-1.5B-ish S1 config (from bundle config.json): 28 layers,
  // 8 KV heads, head_dim 128. Past layout per tensor: [1, 8, seq, 128].
  static const int _kvHeads = 8;
  static const int _headDim = 128;

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
    final dir = Directory('${models.path}/s1-mini-q4');
    if (!await dir.exists()) {
      // Migrate the original s1-q4 folder (same files, new name).
      final legacy = Directory('${models.path}/s1-q4');
      try {
        if (await legacy.exists()) {
          await legacy.rename(dir.path);
          return dir;
        }
      } catch (_) {}
      await dir.create(recursive: true);
    }
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
      if (spec.sha256.isNotEmpty) {
        final digest = await sha256.bind(file.openRead()).first;
        if (digest.toString() != spec.sha256) return false;
      }
      if (spec.mustContain.isNotEmpty) {
        // Small-file structural check (no published hash): read tail-safe
        // prefix; both JSON files carry the marker in the first kilobytes.
        final head = await file
            .openRead(0, spec.sizeBytes > 65536 ? 65536 : spec.sizeBytes)
            .fold<List<int>>([], (acc, c) => acc..addAll(c));
        final text = utf8.decode(head, allowMalformed: true);
        if (!text.contains(spec.mustContain)) return false;
      }
      return true;
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
          final bad = await fileFor(spec);
          var detail = 'missing';
          try {
            if (await bad.exists()) {
              final len = await bad.length();
              final digest = await sha256.bind(bad.openRead()).first;
              detail = 'len=$len sha=$digest';
            }
          } catch (_) {}
          lastError =
              'SHA256 mismatch after download: ${spec.name} ($detail, want sha=${spec.sha256})';
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
      } else if (start == spec.sizeBytes) {
        // Fully present — verify instead of requesting an unsatisfiable
        // Range (server answers 416 when start == size). A corrupt full
        // file fails verify below and is deleted for a fresh pull.
        if (await _verifyFile(spec)) return;
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

  void dispose() {
    try {
      _session?.release();
    } catch (_) {}
    _session = null;
    _tokenizer = null;
    _layout = null;
    _sessionFailed = false;
  }

  Future<bool> _openSession() async {
    if (_session != null && _tokenizer != null) return true;
    if (_sessionFailed) return false;
    try {
      if (!await isReady()) {
        lastError = 'S1 bundle not downloaded — finish the S1 suite step first';
        return false;
      }
      OrtEnv.instance.init();
      final options = OrtSessionOptions()..setIntraOpNumThreads(4);
      final graph = await fileFor(
        bundleFiles.firstWhere((f) => f.name.endsWith('.onnx')),
      );
      _session = OrtSession.fromFile(graph, options);
      options.release();
      _layout = S1IoLayout.classify(_session!.inputNames, _session!.outputNames);
      if (_layout == null) {
        throw StateError(
          'Unrecognized S1 IO: in=${_session!.inputNames} out=${_session!.outputNames}',
        );
      }
      final tokFile = await fileFor(
        bundleFiles.firstWhere((f) => f.name.endsWith('tokenizer.json')),
      );
      final tokJson = jsonDecode(await tokFile.readAsString())
          as Map<String, dynamic>;
      _tokenizer = S1Tokenizer.fromJson(tokJson);
      debugPrint('[S1CleanupService] Session open (${_layout!.pastInputs.length} KV tensors).');
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[S1CleanupService] Session failed: $e');
      _sessionFailed = true;
      try {
        _session?.release();
      } catch (_) {}
      _session = null;
      return false;
    }
  }

  /// Builds thinking-off cleanup prompt ids. Static for unit tests.
  static List<int> buildPromptIds(S1Tokenizer tok, String raw) {
    final ids = <int>[
      ...tok.encode('<|im_start|>system\n$systemPrompt<|im_end|>\n'),
      ...tok.encode('<|im_start|>user\n$raw<|im_end|>\n'),
      ...tok.encode('<|im_start|>assistant\n<think>\n\n</think>\n\n'),
    ];
    if (ids.length > _maxPromptTokens) {
      return ids.sublist(ids.length - _maxPromptTokens);
    }
    return ids;
  }

  /// Flattens plugin-returned nested logit lists ([B, S, V]) to doubles.
  List<double> _flattenNumbers(dynamic node) {
    if (node is List) {
      return [for (final e in node) ..._flattenNumbers(e)];
    }
    return [(node as num).toDouble()];
  }

  int _argmax(List<double> logits) {    var best = 0;
    var bestVal = logits[0];
    for (var i = 1; i < logits.length; i++) {
      if (logits[i] > bestVal) {
        bestVal = logits[i];
        best = i;
      }
    }
    return best;
  }

  /// Thinking cleanup: raw transcript -> clean command. Returns [raw]
  /// unchanged when the bundle/session is unavailable or output is empty —
  /// never blocks the voice loop on S1.
  Future<String> cleanup(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (!await _openSession()) {
      debugPrint('[S1CleanupService] Session unavailable, passing through.');
      return text;
    }
    try {
      final tok = _tokenizer!;
      final session = _session!;
      final layout = _layout!;
      final promptIds = buildPromptIds(tok, text);
      final runOptions = OrtRunOptions();

      var pastSeqLen = 0;
      List<Float32List>? kvCache;
      final generated = <int>[];

      try {
        for (var step = 0; step < _maxNewTokens; step++) {
          final isFirst = step == 0;
          final stepIds = isFirst ? promptIds : [generated.last];
          final stepLen = stepIds.length;
          final inputs = <String, OrtValue>{};
          final created = <OrtValue>[];
          try {
            inputs[layout.inputIdsName] = OrtValueTensor.createTensorWithDataList(
              Int64List.fromList(stepIds),
              [1, stepLen],
            );
            created.add(inputs[layout.inputIdsName]!);
            if (layout.maskInput != null) {
              final total = pastSeqLen + stepLen;
              inputs[layout.maskInput!] =
                  OrtValueTensor.createTensorWithDataList(
                List<int>.filled(total, 1),
                [1, total],
              );
              created.add(inputs[layout.maskInput!]!);
            }
            for (var k = 0; k < layout.pastInputs.length; k++) {
              final cached = kvCache != null ? kvCache[k] : null;
              final data = cached ??
                  Float32List(_kvHeads * pastSeqLen * _headDim);
              inputs[layout.pastInputs[k]] =
                  createFp16Tensor(data, [1, _kvHeads, pastSeqLen, _headDim]);
              created.add(inputs[layout.pastInputs[k]]!);
            }

            final outputs = session.run(runOptions, inputs);
            try {
              var nextId = -1;
              final newCache = List<Float32List>.filled(
                layout.presentOutputs.length,
                Float32List(0),
              );
              for (var i = 0; i < outputs.length; i++) {
                final out = outputs[i];
                if (out == null) continue;
                final name = session.outputNames[i];
                try {
                  if (name == layout.logitsOutput) {
                    final tensor = out as OrtValueTensor;
                    final flat = _flattenNumbers(tensor.value);
                    final vocabSize = flat.length ~/ stepLen;
                    final last = flat.sublist((stepLen - 1) * vocabSize);
                    nextId = _argmax(last);
                  } else {
                    final idx = layout.presentOutputs.indexOf(name);
                    if (idx >= 0) {
                      final tensor = out as OrtValueTensor;
                      newCache[idx] = readFp16Tensor(tensor);
                    }
                  }
                } finally {
                  out.release();
                }
              }
              if (nextId < 0 || nextId == tok.eosId) break;
              generated.add(nextId);
              kvCache = newCache;
              pastSeqLen += stepLen;
            } finally {
              for (final o in outputs) {
                try {
                  o?.release();
                } catch (_) {}
              }
            }
          } finally {
            for (final v in created) {
              try {
                v.release();
              } catch (_) {}
            }
          }
        }
      } finally {
        runOptions.release();
      }

      if (generated.isEmpty) return text;
      var cleaned = tok.decode(generated).trim();
      // Strip stray think residue + quotes the model sometimes adds.
      final thinkEnd = cleaned.indexOf('</think>');
      if (thinkEnd >= 0) cleaned = cleaned.substring(thinkEnd + 8).trim();
      cleaned = cleaned.replaceAll(RegExp(r'^["\u201c\u201d]+|["\u201c\u201d]+$'), '').trim();
      if (cleaned.isEmpty) return text;
      debugPrint('[S1CleanupService] "$text" -> "$cleaned"');
      return cleaned;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[S1CleanupService] Inference failed, passing through: $e');
      return text;
    }
  }
}
