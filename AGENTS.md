# agents.md — REPP On-Device AI / Voice / Stick-Figure Upgrade

> Tracker for the local-AI + voice + tool-calling + stick-animation work.
> Source of truth for progress, decisions, and next steps.

---

## 1. Goal

REPP (Flutter, offline-first, mobile-only): a workout tracker whose AI coach
runs 100% on-device — sees (camera/vision), hears (mic/VAD/ASR), reasons
(Gemma 4 E2B + tool calls), cleans speech (S1 thinking pass), and speaks
(TTS) — with zero API keys, zero cloud, zero OS speech fallbacks.

1. **Local Multimodal LLM (Gemma 4 E2B)** — `gemma-4-E2B-it.litertlm`
   (~2.52 GB) via `flutter_gemma` + `flutter_gemma_litertlm` (LiteRT-LM,
   GPU-preferred) + Genkit plugin. Text, tools, image, audio in.
2. **Omni Voice Loop** — mic (`record`) → Silero VAD v5 (`vad` package,
   bundled ONNX) → moonshine-tiny STT → **S1-mini Q4 ONNX thinking cleanup**
   → Gemma (+ tools) → Inflect-Nano-v2 TTS → `just_audio` playback, with
   barge-in and 700 ms utterance coalescing.
3. **Tool-Calling & Stick Animation** — LLM creates routines in SQLite via
   `create_routine` (+ 9 more GymTools) and generates 2 KB JSON stick-figure
   keyframes via `generate_stick_animation` (CustomPainter, 17 COCO joints),
   augmenting/replacing heavy MP4 media.
4. **Routine Timer Auto-Pause** — auto-freezes workout elapsed timer during
   post-rest "Start" prompt and app backgrounding (`AppLifecycleState.paused`).

---

## 2. Architecture (Current — Locked)

```
Mic (record, 16kHz PCM) → SileroVadService (vad pkg, VAD v5 ONNX, 10fps-ish
│   hangover state machine, fan/AC-hum rejection)
│  → utterance PCM ──→ WhisperAsrService (moonshine-tiny via
│       flutter_gemma_speech LiteRtSttBackend, 5s windows)
│  → raw transcript ─→ S1CleanupService (S1-mini Q4 ONNX via onnxruntime
│       plugin + fp16-KV FFI bridge + Dart BPE codec, thinking rewrite)
│       ──→ OmniDuplexController (states, barge-in, 700ms coalesce,
│             5-min voice-stack unload)
│               ──→ AiCoachProvider.send ──→ GymCoachAgent ──→ Gemma 4 E2B
│                       (GenkitFlutterGemmaPlugin, tools, streaming)
│                   ──→ ToolExecutor → RoutineProvider (SQLite) + StickStore
│               ──→ CoachTtsService (sentence queue) ──→ GemmaSpeechTtsService
│                     (Inflect-Nano-v2 via LiteRtTtsBackend, 24kHz)
│                   ──→ just_audio playback ──→ orb UI (VoiceSpectrumOrb)
```

### Model suite (5 entries, ~3.05 GB, per-model subfolders + migration)

| # | Model | Files | Engine |
|---|-------|-------|--------|
| 1 | Gemma 4 E2B | `gemma-4-e2b/*.litertlm` 2.52 GB | LiteRT-LM, GPU-preferred |
| 2 | Silero VAD v5 | bundled `assets/models/` 2.3 MB | `vad` package (ONNX) |
| 3 | Moonshine tiny STT | `moonshine-tiny/` ~105 MB | `flutter_gemma_speech` STT backend |
| 4 | Inflect-Nano-v2 TTS | engine storage ~34 MB | `flutter_gemma_speech` TTS backend |
| 5 | S1-mini Q4 ONNX | `s1-mini-q4/` ~385 MB (graph+data+tok+cfg, SHA256) | `onnxruntime` plugin + FFI bridge |

* `ModelDownloadService`: background_downloader (Gemma) + FlutterGemma
  installers (STT/TTS, progress-mapped) + plain-http with Range resume
  (STT files, S1 files). Engine-managed vs file entries, legacy flat-path
  fallback when the OS denies the move. Banner in `AiCoachScreen`.
* **Zero OS fallbacks**: no `speech_to_text`, no `flutter_tts`, no
  `TextToSpeech`. `MainActivity` is an empty subclass; all custom Kotlin
  bridges deleted. Mic permission is requested before duplex start.
* **APK**: `--split-per-abi` (arm64 ~348 MB, 193 MB of it exercise MP4s —
  Phase 3 stick work shrinks this).

### Key files

