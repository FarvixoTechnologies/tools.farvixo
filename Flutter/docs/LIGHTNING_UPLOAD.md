# ⚡ Lightning Upload

**Universal upload engine · Farvixo Flutter**
Status: **built — running on the simulated transport**
Location: `lib/features/upload/`

One codebase. Android · iOS · Windows · macOS · Linux · Web · tablet · laptop · desktop · foldables.

---

## 1. The key art, in code

The hero is not an image asset — it is drawn every frame by
`LightningStagePainter`, so it stays crisp at any size, themes with the status,
and animates per layer. Ten layers, back to front:

| # | Layer | Notes |
|---|---|---|
| 1 | Night sky + vignette | Indigo→black vertical gradient, radial corner falloff |
| 2 | Ground glow | Pools under the platform, brightens on every strike |
| 3 | Storm cloud | 7 stacked lobes, each radially shaded; belly rim-lit by the bolt |
| 4 | Lightning bolt | 3 passes — wide blur glow, gold channel, near-white core + 2 forks |
| 5 | Platform | Dark metal slab, vent slots, accent strip catching ring light |
| 6 | Gold ring | Ambient track + bloom + **progress arc** + chasing highlight |
| 7 | Folder | Tab, contact shadow, black gradient body, gold edge, gloss sweep |
| 8 | Upload arrow | Amber gradient, outer glow, left-facet inner highlight |
| 9 | Sparks | 22 deterministic particles drifting upward |
| 10 | Burst | Expanding ring + 12 spokes on completion |

Every position is a **fraction of the stage box** (`UploadStage`), so the
composition is identical on a 320 px phone and an ultrawide panel — it scales,
it does not reflow.

### Palette — `lib/theme/upload_theme.dart`

| Role | Token | Hex |
|---|---|---|
| Sky top → deep | `skyTop` `skyMid` `skyDeep` | `#1A1236` `#150F2C` `#0B0818` |
| Cloud | `cloudLight` `cloudMid` `cloudDark` | `#7A68B8` `#574A85` `#3A3160` |
| Bolt | `boltCore` `boltHot` `bolt` `boltDeep` | `#FFF3C4` `#FFC53D` `#FFA31A` `#FF7A00` |
| Folder | `folderTop` `folderBottom` `folderEdge` | `#1B1826` `#0A0910` `#C9A227` |
| Arrow | `arrowTop` → `arrowBottom` | `#FFC53D` → `#FF8C1A` |
| Platform | `platformTop` `platformBottom` `platformEdge` | `#2A2740` `#14121F` `#3D3A5C` |
| Status | `success` `failure` `paused` | `#34D399` `#FB7185` `#94A3B8` |

**These are art-direction tokens, deliberately theme-fixed.** The stage is
always dark — a light-mode variant would destroy the lightning contrast, which
is the entire point of the design. Everything *around* the stage (queue, rail,
stats, sheets) uses the normal `AppPalette` and is fully theme-aware.

---

## 2. States

19 states in `UploadStatus`. Each one declares its own label, icon, stage tint
and **stage phase** — so the visual cannot desync from the logic.

| Phase | Stage behaviour | States |
|---|---|---|
| `resting` | Folder floats, ambient strike every ~4.2 s | idle · paused · offlineQueued |
| `charging` | Ring brightens, strikes double up | hover · pressed · selecting · preparing · resuming |
| `working` | Ring spins, strikes triple up | scanning · encrypting · processing · aiOptimizing · compressing · verifying · retrying |
| `striking` | Continuous lightning, maximum energy | **uploading** |
| `celebrating` | Burst, ring fills, green tint | completed |
| `faulted` | Cloud desaturates, no lightning, rose tint | failed · cancelled |

Each status also answers `canPause` / `canResume` / `canRetry` / `showsProgress`,
so the queue row renders only legal controls — no disabled-button guesswork.

---

## 3. Sources

`UploadSource` declares which platforms each source runs on, so the sheet never
offers something the device cannot do.

| Group | Sources | Status |
|---|---|---|
| **Device** | Files, Folder, Gallery, Camera, Scanner, Recent, External drive, Drag & drop | ✅ working |
| | Clipboard | ⛔ needs a clipboard-file plugin |
| **Cloud** | Google Drive, Dropbox, OneDrive, Box | ⛔ needs OAuth client IDs |
| **Network** | URL import | ⛔ needs backend fetch endpoint |
| | SMB, FTP/SFTP | ⛔ needs a network-FS plugin |

