# QR SCANNER MODULE — COMPLETE TODO
## Farvixo Enterprise Ultra Pro Max 2026

> Build plan for the QR Scanner + Generator module.
> Grounded in the **existing** Farvixo codebase — reuses `design_tokens.dart`,
> `app_palette.dart`, `premium_kit.dart`, Riverpod and `go_router`.
> Tick items as they land. Phases are ordered by dependency.

---

## 0 · STATUS LEGEND

| Mark | Meaning |
|---|---|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Done |
| 🔑 | **Blocked** — needs an API key / account / native code from you |
| ♻️ | Already exists in the app — reuse, don't rebuild |

---

## 1 · WHAT YOU ALREADY HAVE (do not rebuild)

- ♻️ `mobile_scanner: ^7.0.1` — live camera scanning
- ♻️ `zxing2: ^0.2.3` — pure-Dart decode (gallery images)
- ♻️ `qr_flutter: ^4.1.0` — QR generation
- ♻️ `image_picker`, `share_plus`, `url_launcher`, `file_picker`, `path_provider`
- ♻️ `local_auth`, `flutter_secure_storage` — biometric / PIN lock, encrypted store
- ♻️ `syncfusion_flutter_pdf`, `crypto`
- ♻️ Design system: `Insets`, `Radii`, `AppColors`, `AppPalette`, `AppTheme`
- ♻️ Premium UI kit: `PremiumBackground`, `GlassCard`, `GlowIcon`, `FadeSlideIn`,
      `PremiumHeader`, `PremiumEmptyState`, `CircleGlassButton`, `PremiumSectionHead`
- ♻️ Theme system: dark / light / custom accent (already shipped)
- ♻️ `tools_data.dart` already registers `qr-scanner` and `qr-generator`

---

## 2 · DECISIONS NEEDED FROM YOU (answer before Phase 1)

- [ ] **Color reconciliation.** Spec says Primary `#6D4AFF`, Secondary `#00D4FF`,
      BG `#09090B`. App currently uses `brandPrimary #7C3AED`, `bgBase #0A0A12`.
      → Choose: (a) keep Farvixo brand app-wide, (b) adopt spec colors app-wide,
      or (c) QR module gets its own accent override.
- [ ] **Scanner engine.** `mobile_scanner` alone (already installed, simpler) vs
      adding `google_mlkit_barcode_scanning` (better exotic-format + on-device ML).
- [ ] **History storage.** `hive` vs `isar` vs existing `shared_preferences` +
      `flutter_secure_storage`. (Recommend Hive — light, encryptable.)
- [ ] **Is this a standalone screen or a Farvixo tool?** i.e. does it live at
      `/tool/qr-scanner` or get its own `/qr` route + bottom-nav tab?

---

## 3 · PHASE 1 — FOUNDATION

### 1.1 Dependencies
- [ ] Add `permission_handler` (camera permission flow)
- [ ] Add `connectivity_plus` (offline detection for security checks)
- [ ] Add `hive` + `hive_flutter` (scan history store) *(or Isar per decision)*
- [ ] Add `flutter_animate` (120fps micro-animations)
- [ ] Add `printing` + `pdf` (Export/Print actions)
- [ ] Add `flutter_svg` (SVG QR export)
- [ ] Add `dynamic_color` + `material_color_utilities` (Material You)
- [ ] *(optional)* `lottie` — success/scan animations
- [ ] *(optional)* `google_mlkit_barcode_scanning` — per decision above
- [ ] Run `flutter pub get`, verify Android `minSdk` (ML Kit needs 21+)

### 1.2 Platform config
- [ ] Android: `CAMERA` permission in `AndroidManifest.xml`
- [ ] Android: camera hardware `<uses-feature>` (not required, so tablets install)
- [ ] iOS: `NSCameraUsageDescription` in `Info.plist`
- [ ] iOS: `NSPhotoLibraryUsageDescription` (gallery import)
- [ ] Test permission denied / permanently-denied → settings deep link

### 1.3 Module scaffold
- [ ] Create `lib/features/qr/` with subfolders:
      `models/`, `providers/`, `services/`, `screens/`, `widgets/`
- [ ] `models/scan_result.dart` — type, raw value, parsed payload, timestamp,
      source (camera/gallery), risk level, confidence
- [ ] `models/qr_type.dart` — enum for all 25 payload types
- [ ] Register routes in `lib/routes/app_router.dart`
- [ ] Add QR entry points from Home quick actions + Tools grid