* `lib/ai/audio/omni_duplex_controller.dart` — duplex state machine
* `lib/ai/audio/whisper_asr_service.dart` — moonshine STT facade
* `lib/ai/audio/s1_cleanup_service.dart` — S1 download/verify/session/loop
* `lib/ai/audio/s1_tokenizer.dart` — byte-level BPE (golden-tested 8/8)
* `lib/ai/audio/s1_ort_ffi.dart` — fp16 bridge + IO discovery
* `lib/ai/audio/silero_vad_service.dart` — VAD + hangover + fan filter
* `lib/ai/tts/{coach_tts_service,gemma_speech_tts_service}.dart`
* `lib/ai/{local_llm_service,gym_coach_agent,tool_executor}.dart`
* `lib/ai/tools/gym_tools.dart` — 10 tools, `ToolCall.tryParse`

---

## 3. Progress

| Phase | Scope | Status | Evidence |
|-------|-------|--------|----------|
| **0 — Scaffold** | `lib/ai/`, stick widgets, pose stubs, tool schemas, `AiCoachScreen`, `HomeScreen` AI tab, `assets/pose_templates/` | ✅ Done | Initial commits |
| **1 — Local LLM** | Genkit + LiteRT Gemma 4 E2B, `ModelDownloadService`, banner, manifest perms | ✅ Done | Chat works on-device |
| **Timer — Auto-Pause** | Freeze in post-rest "Start" overlay + lifecycle paused | ✅ Done | Auto-freezes, deducts idle |
| **2 — Omni voice (ASR+VAD)** | Mic perm gate, single VAD callback, onChunk fwd, singleton lifecycle, Kotlin main-thread fix | ✅ Done | `fix(omni)` + device smoke test (no crash) |
| **3 — flutter_gemma speech** | Qwen3→Inflect TTS, whisper→moonshine STT, suite 4 entries, deleted crispasr/whisper/bridges/.so | ✅ Done | `feat(speech)` + split APKs |
| **4 — S1 thinking cleanup** | Regex normalizer deleted; S1 Q4 download+SHA256; BPE codec; fp16 bridge; greedy loop; Omni wiring | ✅ Done | `feat(s1)` ×3, 27/27 tests |
| **5 — Suite hardening (device-driven)** | Per-model subfolders + migration + legacy fallback; S1 416 fix; STT via our downloader; hash corrections | ✅ Done | `fix(suite)` ×3, phone-verified TTS install |
| **Pose → LLM** | ML Kit 10fps + `AngleCalculator` + `RepCounter` → live cues | 🔲 Deferred | Stub in place (`pose_service.dart:43`) |
| **Stick Animation GA** | LLM keyframes + persistence + `ExerciseDetailScreen` fallback | 🔲 Next | 3 static templates only |
| **YOLO backlog** | YOLOv11 pose benchmarking + RAG over `howTo` | ⬜ Backlog | `yolo_pose_detector.dart` stub |

---

## 4. Todos (Current Sprint)

* [ ] Phone-verify S1 end-to-end: suite completes → mic turn → S1 rewrite visible → Gemma reply → Inflect voice
* [ ] Phone-verify moonshine STT accuracy in gym noise (parakeet-TDT via custom path is the fallback — needs runtime work, no native rebuild since crispasr is gone; reassess if needed)
* [ ] Fix first-run storage-permission storm (`AppManageExternalStorageActivity` pops over the app — move fully to app-private dir, drop the permission)
* [ ] Stick Animation GA (Phase 3)
* [ ] `flutter analyze` clean + full `flutter test` green before every push (enforced)

---

## 5. Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-04 | Mobile-only (drop Windows runner) | Android + iOS targets |
| 2026-09-04 | Timer auto-pause, no manual button | Hands-free workouts |
| 2026-09-08 | Gemma 4 E2B stays the brain (no Qwen3.5-2B switch) | 43.6% vs ~62% BFCL; untrusted conversion; thinking-loop risk |
| 2026-09-08 | All speech on flutter_gemma family (moonshine STT + Inflect TTS) | One accelerated engine, iOS-capable; deleted 186 MB `.so` + bridges |
| 2026-09-08 | TTS = Inflect-Nano-v2 over Qwen3-TTS/Matcha/Kokoro | Only demonstrated end-to-end path; 34 MB; realtime; Kokoro unwired, Qwen3 sub-realtime |
| 2026-09-08 | S1-mini Q4 ONNX (not GGUF) for thinking cleanup | Runtime already in APK via `vad` dep; GGUF needs second engine |
| 2026-09-08 | Delete regex normalizer; S1 owns cleanup | Regex can't do "scratch that" revisions |
| 2026-09-08 | Per-model subfolders + legacy fallback | Survives denied file-access permission without re-downloads |

---

*Last updated: 2026-09-09 — Voice stack fully on-device (E2B + moonshine + S1 + Inflect). Pending: phone proof of S1 turn, permission-storm fix, stick GA.*