Blocked sources are **visible but locked**, with the reason inline
(`UploadPickerService.unavailableReason`). They don't silently do nothing.

### Platform matrix

| Source | Android | iOS | Win | macOS | Linux | Web |
|---|---|---|---|---|---|---|
| Files | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Folder | — | — | ✅ | ✅ | ✅ | — |
| Gallery / Camera / Scanner | ✅ | ✅ | — | — | — | — |
| External drive | ✅ | — | ✅ | ✅ | ✅ | — |
| Drag & drop | ✅ | — | ✅ | ✅ | ✅ | ✅ |
| SMB / FTP | — | — | ✅ | ✅ | ✅ | — |

Folder enumeration uses conditional imports (`folder_lister_io` /
`folder_lister_web`) because **`dart:io` cannot be imported at all in a web
build** — importing it unconditionally breaks `flutter build web`.

---

## 4. Transfer engine

`UploadQueueController` (Riverpod `Notifier`) owns admission, scheduling,
transfer and recovery.

| Feature | How |
|---|---|
| Multi-file queue | Immutable `UploadItem` list; `select()`-friendly so one row rebuilds |
| Concurrency | `uploadConcurrencyProvider`, default 3 |
| Priority | `UploadPriority.high/normal/low`, sorted before FIFO |
| Chunked transfer | `UploadTransport.chunkBytes`, 256 KB default |
| Pause | Cancels the subscription, records the byte offset |
| Resume | Restarts the stream at `fromByte` |
| Retry | Auto, 3 attempts, linear backoff; manual after that |
| Cancel | Aborts and marks terminal |
| Offline queue | Parks everything on disconnect, self-resumes on reconnect |
| Duplicate detection | Same name + size → flagged, **not** dropped; user decides |
| Speed | Exponential smoothing (0.7/0.3) so the readout doesn't flicker |
| ETA | `remaining / smoothed rate`, suppressed when not meaningful |
| Verify | `verifying` stage before `completed`, ready for a SHA-256 compare |

### The backend boundary

The UI **never** talks to Supabase, Firebase Storage or the Farvixo API. It
drives `UploadTransport`:

```dart
abstract class UploadTransport {
  Stream<ChunkProgress> send(UploadItem item, {int fromByte});
  int get chunkBytes;
}
```

This satisfies CLAUDE.md § DO NOT CHANGE (backend untouched) and makes the whole
queue testable without a network.

Shipping today: `SimulatedUploadTransport` — models jittered throughput
(±35 %), honours cancel and resume exactly like a real transport, and can inject
failures to exercise the error path. **Every queue behaviour above is real**,
only the bytes are synthetic.

To go live, override one provider:

```dart
uploadTransportProvider.overrideWithValue(FarvixoUploadTransport(...))
```

---

## 5. Which tools use upload — 71 of 143

`ToolUploadSpecs` (`domain/tool_upload_spec.dart`) is the single registry. Each
entry declares accepted extensions, single-vs-batch, batch ceiling and whether
mobile should open the gallery instead of the file browser.

| Category | Total | Upload | Why the rest don't |
|---|---:|---:|---|
| PDF | 19 | **19** | — |
| Image | 19 | **19** | — |
| Video | 14 | **13** | `screen-recorder` captures its own input |
| Audio | 13 | **11** | `audio-recorder` captures; `text-to-speech` takes text |
| AI | 20 | **5** | 15 are prompt-only (chat, writer, image-gen) |
| Developer | 22 | **2** | 20 are paste-only (base64, hash, JSON, JWT, UUID) |
| Text | 18 | **1** | 17 take typed text |
| Utility | 18 | **1** | 17 are calculators and generators |
| **Total** | **143** | **71** | |

Batch tools (`multiFile`): `merge-pdf` (30), `image-to-pdf` (100),
`video-merger` (20), `audio-merger` (20), `image-compressor`,
`image-converter`, `image-resizer` (50 each).

`test/tool_upload_spec_test.dart` guards this: it fails if a spec orphans, if a
PDF/Image/Video/Audio tool loses its spec, or if a typed-input tool grows one.

### Embedding in a tool

```dart
ToolUploadPanel(
  toolId: 'merge-pdf',
  onFilesReady: (files) => controller.run(files),
)
```

