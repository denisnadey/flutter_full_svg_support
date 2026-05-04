# Graph Report - comparison  (2026-04-28)

## Corpus Check
- Corpus is ~10,688 words - fits in a single context window. You may not need a graph.

## Summary
- 119 nodes · 213 edges · 12 communities detected
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 23 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Comparison UI & Design Rationale|Comparison UI & Design Rationale]]
- [[_COMMUNITY_Flutter Launch & Build Pipeline|Flutter Launch & Build Pipeline]]
- [[_COMMUNITY_Swift SCK Screen Recorder|Swift SCK Screen Recorder]]
- [[_COMMUNITY_TCC Permission Detection|TCC Permission Detection]]
- [[_COMMUNITY_Session Orchestration & Post-processing|Session Orchestration & Post-processing]]
- [[_COMMUNITY_Disclaimed posix_spawn  TCC Bypass|Disclaimed posix_spawn / TCC Bypass]]
- [[_COMMUNITY_Telemetry HTTP Server|Telemetry HTTP Server]]
- [[_COMMUNITY_Screen Capture Probe Methods|Screen Capture Probe Methods]]
- [[_COMMUNITY_ffmpeg & Flutter Telemetry Build|ffmpeg & Flutter Telemetry Build]]
- [[_COMMUNITY_macOS Version & Fallback Diagnostics|macOS Version & Fallback Diagnostics]]
- [[_COMMUNITY_Swift Recorder Build & Hash Cache|Swift Recorder Build & Hash Cache]]
- [[_COMMUNITY_Silent HTTP Log Handler|Silent HTTP Log Handler]]

