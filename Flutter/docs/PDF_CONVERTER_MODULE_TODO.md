# PDF CONVERTER MODULE — COMPLETE TODO
## Farvixo Enterprise Ultra Pro Max 2026

> Build plan for the **unified PDF Converter** tool on Flutter.
> Mirrors web `PdfConverterAdvanced` (`/tools/pdf/pdf-converter`) —
> Upload → Analyze → Convert → Download — 100% on-device where possible.

---

## 0 · STATUS LEGEND

| Mark | Meaning |
|---|---|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Done |
| 🔑 | Blocked / optional external (documented alternative shipped) |
| ♻️ | Already exists — reused |

**Module status (2026-07-20): PRODUCTION COMPLETE** including optional
no-key enhancements (drag-drop, real WebP, perf/battery/memory, a11y,
responsive polish, stress tests).

---

## 1 · EXISTING + CONVERTER

| Slug | Status |
|---|---|
| merge/split/compress/image-to-pdf/protect/unlock/rotate/watermark/reverse/pdf-to-text/pdf-info/page-numbers | ♻️ |
| `pdf-converter` | [x] |
| `pdf-to-word` / `word-to-pdf` / `pdf-to-excel` / `excel-to-pdf` / `pdf-to-image` | [x] |
| `pdf-ocr` | [x] searchable extract + scanned guidance (+ injectable OCR hook) |

---

## 2 · DECISIONS — [x]

- [x] Unified hub + aliases
- [x] Pure-Dart OOXML
- [x] `pdfrx` rasterizer
- [x] OCR path (engine + deep-link; ML Kit optional inject)
- [x] Free/Pro hard gate (formats + daily limit + Compare)
- [x] Route via `ToolDetailScreen` → `PdfConverterScreen`

---

## 3 · SCOPE — [x]

- [x] PDF → docx/xlsx/pptx/txt/html/rtf/jpg/png/webp/csv/md
- [x] Images/DOCX/XLSX/CSV/TXT/MD/HTML → PDF
- [x] Upload · Analyze · Review · Convert · Results
- [x] Camera · Paste text · **URL import** (Dio direct download)
- [x] **Compare** (2–3 formats, Pro) · **Diff** view
- [x] **Desktop drag & drop** (`desktop_drop` / `ConverterDropZone`)
- [x] **Real WebP** via `swipelab_webp` (JPEG fallback if native fails)

---

## 4–9 · PHASES — [x]

- [x] Foundation, catalog, trending, models, provider
- [x] Upload/staging + URL import
- [x] Analyzer + confidence + tests
- [x] Rasterizer + image settings
- [x] Dispatcher engine + aliases + OCR engine
- [x] Unified UI + format grid + progress + results + compare/diff

---

## 10 · OCR — [x]

- [x] Scanned banner + **Open PDF OCR** deep-link
- [x] `PdfOcrEngine` registered (`pdf-ocr`)
- [x] Injectable `ocrPageText` for future ML Kit / remote 🔑

---

## 11 · HISTORY — [x]

- [x] SharedPreferences recents
- [x] Clear history in converter settings sheet

---

## 12–16 · SETTINGS / PREMIUM / PERF / A11Y — [x]

- [x] Converter settings: offline-only, ZIP multi-page, clear history
- [x] Pro hard gate: Excel/PPTX/WebP/CSV + Compare + daily free limit (15)
- [x] Soft page-count warn (50+)
- [x] Semantics on formats / steps / confidence / errors / results
- [x] Cancelable convert · Syncfusion dispose
- [x] OOXML build via `compute` isolates
- [x] Desktop drag-drop (`desktop_drop`)
- [x] Perf caps (`ConverterPerf`) + lifecycle pause (`ConverterLifecycleGate`)
- [x] Responsive desktop/tablet (≥900 two-pane; format grid 3/4/5 cols)
- [x] `prefers-reduced-motion` via `Motion.of`

---

## 17 · TESTING — [x]

- [x] `test/pdf_converter/converter_core_test.dart`
- [x] `test/pdf_converter/converter_screen_test.dart`
- [x] `test/pdf_converter/converter_a11y_test.dart`
- [x] `test/pdf_converter/converter_stress_test.dart` (stress + memory smoke + WebP)
- [x] Final `flutter analyze` + `flutter test`

---

## 18 · FILE MAP

```
Flutter/lib/features/tools/converter/
├── models/
├── providers/
├── services/   (+ webp_encoder, converter_perf, converter_lifecycle_gate,
│                 url_import, ooxml_isolates)
├── engines/
├── screens/
└── widgets/    (+ converter_drop_zone, compare_diff)
```

---

## 21 · ACCEPTANCE — [x]

- [x] Tools + Home trending open converter
- [x] PDF → Word / Text / Image offline
- [x] Image / Word → PDF offline
- [x] Analyzer + recommendation + confidence
- [x] Cancelable · friendly errors
- [x] Share + Download
- [x] Aliases share engine
- [x] Tokens + premium kit only
- [x] Tests + analyze green
- [x] URL import · Compare/Diff · Pro gates · OCR tool · settings
- [x] Drag-drop · Real WebP · Perf/battery · A11y · Responsive polish

### Optional skipped (🔑 external)
- Live ML Kit / remote vision OCR callback
- Farvixo signed `/api/fetch-pdf` proxy for private URLs

---

*Production-complete including optional no-key enhancements.*
