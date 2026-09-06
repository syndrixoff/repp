# agents.md — REPP AI/ Pose / Stick-Figure Upgrade

> Tracker for the local-AI + YOLO skeleton + tool-calling + stick-animation work.
> Source of truth for progress, decisions, and next steps.

---

## 1. Goal

Upgrade REPP (Flutter, offline-first, mobile-only):

1. **Local Multimodal LLM (Gemma 4 E2B Q4_K_M)** — runs on-device via `fllama` (llama.cpp) with `--jinja` template, zero API keys, any-to-any multimodal I/O (text, tools, image, video clip, audio PCM).
2. **Pose Detection & Angle Tracking** — `google_mlkit_pose_detection` (10fps throttle) + `AngleCalculator` (knee/hip/elbow) + `RepCounter` -> compact `PoseContext` text + raw crop JPEG to model for real-time form guidance.
3. **Tool-Calling & Stick Animation** — LLM creates routines in SQLite via `create_routine` and generates 2KB JSON stick-figure keyframes via `generate_stick_animation` (CustomPainter 17 COCO joints) augmenting/replacing heavy MP4 media.
4. **Routine Timer Auto-Pause** — auto-freezes workout elapsed timer during post-rest "Start" prompt and app backgrounding (`AppLifecycleState.paused`), deducting dead idle time.

---

## 2. Architecture Decision (Locked Roadmap)

```
Camera (camera ^0.12) → PoseService (google_mlkit_pose_detection @ 10fps)
                     → AngleCalculator (knee/hip/elbow) + RepCounter
                     → PoseContext text + raw crop JPEG
Audio Input (record)  → 16kHz PCM audio bytes
Video Input           → video_sampler.dart (1fps / 2 frames per ~2s clip @ 320p)
                     │
                     ▼
             GymCoachAgent (unified prompt + Jinja assistant template + GymTools schemas)
                     │
                     ▼
             LocalLlmService / FllamaService
               Model: unsloth/gemma-4-E2B-it-GGUF:gemma-4-e2b-it-Q4_K_M.gguf (~1.2GB)
               Single base only, --jinja enabled, downloaded on-demand via ModelDownloadService
               Fallback: MockLlmService until model is downloaded
                     │
                     ▼
             ToolExecutor → RoutineProvider (SQLite) + StickStore (App Docs)
                     │
                     ▼
             StickFigurePainter / StickAnimator (CustomPainter, 17 COCO joints, lerp keyframes)
```

### Why this stack:
* **Mobile-only**: Dropped Windows desktop runner; Android & iOS mobile targets.
* **Gemma 4 E2B Q4_K_M**: Single unified any-to-any multimodal checkpoint (~1.2GB). Avoids multi-model bloat (no separate CLIP or Whisper needed). Excellent tool-calling and JSON reliability.
* **fllama with `--jinja`**: Mobile llama.cpp runtime supporting Gemma 4 It chat template so tool JSON schemas never malform.
* **ML Kit Pose**: Zero model file download, runs at 30fps (throttled to 10fps for feature extraction), high accuracy.
* **Video Sampling (1fps / 2 frames @ 320p)**: Cuts token load by ~50% (~500 vs 1000 tokens), speeds up inference to ~8–10s, fits 3GB–4GB devices.

---

## 3. Progress

| Phase | Scope | Status | Evidence |
|-------|-------|--------|----------|
| **0 — Scaffold** | `lib/ai/`, stick widgets, pose stubs, tool schemas, `AiCoachScreen`, `HomeScreen` 5th tab, `assets/pose_templates/` | ✅ Done | Initial commit & scaffold in place |
| **1 — Local LLM & Multimodal** | `pubspec` dependencies (`fllama`, `camera`, `google_mlkit_pose_detection`, `record`, `just_audio`), `ModelDownloadService` (Range resume + SHA256), `FllamaService` (Jinja + multimodal), `video_sampler.dart`, `AndroidManifest.xml` permissions | ✅ Done | Built, tested, and pushed |
| **Timer — Auto-Pause** | Auto-freeze timer in post-rest "Start" overlay & lifecycle paused state | ✅ Done | Auto-freezes on 0s and backgrounding |
| **2 — Pose → LLM** | Camera stream throttle (10fps) + `AngleCalculator` + `RepCounter` -> `PoseContext` injection + live cues | 🔲 Next | Phase 2 |
| **3 — Stick Animation GA** | LLM keyframe generation + persistence in app docs + `ExerciseDetailScreen` fallback | 🔲 Next | Phase 3 |
| **4 — YOLO Backlog** | YOLOv11 pose benchmarking + RAG over `howTo` steps | ⬜ Backlog | Future |

---

## 4. Todos

### Phase 1 & Timer (Current Sprint)
- [ ] Add dependencies to `pubspec.yaml`: `fllama`, `camera`, `google_mlkit_pose_detection`, `permission_handler`, `just_audio`, `record`, `device_info_plus`
- [ ] Update `AndroidManifest.xml` (INTERNET, ACCESS_NETWORK_STATE, CAMERA, RECORD_AUDIO, `largeHeap="true"`)
- [ ] Remove `sqflite_common_ffi` desktop guards in `lib/main.dart`
- [ ] Implement `ModelDownloadService`: download `gemma-4-e2b-it-Q4_K_M.gguf` with HTTP Range resume, SHA256 verify, WiFi check
- [ ] Add Model Download banner in `AiCoachScreen` with progress bar & WiFi gate
- [ ] Implement `FllamaService` with `--jinja` multimodal support (text, tools, image, audio, video frames)
- [ ] Create `lib/ai/multimodal/video_sampler.dart` (1fps / 2 frames @ 320p from ~2s clip)
- [ ] Implement Routine Timer Auto-Pause: freeze in `GuidedWorkoutScreen` during "Start" prompt after break timer finishes and during `AppLifecycleState.paused`
- [ ] Verify `flutter analyze` passes with zero warnings

---

## 5. Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-04 | Mobile-only (Drop Windows) | App targets Android and iOS devices |
| 2026-09-04 | Gemma 4 E2B Q4_K_M single base | Any-to-any multimodal (vision, audio, tools) in 1.2GB; avoids multi-model bloat |
| 2026-09-04 | Q4_K_M default, no Q6_K quality toggle | Lean footprint, fits comfortably in mobile memory headroom |
| 2026-09-04 | 1fps / 2-frame video sampling @ 320p | Saves 50% tokens, cuts inference time to 8–10s on mobile |
| 2026-09-04 | Timer auto-pause (no manual pause button) | Hands-free experience during workouts; freezes idle time after rest timer ends |

---

*Last updated: 2026-09-04 — Locked decisions confirmed. Ready to execute Phase 1 & Timer.*