## God Nodes (most connected - your core abstractions)
1. `main()` - 25 edges
2. `_info()` - 17 edges
3. `SCKRecorder` - 12 edges
4. `main()` - 12 edges
5. `ensure_screen_recording_permission()` - 10 edges
6. `SVG Comparison HTML (Chrome Native)` - 9 edges
7. `Side-by-side Comparison Harness README` - 9 edges
8. `probe_with_swift_recorder()` - 7 edges
9. `_die()` - 6 edges
10. `_osascript()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `SVG Comparison HTML (Chrome Native)` --references--> `Galactic Storm SVG (stress asset)`  [EXTRACTED]
  comparison/comparison.html → assets/stress/galactic_storm.svg
- `Side-by-side Comparison Harness README` --references--> `Flutter Benchmark App (release .app)`  [EXTRACTED]
  comparison/README.md → benchmark_app/lib/main.dart
- `Side-by-side Comparison Harness README` --references--> `Galactic Storm SVG (stress asset)`  [EXTRACTED]
  comparison/README.md → assets/stress/galactic_storm.svg
- `Side-by-side Comparison Harness README` --references--> `Flutter Telemetry Metrics Reporter`  [EXTRACTED]
  comparison/README.md → benchmark_app/lib/telemetry/metrics_reporter.dart
- `Flutter Telemetry Metrics Reporter` --references--> `Telemetry HTTP Server (:18765)`  [INFERRED]
  benchmark_app/lib/telemetry/metrics_reporter.dart → comparison/README.md

## Communities

### Community 0 - "Comparison UI & Design Rationale"
Cohesion: 0.12
Nodes (21): Chrome rAF 60Hz Clamp on macOS (known limitation), SVG Comparison HTML (Chrome Native), Side-by-side Comparison Harness README, Flutter Benchmark App (release .app), FPS HUD (Heads-Up Display), Galactic Storm SVG (stress asset), Local HTTP Server (stdlib, serves benchmarks/), HUD GPU Compositor Layer Design (translateZ, will-change) (+13 more)

### Community 1 - "Flutter Launch & Build Pipeline"
Cohesion: 0.18
Nodes (19): build_flutter_release(), _die(), ensure_macos_platform(), find_built_app(), find_chromium(), _find_flutter(), get_screen_size(), launch_chrome() (+11 more)

### Community 2 - "Swift SCK Screen Recorder"
Cohesion: 0.19
Nodes (7): NSObject, AVAssetWriter, AVAssetWriter.Status, Main, SCKRecorder, SCStreamDelegate, SCStreamOutput

### Community 3 - "TCC Permission Detection"
Cohesion: 0.14
Nodes (14): detect_xcode_make_in_chain(), ensure_screen_recording_permission(), get_process_chain(), identify_owning_app(), macos_check_screen_capture(), macos_request_screen_capture(), open_screen_recording_settings(), Walk up the process tree from os.getppid(), return [(pid, comm), ...]. (+6 more)

### Community 4 - "Session Orchestration & Post-processing"
Cohesion: 0.46
Nodes (7): aggregate(), find_ffmpeg(), kill_app_by_name(), main(), start_server(), stats(), write_report()

### Community 5 - "Disclaimed posix_spawn / TCC Bypass"
Cohesion: 0.29
Nodes (7): _libsystem(), probe_with_swift_recorder(), posix_spawn the executable with `responsibility_spawnattrs_setdisclaim(1)`., Wait for child PID, return exit code (or -1 if killed/timeout)., 1 s capture via the Swift recorder. Validates by exit code + file size.      Use, spawn_disclaimed(), waitpid_full()

### Community 6 - "Telemetry HTTP Server"
Cohesion: 0.33
Nodes (2): BaseHTTPRequestHandler, _Handler

### Community 7 - "Screen Capture Probe Methods"
Cohesion: 0.33
Nodes (6): measure_luminance(), probe_with_screencapture(), quick_permission_probe(), Extract first-frame YAVG from a video. 0 ≈ black, 235 ≈ white., Try the Apple-signed system recorder. Often works when ffmpeg can't,     because, Capture 1s with ffmpeg-avfoundation and verify it isn't all black.

### Community 8 - "ffmpeg & Flutter Telemetry Build"
Cohesion: 0.33
Nodes (6): _info(), build_flutter_with_telemetry(), detect_screen_index(), make_gif(), Run ffmpeg's device list and pick `[N] Capture screen 0`., split_recording()

### Community 9 - "macOS Version & Fallback Diagnostics"
Cohesion: 0.5
Nodes (5): macos_major_version(), _print_probe_failure_help(), `screencapture -V <duration>` was added in macOS 14 (Sonoma)., All capture methods failed — print actionable diagnostics and exit., screencapture_video_supported()

### Community 10 - "Swift Recorder Build & Hash Cache"
Cohesion: 0.5
Nodes (4): ensure_swift_recorder(), SHA-256 of recorder.swift content, truncated to 16 hex chars., Compile recorder.swift on first use; package as a .app bundle.      The binary i, _swift_src_hash()

### Community 11 - "Silent HTTP Log Handler"
Cohesion: 0.67
Nodes (2): Quiet variant — request logs would otherwise spam the launcher console., _SilentHandler

## Knowledge Gaps
- **34 isolated node(s):** `AVAssetWriter.Status`, `Run an AppleScript snippet, return stdout.`, `Return (width, height) of the primary display in points.`, `Move + resize the front window of `process_name` via System Events.`, `Quiet variant — request logs would otherwise spam the launcher console.` (+29 more)
  These have ≤1 connection - possible missing edges or undocumented components.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `start_server()` connect `Session Orchestration & Post-processing` to `Flutter Launch & Build Pipeline`, `Swift SCK Screen Recorder`?**
  _High betweenness centrality (0.170) - this node is a cross-community bridge._
- **Why does `main()` connect `Session Orchestration & Post-processing` to `Flutter Launch & Build Pipeline`, `TCC Permission Detection`, `Disclaimed posix_spawn / TCC Bypass`, `Screen Capture Probe Methods`, `ffmpeg & Flutter Telemetry Build`, `macOS Version & Fallback Diagnostics`, `Swift Recorder Build & Hash Cache`?**
  _High betweenness centrality (0.154) - this node is a cross-community bridge._
- **Are the 7 inferred relationships involving `main()` (e.g. with `_die()` and `find_chromium()`) actually correct?**
  _`main()` has 7 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `_info()` (e.g. with `ensure_screen_recording_permission()` and `detect_screen_index()`) actually correct?**
  _`_info()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **What connects `AVAssetWriter.Status`, `Run an AppleScript snippet, return stdout.`, `Return (width, height) of the primary display in points.` to the rest of the system?**
  _34 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Comparison UI & Design Rationale` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._
- **Should `TCC Permission Detection` be split into smaller, more focused modules?**
  _Cohesion score 0.14 - nodes in this community are weakly interconnected._