### 1.4 Design tokens for the module
- [ ] Extend `design_tokens.dart` with scanner-specific tokens
      (frame size, laser speed, corner radius, glow blur)
- [ ] Add risk-level colors (safe/warning/danger) to `AppColors`

---

## 4 · PHASE 2 — CORE SCANNER

### 2.1 Camera screen
- [ ] `screens/qr_scanner_screen.dart` — full-bleed camera preview
- [ ] Instant camera start (pre-warm controller, no white flash)
- [ ] Scan / History segmented toggle (top pills, per mockup)
- [ ] Header: menu · title + verified badge · "Secure • Fast • Smart" · flash pill
- [ ] Proper lifecycle: pause camera on background, dispose on exit
- [ ] Handle permission-denied state with premium empty state + CTA

### 2.2 Camera overlay
- [ ] `widgets/scanner_overlay.dart` — dimmed mask + rounded cutout
- [ ] Animated neon corner brackets (cyan, glowing)
- [ ] Moving laser line (vertical sweep, ~2s loop, `RepaintBoundary`)
- [ ] Corner glow pulse
- [ ] Auto-focus tap indicator (ripple at tap point)
- [ ] Smart hint text: "Align QR code within the frame"
- [ ] Brightness meter → auto-suggest torch in low light
- [ ] Distance indicator ("move closer" when code too small)
- [ ] Night mode (boost exposure)
- [ ] Success animation: brackets snap green + haptic + beep

### 2.3 Controls
- [ ] Torch toggle (with on/off state + glow)
- [ ] Gallery import → decode via `zxing2`
- [ ] Zoom control (− 1.0x +) wired to camera zoom
- [ ] Pinch-to-zoom gesture
- [ ] Camera switch (front/back)
- [ ] Multi-code handling — if several in frame, let user pick

### 2.4 Detection
- [ ] Debounce duplicate scans (ignore same value within ~2s)
- [ ] Format support: QR, Code128, EAN-8/13, UPC-A/E, ITF, Codabar,
      Code39/93, PDF417, Aztec, Data Matrix
- [ ] Haptic + sound on detect (respect settings)
- [ ] Auto-navigate to result (respect "Smart Scan" auto-action setting)

---

## 5 · PHASE 3 — PAYLOAD PARSING

- [ ] `services/qr_parser.dart` — raw string → typed payload
- [ ] URL / Link (+ punycode & IDN homograph detection)
- [ ] Wi-Fi (`WIFI:S:…;T:WPA;P:…;`)
- [ ] vCard / MeCard → contact
- [ ] Email (`mailto:`) · SMS (`smsto:`) · Phone (`tel:`)
- [ ] Geo location (`geo:`) → map preview
- [ ] Calendar event (`VEVENT`)
- [ ] UPI payment (`upi://pay`) — parse VPA, amount, note
- [ ] Crypto wallet (bitcoin:, ethereum:)
- [ ] Social deep links: WhatsApp, Telegram, Instagram, Facebook, Discord
- [ ] ISBN / product barcodes → lookup-ready
- [ ] Plain text fallback
- [ ] Unit tests for every parser (malformed input must not crash)

---

## 6 · PHASE 4 — SCAN RESULT SCREEN

- [ ] `screens/scan_result_screen.dart` — glass card, `PremiumBackground`
- [ ] Large type icon with accent glow (per type)
- [ ] Category label · title · subtitle · raw-value preview
- [ ] Rich previews: URL favicon/title, map thumbnail, contact card, Wi-Fi SSID
- [ ] Security banner: risk level, score, confidence %
- [ ] Metadata: scan time, source (camera/gallery), format
- [ ] Smart action buttons, contextual per type:
  - [ ] Open Website · Copy · Share · Save to History · Favorite
  - [ ] Connect Wi-Fi · Add Contact · Add Calendar · Open Maps
  - [ ] Call · Send Email · Send SMS · Pay UPI · Launch App
  - [ ] Search Google · Translate · Generate Again
  - [ ] Export PDF · Export Image · Print
- [ ] Danger interstitial — block auto-open on high risk, require confirm
- [ ] Copy/Share feedback via snackbar + haptic

---

## 7 · PHASE 5 — SECURITY ENGINE

> ⚠️ Realistic scope: **heuristics work offline and ship now.** Reputation
> lookups need third-party services and are blocked on keys.

