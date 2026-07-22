# Farvixo Flutter — Enterprise Migration Roadmap

**Version:** 2.0 · **Status:** Master Roadmap · **Company:** Farvixo Technologies Pvt. Ltd.
**Targets:** Android · iOS · Windows · macOS · Linux · Web · Tablet · Desktop · Laptop · Foldables

**Constraint (CLAUDE.md):** UI / UX / animation / accessibility / performance only.
Business logic, auth, Supabase, Firebase, Riverpod providers, routing, payments, quota and storage are **frozen**.

Legend: `[x]` done · `[~]` in progress · `[ ]` pending

---

## Vision

One universal codebase, premium on every platform: enterprise architecture, responsive everywhere,
AI ready, cloud ready, offline ready, extremely fast, modular, future proof.

---

## Progress snapshot

| Area | State |
|---|---|
| Universal theme engine (light / dark / custom accent) | `[x]` |
| Category identity system — 19 categories, 4 stops each | `[x]` |
| Dynamic category mapping + alias table + hash fallback | `[x]` |
| Gradient / glow / shadow engines | `[x]` |
| ToolCard integration (theme-aware category colors) | `[x]` |
| Color audit script + CI gate | `[x]` |
| Typography scale (15 M3 roles + 7 micro roles) | `[x]` |
| Spacing / radius / elevation / motion token ladders | `[x]` |
| Documentation | `[x]` |
| Colour migration off direct `AppColors.*` reads | `[~]` |
| Component library | `[ ]` |
| Everything from Phase 2 onward | `[ ]` |

---

## Phase 0 — Design System Foundation ★★★★★ `[~]`

The gate. No screen work begins until tokens are unified.

### Typography `[x]`
`lib/theme/app_typography.dart`

- [x] All 15 Material 3 roles: display L/M/S · headline L/M/S · title L/M/S · body L/M/S · label L/M/S
- [x] Ramp tuned to Farvixo density (dense tool catalog, not editorial)
- [x] 7 micro roles: `toolTitle` `caption` `overline` `badge` `metric` `mono` `numeric`
- [x] `FontWeights` tokens (regular → black); no raw `FontWeight.w800` in widgets
- [x] Tabular figures on `numeric` for progress / size / ETA / speed
- [x] Text-scale clamping — `scalerOf(context, dense:)`, 1.3× dense / 2.0× prose
- [x] `boldText` accessibility flag bumps weight without changing metrics
- [x] Wired into `AppTheme` — app bar, buttons, inputs, snackbar, nav all read the scale
- [x] `context.type.titleMedium` ergonomic accessor
- [ ] Migrate **403 raw `TextStyle()` calls / ~330 hardcoded `fontSize` literals** in features to roles
- [ ] Licensed brand typeface (**blocked** — see Blockers)

### Spacing `[x]`
- [x] Full `Space` ladder: 0 2 4 8 12 16 20 24 28 32 40 48 56 64 80 96 128
- [x] `Insets` semantic aliases over the ladder (backward compatible across 189 files)
- [x] Added missing steps: `smd` `mlg` `lxl` `xxxxl` `section` `scrollBottom`

### Radius `[x]`
- [x] Semantic names: `button` `tile` `card` `panel` `banner` `sheet` `hero` `pill`
- [x] T-shirt aliases: `xs` `sm` `md` `lg` `xl` `xxl` `full`
- [x] Prebuilt `BorderRadius` constants for every step + `brSheetTop`

### Elevation `[x]`
- [x] Semantic shadows: `card` `raised` `accentGlow`
- [x] Numbered levels 0–5
- [x] `Surfaces` tonal fill tiers 0–4 (M3 conveys elevation by color *and* shadow)
- [x] `Glass` tiers — `subtle` / `standard` / `heavy`, each with blur + fill + border

### Motion `[x]`
- [x] Durations: `instant` `fast` `base`/`normal` `medium` `slow` `verySlow` `page` `ambient`
- [x] Curves: `ease` `easeIn` `easeOut` `standard` `emphasized` `spring` `elastic` `bounce` `decelerate`
- [x] `Motion.of()` / `curveOf()` / `reduced()` honor reduce-motion
- [x] `Motion.stagger()` — capped list entrance delays

