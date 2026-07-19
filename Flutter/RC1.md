# Farvixo Mobile — Release Candidate 1 (RC1)

**Version:** `1.0.0-rc.1+1` · **Status:** FROZEN · **Scope:** Phase 5A tool-execution pipeline

> RC1 freezes the current implementation. **No new tools** are added until RC1
> is confirmed stable on a real Android device. Only build fixes, runtime bug
> fixes, and performance work are in scope during the RC.

---

## 1. Freeze scope

Frozen surface = the on-device / remote tool-execution pipeline built in Phase 5A
(increments 1–4) plus the existing app shell (home, tools, search, favorites,
detail, AI assistant, settings, auth).

Engine layer (frozen):
```
lib/features/tools/engine/
├── tool_engine.dart        # ToolEngine, ToolSpec, ToolResult, ToolInput, ToolChoiceSpec
├── tool_execution.dart     # ToolEngineRegistry + ToolExecutionController (progress/cancel)
├── tool_io_service.dart    # pick (file_picker/image_picker) · save · share (share_plus)
└── engines/
    ├── engine_util.dart · pdf_engines.dart · image_engines.dart
    ├── local_util_engines.dart · text_engines.dart · remote_engines.dart
```

## 2. Frozen tool inventory (23 tools)

**Local — on-device, offline (17):**
`merge-pdf`, `image-to-pdf`, `protect-pdf`, `image-compressor`, `image-resizer`,
`image-converter`, `rotate-flip-image`, `hash-generator`, `uuid-generator`,
`qr-generator`, `base64`, `json-formatter`, `json-validator`, `word-counter`,
`character-counter`, `case-converter`, `password-generator`, `lorem-ipsum-generator`

**Remote — existing Farvixo AI backend, session-authed (6):**
`ai-chat`, `ai-image-generator`, `ai-translator`, `ai-summarizer`, `ai-writer`,
`ai-email-writer`

Backend-slug aliases mapped to the same engine: `qr-code-generator`,
`base64-encoder-decoder` (+ `json-validator` shares the JSON engine).

Any slug not registered shows an honest "coming soon on mobile" card — never a
fake result.

## 3. Verification status at freeze

| Check | Result |
|---|---|
| `flutter analyze` | 0 errors, 0 warnings (1 `info`: unnecessary `dart:typed_data` import in `ai_service.dart` — non-blocking) |
| `flutter test test/tool_engines_test.dart` | 21/21 pass |
| Known-answer vectors | SHA-256/MD5/SHA-512, UUID v4 regex, Base64 round-trip, JSON, Case, Password, Lorem, Word Counter |
| Bug fixed pre-freeze | Title Case dropped spaces/punctuation → corrected + tested |
| Android debug/release build | **NOT yet green — see §4 (must pass to exit RC)** |
| Real-device QA | **Pending — see §5** |

## 4. Build runbook (priority 1 & 2)

Run on a machine with adequate RAM (the dev host here has ~5 GB and OOMs).

```bash
cd Flutter
flutter pub get
flutter build apk --debug       # Priority 1
flutter build apk --release     # Priority 2  (or: flutter build appbundle)
```

**Gradle heap:** `android/gradle.properties` is `-Xmx1536m` (tuned for the ~5 GB
dev host, where it OOMs Jetifier). On a larger machine, if you hit Jetifier
`Java heap space`, raise to `-Xmx3072m` (≥8 GB RAM) or `-Xmx4096m` (≥16 GB).

**Native deps requiring a real build to validate:** `file_picker`, `image_picker`,
`share_plus`, `syncfusion_flutter_pdf`, `qr_flutter`, `crypto`, `image`.
`minSdk 24` satisfies all. Manifest already declares INTERNET, CAMERA,
READ_MEDIA_*, storage, and share `<queries>` — no manifest change expected.

## 5. Real-device QA checklist (priority 3)

Cannot be automated — needs device + network + a signed-in session.

- [ ] **File picker** opens, returns bytes (media permission prompt first run)
- [ ] **PDF** merge / protect / image-to-PDF → Share/Save yields valid PDF
- [ ] **Image** compress / resize / convert / rotate from gallery + camera
- [ ] **AI Chat** streams; Cancel aborts mid-stream
- [ ] **AI Image Gen** returns an image (backend session/quota)
- [ ] **Translator** text + language → translated output
- [ ] **QR** Text/URL/Email/Phone → renders; Save PNG + Copy text
- [ ] **UUID** valid v4; Copy + Regenerate
- [ ] **Hash** MD5/SHA1/256/512; hex copyable
- [ ] **Base64** encode/decode round-trip
- [ ] **JSON** pretty/minify/validate; invalid → friendly error
- [ ] **Word Counter** full stats report

## 6. Performance profiling (priority 5)

After device QA passes, profile with `flutter run --profile` + DevTools:
- [ ] Large-image compress/resize — main-thread jank? (engines yield between
      steps but run on the UI isolate; `compute()`/isolate offload is the known
      follow-up for very large files)
- [ ] Large PDF merge — memory + frame times
- [ ] AI Chat streaming — no dropped frames while tokens arrive
- [ ] Tool grid scroll + provider rebuilds (Phase 4 optimizations in place)

## 7. Known constraints / risks

- On-device heavy processing runs on the main isolate (cooperative `yieldFrame`);
  fine for typical files, flagged for isolate offload post-RC.
- `ai_service.dart` carries a non-blocking `info` lint and an unused
  `_friendlyError`; left untouched (owner-maintained file).
- Remote tools require backend availability + auth; offline they surface a
  friendly "offline" error (chat also has a local mock fallback).

## 8. Exit criteria (RC1 → stable)

1. `flutter build apk --debug` green
2. `flutter build apk --release` green
3. Device QA checklist (§5) fully passed
4. All runtime bugs found during QA fixed
5. Performance profiling (§6) shows no blocking regressions

Only after all five: unfreeze and resume the next tool increment.