### 5.1 Offline heuristics (no key needed)
- [ ] `services/security_engine.dart`
- [ ] URL shortener detection (bit.ly, tinyurl…) → warn "destination hidden"
- [ ] IDN / homograph / punycode spoof detection
- [ ] IP-address-as-host detection
- [ ] Excessive subdomain / lookalike-brand detection
- [ ] Non-HTTPS warning
- [ ] Suspicious TLD list
- [ ] Embedded-credentials (`user:pass@host`) detection
- [ ] Risk scoring model → safe / caution / danger + confidence
- [ ] Privacy warning for payloads containing personal data

### 5.2 Online reputation
- [ ] 🔑 Google Safe Browsing API — **needs API key**
- [ ] 🔑 VirusTotal URL reputation — **needs API key**
- [ ] 🔑 AI threat summary — **needs LLM endpoint/key** (can route via existing `AiService`)
- [ ] SSL certificate validity check
- [ ] Cache verdicts locally (TTL) to save quota + work offline
- [ ] Graceful degradation → heuristics only when offline

---

## 8 · PHASE 6 — QR GENERATOR

### 6.1 Types
- [ ] `screens/qr_generator_screen.dart` with type tabs
- [ ] URL · Text · Wi-Fi · Contact (vCard) · Email · Phone · SMS
- [ ] UPI · Location · Event · Crypto · App Link · Play/App Store
- [ ] WhatsApp · Telegram · Instagram · Custom raw data
- [ ] Per-type form + validation + live preview

### 6.2 Styling
- [ ] Foreground / background color pickers
- [ ] Gradient QR
- [ ] Rounded modules
- [ ] Custom eye styles
- [ ] Logo upload (center overlay, keep error-correction H)
- [ ] Frame styles with caption
- [ ] Transparent background
- [ ] ⚠️ Validate scannability after styling (contrast + quiet zone check)

### 6.3 Export
- [ ] PNG export (`RepaintBoundary` → image)
- [ ] SVG export (`flutter_svg` / manual path build)
- [ ] PDF export (`pdf` package)
- [ ] Save to gallery · Share · Print
- [ ] Batch generate (premium)

---

## 9 · PHASE 7 — HISTORY & FAVORITES

- [ ] Hive box + adapter for `ScanResult`
- [ ] `screens/scan_history_screen.dart` (matches mockup)
- [ ] Search bar (debounced)
- [ ] Category filter chips: All · Link · Wi-Fi · Text · Contact · Email · Location
- [ ] Grouped timeline (Today / Yesterday / Earlier)
- [ ] Row: type icon · title · type label · timestamp · overflow menu
- [ ] Swipe to delete + undo
- [ ] Bulk select + bulk delete
- [ ] Pin / favorite
- [ ] Recently Deleted (soft delete, 30-day purge)
- [ ] Restore from trash
- [ ] Export CSV · Export PDF
- [ ] Favorites: collections, folders, tags, color labels
- [ ] Empty states via `PremiumEmptyState`

---

## 10 · PHASE 8 — ANALYTICS

- [ ] `screens/qr_analytics_screen.dart`
- [ ] Today / Weekly / Monthly scan counts
- [ ] Usage graph (bar/line chart)
- [ ] Category breakdown (donut)
- [ ] Most-used QR types · Top actions
- [ ] Average scan time · Success rate · Threat count
- [ ] All computed **locally** from Hive (no tracking)

---

## 11 · PHASE 9 — SETTINGS & PRIVACY

### 9.1 Scanner settings
- [ ] Scanner sound toggle · Vibration toggle
- [ ] Auto-open links toggle (default OFF for safety)
- [ ] Auto flash · Auto focus
- [ ] Camera resolution selector
- [ ] Battery saver mode
- [ ] Developer mode (raw payload inspector)
- [ ] ♻️ Theme / accent — reuse existing appearance sheet

### 9.2 Privacy & security
- [ ] Offline-only scanning mode
- [ ] Encrypted history (`flutter_secure_storage` key → Hive cipher)
- [ ] Biometric lock (`local_auth`)
- [ ] PIN lock fallback
- [ ] Hidden / private folder
- [ ] Private mode (scan without saving)
- [ ] Auto-delete history (7/30/90 days)
- [ ] Permissions screen + "clear all data"
- [ ] Write privacy policy copy ("no tracking, nothing leaves device unless…")

---

## 12 · PHASE 10 — CLOUD SYNC 🔑

> All of these need OAuth apps registered — blocked until you provide credentials.

- [ ] 🔑 Farvixo Cloud (Supabase — already wired, likely easiest first)
- [ ] 🔑 Google Drive backup
- [ ] 🔑 OneDrive backup
- [ ] 🔑 Dropbox backup
- [ ] Auto-sync toggle + conflict resolution
- [ ] Restore backup flow
- [ ] Cross-device sync + encryption at rest