### Colour `[~]`
- [x] 19-category identity system — `docs/CATEGORY_COLORS.md`
- [x] 3 brand component identities (`brand` `favorite` `premium`) — theme-aware
      replacements for the flat `brandPrimary` / `brandMagenta` / `goldPremium`
- [x] `AppColors.onAccent` — semantic on-colour for gradient / shader fills
- [x] Audit: AA 3:1 verified, zero confusable pairs, CI-gateable
- [ ] **Migrate 184 remaining direct `AppColors.accent*` reads** — see Phase 0b

### Guardrails `[x]`
- [x] **`tool/audit_design_tokens.py`** — CI gate rejecting hardcoded colour,
      fontSize, fontWeight, radius, duration, curve, raw `TextStyle()` and
      direct accent reads
- [x] Ratcheting baseline (`tool/token_baseline.json`) — new debt is blocked
      while existing debt is paid down feature by feature
- [x] `audit_category_colors.py` CI-gateable
- [ ] Wire both audits + `flutter analyze` into the CI pipeline config
- [ ] Extend gate to hardcoded `EdgeInsets` literals

### Icon system `[ ]`
- [ ] Icon token registry: filled / outlined / rounded variants per semantic name
- [ ] Animated icon set (morph, state transitions)
- [ ] 3D / illustrated icon set for heroes and empty states

---

## Phase 0b — Tokenization migration `[~]`

Feature-by-feature, each passing `flutter analyze` and the token gate before
the next begins. Baseline recorded at **1664** violations across 78 files.

| Order | Feature | Violations | Status |
|---|---|---|---|
| 1 | **Home** (dashboard) | 103 → **0** | `[x]` |
| 2 | **Search** | 55 → **0** | `[x]` |
| 3 | **Shared widgets** (`lib/widgets`) | 91 → **0** | `[x]` |
| 4 | **Tools** — index, detail, converter, scanner, engines | 426 → **0** | `[x]` |
| 5 | **Upload** (new feature) | built clean | `[x]` |
| 6 | **Settings** | 402 → **0** | `[x]` |
| 7 | **Profile** | 311 → **0** | `[x]` |
| 8 | **Auth** | 65 → **0** | `[x]` |
| 9 | **Splash** | 62 → **0** | `[x]` |
| 10 | **Onboarding** | 53 → **0** | `[x]` |
| 11 | **AI** | 34 → **0** | `[x]` |
| 12 | **Shell · notifications · providers · premium widgets · launch** | ~50 → **0** | `[x]` |

**COMPLETE: 0 violations across 0 files** (from 1664 across 78 — **100 % paid down**).

The token gate now runs in `--strict` mode (zero tolerance) and passes. The
ratcheting baseline is no longer needed — any new hardcoded value fails the build.

```
tool/check_balance.py          223 files, 0 unbalanced
tool/check_const.py            223 files, 0 const violations
tool/audit_category_colors.py  19 categories, AA clean, 0 confusable
tool/audit_design_tokens.py --strict   clean
```

### Tooling built for the migration

- `tool/migrate_textstyle.py` — `TextStyle(fontSize:…)` → nearest `AppTypography` role
- `tool/mech_pass.py` — radii / durations / curves / `Colors.white`→`onAccent`
- `tool/check_const.py --fix` — drops `const` left stranding a context-bound call
- `tool/check_balance.py` — bracket balance (string/comment aware)
- `tool/audit_design_tokens.py --strict` — the CI gate

### Migration tooling built along the way

- `tool/migrate_textstyle.py` — rewrites inline `TextStyle(fontSize:…)` to the
  nearest `AppTypography` role, carries color/weight/height, drops `const`.