The panel reads the spec itself — accepted extensions, batch limits and source
list all come from the registry, not the call site. A tool id with no spec
renders nothing, so a text tool can never accidentally grow a drop zone.

---

## 6. Sizing — seven size classes

`UploadSizeClass` keys off the **shortest side**, not width. Using raw width is
the classic bug that makes a landscape phone render the desktop layout on a
5-inch screen.

| Class | Trigger | Panes | Hero max W | Hero H range | Chrome |
|---|---|:--:|---:|---|---|
| Compact phone | short < 360 | 1 | 300 | 200–300 | FAB |
| Phone | short < 600 | 1 | 380 | 260–400 | FAB |
| Foldable | width < 840 | 2 | 420 | 300–480 | FAB + stats |
| Tablet | width < 1024 | 2 | 460 | 320–540 | stats |
| Laptop | width < 1440 | 3 | 480 | 340–600 | rail 216 · queue 340 |
| Desktop | width < 1920 | 3 | 540 | 380–680 | rail 232 · queue 380 |
| Ultrawide | ≥ 1920 | 3 | 600 | 420–760 | rail 260 · queue 440 |

Every dimension lives in the `UploadMetrics` table — one place to read and
tune, not magic numbers spread through build methods. The hero clamps to both
the max (so it never dominates an ultrawide) and the min (so it never squashes
into something that reads as broken).

`UploadMetrics.embedded` gives the smaller variant used by `ToolUploadPanel`,
so the stage frames a tool's controls instead of competing with them.

Drag-and-drop wraps the **whole scaffold**, so a drop anywhere in the window
lands — not just on the hero.

---

## 7. Accessibility

- Stage is a labelled `Semantics` button announcing status and caption
- Queue rows announce name, status and size
- All icon actions have tooltips and 40×40 hit targets
- **Reduce-motion**: every controller stops; the stage renders a still frame
  with the bolt held at a phase-appropriate intensity — the art stays fully
  legible with zero animation
- Status is never colour-only — every state carries an icon and a text label

---

## 8. Files

```
lib/theme/upload_theme.dart              palette + stage geometry + motion
lib/features/upload/
  domain/
    upload_status.dart                   19 states + StagePhase
    upload_source.dart                   sources + platform matrix
    upload_item.dart                     item model + queue summary
    upload_transport.dart                backend boundary + simulator
  providers/
    upload_providers.dart                queue controller + providers
  services/
    upload_picker_service.dart           source → UploadItem
    folder_lister.dart / _io / _web      conditional folder enumeration
  presentation/
    upload_screen.dart                   3 responsive layouts
    widgets/
      lightning_stage_painter.dart       the key art
      lightning_hero.dart                animated stage + LightningMark
      upload_drop_zone.dart              universal OS drag & drop
      upload_queue_tile.dart             queue row
      upload_source_sheet.dart           source picker
```

Verified: **0 token violations · 0 const violations · 0 unbalanced files.**

---

## 9. Integration — one step left

The screen is built but **not routed**. `lib/routes/app_router.dart` is frozen
under CLAUDE.md § DO NOT CHANGE (Navigation/Routes), so wiring it is your call:

```dart
GoRoute(
  path: '/upload',
  builder: (context, state) => const UploadScreen(),
),
```

Until then, `UploadScreen` can be pushed directly or previewed in isolation.

---

## 10. Blocked work

| Blocker | Unblocks |
|---|---|
| **OAuth client IDs** — Google Drive, OneDrive, Dropbox, Box | 4 cloud sources |
| **Backend upload endpoint** | Real `UploadTransport`, URL import |
| **Network-FS plugin** | SMB, FTP/SFTP |
| **Clipboard-file plugin** | Clipboard source |

Everything else — state machine, key art, queue, chunking, pause/resume/retry,
offline parking, drag & drop, all three layouts — is done and needs no
credentials.

## 11. Not yet built

Named honestly so the roadmap stays accurate:

- **Encryption** — `encrypting` state exists and renders; no cipher is wired
- **Virus scan** — `scanning` state exists; no scanner behind it
- **AI classification / smart rename** — `aiOptimizing` state exists; no model call
- **Compression** — `compressing` state exists; no codec
- **SHA-256** — `verifying` state and the `sha256` field exist; no digest computed
- **Background upload** — foreground only; needs a platform background task
- **Bandwidth control / speed limit** — not implemented
- **Folder effect variants** (carbon, crystal, hologram…) — one finished
  treatment ships; the rest are art direction, not code