---

## 13 · PHASE 11 — HOME-SCREEN WIDGETS 🔑

> Not pure Flutter — needs native Android App Widget + iOS WidgetKit code.

- [ ] 🔑 Android: Glance / App Widget provider
- [ ] 🔑 iOS: WidgetKit extension
- [ ] Quick Scan widget (deep link straight to camera)
- [ ] Recent Scan widget
- [ ] Generate QR widget
- [ ] Flash toggle widget
- [ ] History widget

---

## 14 · PHASE 12 — PREMIUM GATING

- [ ] Define free limits (e.g. 50 scans/day, 10 generates/day)
- [ ] Gate: unlimited scan / generate
- [ ] Gate: AI security scan
- [ ] Gate: cloud sync
- [ ] Gate: gradient + logo QR
- [ ] Gate: batch scanner / generator
- [ ] Gate: PDF export · priority AI
- [ ] Premium upsell sheet (reuse Pro banner styling)
- [ ] ⚠️ Do **not** gate basic safety warnings — security should be free

---

## 15 · PHASE 13 — PERFORMANCE

- [ ] `RepaintBoundary` around laser + animated overlay
- [ ] Throttle detection callbacks (avoid rebuild storm)
- [ ] Dispose camera controller correctly on route change
- [ ] Lazy-load history (paginated Hive reads)
- [ ] Compress imported gallery images before decode
- [ ] Cache security verdicts
- [ ] Profile with DevTools → verify 60/120fps, no jank
- [ ] Measure battery drain over 10 min continuous scan
- [ ] Memory-leak check (open/close scanner 50×)

---

## 16 · PHASE 14 — ACCESSIBILITY

- [ ] `Semantics` labels on every control (torch, gallery, zoom, capture)
- [ ] Screen-reader announcement on successful scan + result type
- [ ] Large-text support — verify no overflow at 200% text scale
- [ ] High-contrast mode
- [ ] Color-blind safe risk indicators (icon + text, never color alone)
- [ ] Haptic feedback for scan success/failure
- [ ] Full keyboard/focus traversal on tablet & desktop
- [ ] Minimum 48dp touch targets

---

## 17 · PHASE 15 — RESPONSIVE & PLATFORMS

- [ ] Phone portrait (primary)
- [ ] Landscape layout (controls move to side rail)
- [ ] Tablet — two-pane (camera + live history)
- [ ] Foldable — hinge-aware layout
- [ ] Desktop — webcam or file-drop decode
- [ ] Web — `getUserMedia` fallback + graceful "not supported"
- [ ] Dark / light / custom accent verified on every screen
- [ ] AMOLED true-black variant

---

## 18 · PHASE 16 — TESTING & RELEASE

- [ ] Unit tests: all parsers, security heuristics, risk scoring
- [ ] Widget tests: scanner overlay, result screen, history filters
- [ ] Golden tests: result screen in dark/light/custom
- [ ] Integration test: scan → result → action → history
- [ ] Test on low-end Android (camera start time, fps)
- [ ] Test permission denial + airplane mode + no camera
- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] Release builds: apk · appbundle · ios
- [ ] Store assets: screenshots, feature graphic, privacy disclosure
- [ ] Data-safety form (declare camera use, no data collection)

---

## 19 · SUGGESTED BUILD ORDER (fastest path to usable)

1. **Phase 1** foundation + permissions
2. **Phase 2** camera + overlay → *first visible win*
3. **Phase 3** parsers
4. **Phase 4** result screen + actions → *module is now genuinely useful*
5. **Phase 7** history (Hive)
6. **Phase 5.1** offline security heuristics
7. **Phase 6** generator
8. **Phase 9** settings & privacy
9. Then: analytics → premium gating → performance → a11y → responsive
10. Last: cloud sync 🔑, widgets 🔑, online reputation 🔑 (all key-blocked)

---

## 20 · OPEN BLOCKERS SUMMARY

| Item | Needs |
|---|---|
| Google Safe Browsing | API key |
| VirusTotal reputation | API key |
| AI threat summary | LLM endpoint/key |
| Google Drive / OneDrive / Dropbox | OAuth client registration |
| Home-screen widgets | Native Android + iOS code |
| Material You dynamic color | `dynamic_color` pkg + Android 12+ device to verify |

---

*Generated for the Farvixo Flutter project. Reuses existing design tokens,
premium UI kit, Riverpod providers and go_router — no parallel design system.*