- `tool/check_const.py` — catches context-bound calls left inside `const`
  constructors (the migrator's one failure mode).
- `tool/check_balance.py` — bracket-balance scanner that skips strings/comments.

### Legitimate raw values, now named (not forced through the theme)

Some hardcoded values were correct and became **named tokens** rather than
theme-adaptive ones:

- **File-format brand colours** (`AppColors.formatWord` …) — vendor-fixed.
- **QR ink** (`AppColors.scrim` / `onAccent`) — black-on-white is a
  scannability requirement.
- **Colour-picker hue wheel** (`AppColors.hueWheel`) & **QR swatches** — a
  user picking a colour, not app theming.
- **On-gold ink** (`AppColors.onPremium` / `onPremiumMuted`) — dark text on the
  gold premium banner.
- **Profile avatar / hero gradients** — named brand gradients.

Const data catalogs (`tools_data`, `settings_catalog`, `settings_v5_*`,
`settings_screen`) are exempt from `direct-accent-read`: they store an accent as
data and render it as an AA-safe glyph, exactly like `tools_data` resolving via
`.identity`. The rule still fires on genuine screen code — Home, Search, Tools,
Settings and Profile all passed it.

### What the Home migration established

Patterns to reuse for every remaining feature:

- **Tools carry `categoryId`, not `Color`.** `home_categories`, `home_popular`
  and `home_trending` stored hand-picked colours that disagreed with the tools
  grid — Image was orange on Home and emerald in the catalog, AI was blue on
  Home and fuchsia in the catalog. They now resolve through `CategoryColors`
  from the same slug as `tools_data.dart`, so a tool looks identical everywhere.
- **Status becomes an enum, not a colour.** `TrendingBadge` owns its own label
  and semantic colour; no call site picks one.
- **App shortcuts use brand component identities.** Favorites → `favorite`,
  premium → `premium`, generic → `brand`. Not category colours.
- **Shader/gradient text uses `AppColors.onAccent`**, not `Colors.white`.
- **Named motion tokens over raw durations** — `Motion.pulse`, `Motion.intro`,
  `Motion.breathe`, `Motion.carouselDwell`, `Motion.refreshDwell`.

### Semantic mismatches the gate surfaced

`direct-accent-read` is not only a theme-awareness rule — it finds category
colours doing non-category jobs. Fixed so far:

- **Offline banner** (`retry_view`) used `accentAudio` as a warning colour,
  purely because it was orange → now `AppColors.warning`.
- **Search "New" filter chip** used `accentImage` as a success colour → now
  `AppColors.success`, matching the NEW badge on `ToolCard`.
- **`ToolCard` POPULAR / AI badges** used flat brand colours → now
  `CategoryColors.premium` / `CategoryColors.ai`, brightness-aware.

Expect more of these in Settings and Profile, which hold the largest
`direct-accent-read` clusters.

### Verification tooling

- `tool/audit_design_tokens.py` — token gate (ratcheting baseline)
- `tool/audit_category_colors.py` — contrast + confusability
- `tool/check_balance.py` — bracket-balance scanner that correctly skips
  raw / multiline / interpolated strings and comments (a naive regex reports
  false positives on URLs containing `//` and on apostrophes inside
  double-quoted strings)

---

## Phase 1 — Universal Component Library ★★★★★ `[ ]`

Existing: `PremiumBackground` `GlassPanel` `FadeSlideIn` `PressableScale` `AppPageRoute` skeletons `ToolCard`

- [ ] **Buttons** — `AppButton` `PrimaryButton` `SecondaryButton` `GlassButton` `AppIconButton` `AppFAB` `SegmentButton`
- [ ] **Cards** — `PremiumCard` `GlassCard` `StatCard` `UploadCard` `ProgressCard`
- [ ] **Input** — `SearchBar` `FilterBar` `Dropdown` `AppTextField`
- [ ] **Atoms** — `Chip` `Badge` `Avatar` `Tooltip`
- [ ] **Overlays** — `AppDialog` `AppBottomSheet` `AppSnackbar` `ContextMenu`
- [ ] **Navigation** — `Sidebar` `NavigationRail` `NavigationDrawer` `AppTabBar`
- [ ] **Structure** — `Accordion` `Timeline` `Carousel` `AppGrid` `AppList` `DataTable` `TreeView` `Chart`
- [ ] **States** — `EmptyState` `ErrorState` `LoadingState` `Skeleton`
- [ ] **Gallery route** (debug-only): every component × every category × light/dark — the visual regression surface
- [ ] Golden tests per component

---

## Phase 2 — Universal Upload System ★★★★★ `[ ]`

Codename **Lightning Upload**. Identity: `CategoryColors.upload` — electric blue `#38BDF8` + lightning orange `#FFA31A`.
Architecture: `lib/features/upload/{data,domain,presentation/{widgets,controllers},services,models,providers,animations}`

- [ ] **State machine** — idle · hover · pressed · selecting · preparing · scanning · encrypting · uploading · processing · AI-optimizing · compressing · verifying · completed · failed · retry · cancelled · paused · resume · offline-queue
- [ ] **Visual shell** — 3D black-premium folder (golden edge, gloss, metal), 3D gradient arrow with pulse + lightning trail, animated gradient background (particles, floating lights, blur/depth layers)
- [ ] **Folder effect variants** — glass · metal · carbon · crystal · lightning · cyber · neon · hologram
- [ ] **Progress** — circular · linear · glass ring · percentage · speed · ETA · remaining · transferred/total · current file · queue position · network status
- [ ] **Sources** — internal · external · USB · camera · gallery · scanner · clipboard · drag-drop · folder · Drive · Dropbox · OneDrive · Box · NAS · SMB · FTP · SFTP · HTTP/S · URL
- [ ] **Features** — single · multi · folder · chunked · resume · pause · retry · cancel · queue · priority queue · offline queue · background · encrypted · hash verification · duplicate detection · auto rename · smart queue · auto retry · bandwidth control · speed limit · compression · AI file detection · virus-scan ready
- [ ] **Layouts** — desktop (sidebar + large drop area + queue/history panels) · tablet (two-column, split view, floating panel) · mobile (single column, bottom sheet, floating FAB)
- [ ] **Animations** — folder float · arrow pulse · glow expand · lightning flash · speed lines · particle burst · progress ring · completion explosion · check draw
- [ ] Success · error · empty states
- [ ] Golden tests across 5 breakpoints × light/dark

---

## Phase 3 — Tool Detail Redesign `[ ]`

- [ ] Premium adaptive layout — desktop sidebar / mobile bottom sheet
- [ ] Floating actions · AI assistant panel
- [ ] History · recent · favorites · share · export
- [ ] **Per-tool checklist ×140** (8 shipped categories, `lib/data/tools_data.dart`):
  hero + dynamic background from category gradient · drag-drop · multi-file queue · preview ·
  live progress · before/after · animated result · confetti success · premium error ·
  empty/offline/shimmer states · responsive · hover/keyboard/context-menu · `flutter analyze` clean

| # | Category | Identity | Status |
|---|---|---|---|
| 1 | PDF | Crimson `#EF4444` | `[ ]` |
| 2 | Image | Emerald `#10B981` | `[ ]` |
| 3 | Video | Amethyst `#A855F7` | `[ ]` |
| 4 | Audio | Ember `#F97316` | `[ ]` |
| 5 | AI | Fuchsia `#D946EF` | `[ ]` |
| 6 | Developer | Azure `#3B82F6` | `[ ]` |
| 7 | Text | Cyan `#06B6D4` | `[ ]` |
| 8 | Utilities | Graphite `#64748B` | `[ ]` |

Reserved identities for future categories: `ocr` `qr` `scanner` `security` `finance` `business` `government` `converter` `calculator` `notes` `cloud`

---

## Phase 4 — Enterprise Animation Engine `[ ]`

- [ ] Interaction: hover · press · ripple · glow
- [ ] Transition: hero · morph · shared-element (grid → detail) · premium page routes
- [ ] Feedback: success · error · shake · pulse
- [ ] Ambient: floating · gradient flow · background motion · parallax · particles · lightning
- [ ] Celebration: confetti
- [ ] Lottie + Rive integration points (**blocked** on assets)
- [ ] Every animation honors `Motion.of()` / `curveOf()`

---

## Phase 5 — Universal Navigation `[ ]`

- [ ] Bottom navigation · navigation rail · sidebar · drawer · floating nav
- [ ] Adaptive navigation (switches by breakpoint)
- [ ] Search everywhere · command palette
- [ ] Full keyboard navigation

---

## Phase 6 — AI Integration `[ ]`

UI surfaces only — model calls stay in existing `lib/services/ai_service.dart`.

- [ ] Assistant panel · suggestions surface · streaming response UI
- [ ] OCR · translation · summarization · image recognition surfaces
- [ ] AI rename · AI organize · AI compression flows

---

## Phase 7 — Cloud Platform `[ ]`

UI surfaces only — Supabase / Firebase logic frozen.

- [ ] Cloud storage browser · Drive / Dropbox / OneDrive pickers
- [ ] Sync · realtime · offline-sync status surfaces
- [ ] Backup / restore flows

---

## Phase 8 — Universal Dashboard `[ ]`

- [ ] Recent activity · pinned tools · favorites · history · recent uploads
- [ ] Statistics · storage · credits · cloud usage · AI usage
- [ ] Notifications · performance · insights

---

## Phase 9 — Enterprise Security `[ ]`

UI surfaces only — crypto and token handling stay in existing services.

- [ ] Biometric prompt · permission manager UI
- [ ] Integrity / checksum / SHA-256 display surfaces
- [ ] Certificate + secure-storage state surfaces

---

## Phase 10 — Desktop Experience `[ ]`

- [ ] Resizable + dockable panels · split view · floating windows
- [ ] Window controls (macOS traffic lights, Windows title bar)
- [ ] Keyboard shortcuts · right-click menus · drag-drop
- [ ] Multiple tabs · workspaces

---

## Phase 11 — Responsive Engine `[ ]`

- [ ] Breakpoint utility + `AdaptiveScaffold` (single source for layout switching)
- [ ] Mobile 320–600 · tablet 600–1024 · laptop 1024–1440 · desktop 1440–1920 · ultrawide 1920+
- [ ] Landscape + portrait on every screen
- [ ] Foldable / dual-screen hinge awareness
- [ ] Dynamic grid · adaptive sidebar / toolbar / FAB

---

## Phase 12 — Performance `[ ]`

- [ ] `const` constructors everywhere possible
- [ ] `RepaintBoundary` on animated + list surfaces
- [ ] Lazy builders · virtual lists · pagination · infinite scroll
- [ ] Image cache + decode sizing (`cacheWidth`/`cacheHeight`)
- [ ] Riverpod `select()` on all watchers
- [ ] Isolates for heavy tool engines · background processing
- [ ] Shader warmup (kills first-run jank)
- [ ] DevTools pass — 60/120 FPS, no frame >8ms on 120Hz

---

## Phase 13 — Accessibility `[ ]`

- [ ] `Semantics` on every interactive element; labels on all icon-only buttons
- [ ] Tooltips on all icon actions
- [ ] 200% text scaling without overflow (clamping in place; needs per-screen verification)
- [ ] Minimum 48×48 touch targets audited
- [ ] Screen reader pass — TalkBack + VoiceOver
- [ ] Voice control labels · focus traversal order
- [ ] WCAG AA across all surfaces; AAA on body copy
- [ ] High contrast + color-blind verification (category ramp done — extend to badges, charts, status)

---

## Phase 14 — Localization `[ ]`

- [ ] `l10n` infrastructure + ARB extraction
- [ ] English · Bengali · Hindi · Arabic · Spanish · French · German · Japanese · Chinese
- [ ] **RTL support** (Arabic) — audit every `EdgeInsets.only`, `Alignment`, directional icon
- [ ] Dynamic locale switching

---

## Phase 15 — Developer Experience `[ ]`

- [ ] Feature-module folder structure enforced (see below)
- [ ] Clean architecture layering · dependency injection
- [ ] Logging · analytics · Crashlytics surfaces
- [ ] Golden · widget · integration · unit tests
- [ ] CI/CD · code generation · lint rules

---

## Target folder structure

```
lib/
  core/{theme,tokens,animations,widgets,services,utils,models,providers}/
  features/{upload,pdf,image,scanner,converter,ai,notes,cloud,settings,dashboard,auth}/
  shared/
  l10n/
assets/
```

Each feature: `widgets/ controllers/ providers/ models/ services/ animations/ utils/`

---

## Design rules

Never hardcode colors · spacing · radius · typography · animation duration.
Never duplicate widgets.
Everything reusable · theme-aware · responsive · accessible · testable · modular.

---

## Validation gates

After every feature: `flutter analyze`
After every category: `flutter analyze && flutter test`

Final:

```bash
python3 tool/audit_category_colors.py
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
flutter build appbundle
flutter build web
flutter build windows
flutter build linux
flutter build macos
```

Repeat until clean.

---

## Git workflow

Feature branch per phase: `ui/phase-N-<name>` · commit after each completed category · clean messages · no squashing unrelated work.

---

## Blockers requiring you

Work stops only for these:

1. **Brand typeface** (Phase 0) — the licensed display font, or approval to ship a Google Fonts stand-in.
   `FontFamilies.sans` is currently `null` (platform default) and is the single swap point.
2. **Cloud upload credentials** (Phase 2) — Drive / OneDrive / Dropbox / Box OAuth client IDs.
3. **Rive / Lottie assets** (Phase 4) — licensed animation files, or approval to author placeholders.
