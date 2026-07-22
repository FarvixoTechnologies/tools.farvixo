# Farvixo — Per-Category Color Identity

**Source of truth:** `lib/theme/app_colors.dart` (raw tokens) → `lib/theme/category_colors.dart` (composed identities)

Every tool category owns a distinct visual identity. Screens never read a raw
`Color`; they resolve a `CategoryIdentity` and ask it for the role they need.

---

## Usage

```dart
final id = CategoryColors.of(tool.categoryId);

Container(
  decoration: BoxDecoration(
    gradient: id.surfaceGradient(context),   // translucent card wash
    border: Border.all(color: id.border(context)),
    boxShadow: id.glow(context),             // colored ambient glow
  ),
  child: Icon(tool.icon, color: id.accentOf(context)),
);
```

Shorthands:

```dart
context.categoryColor('pdf');       // Color
context.categoryIdentity('pdf');    // CategoryIdentity
tool.identity;                      // from a Tool
category.identity;                  // from a ToolCategory
```

### Roles on `CategoryIdentity`

| Role | Purpose |
|---|---|
| `accentOf(context)` / `ink(context)` | Icons, labels, active states |
| `tint(context)` | Icon chips, badges, pills (low alpha) |
| `wash(context)` | Large section / hero backgrounds (lowest alpha) |
| `border(context)` | Hairline category-owned outlines |
| `gradient(context)` | Solid CTA / hero / progress fills |
| `surfaceGradient(context)` | Translucent card + panel backgrounds |
| `glow(context, strength:)` | Ambient colored shadow (FAB, hero icon) |
| `cardShadow(context)` | Cheap resting shadow for grid tiles |
| `onGradient(context)` | Foreground guaranteed readable on `gradient` |

Each identity carries four stops: `dark` (base, tuned for dark surfaces),
`light` (AA-safe twin for light surfaces), `deep` (gradient end / pressed) and
`companion` (second gradient stop, unique per category).

---

## The ramp

### Core 8 — shipped catalog

| Category | Identity | Dark | Light | Deep |
|---|---|---|---|---|
| `pdf` | Crimson | `#EF4444` | `#DC2626` | `#B91C1C` |
| `image` | Emerald | `#10B981` | `#059669` | `#047857` |
| `video` | Amethyst | `#A855F7` | `#9333EA` | `#7E22CE` |
| `audio` | Ember | `#F97316` | `#EA580C` | `#C2410C` |
| `ai` | Fuchsia | `#D946EF` | `#C026D3` | `#A21CAF` |
| `dev` | Azure | `#3B82F6` | `#2563EB` | `#1D4ED8` |
| `text` | Cyan | `#06B6D4` | `#0891B2` | `#0E7490` |
| `utility` | Graphite | `#64748B` | `#475569` | `#334155` |

### Extended set — pending / future categories

| Category | Identity | Dark | Light | Deep |
|---|---|---|---|---|
| `ocr` | Teal | `#5EEAD4` | `#115E59` | `#134E4A` |
| `qr` | Indigo | `#6366F1` | `#4F46E5` | `#4338CA` |
| `scanner` | Sky | `#7DD3FC` | `#0C4A6E` | `#082F49` |
| `security` | Rose | `#FDA4AF` | `#9F1239` | `#881337` |
| `finance` | Jade | `#22C55E` | `#16A34A` | `#15803D` |
| `business` | Gold | `#FCD34D` | `#B45309` | `#92400E` |
| `government` | Bronze | `#D6B25E` | `#8A6A16` | `#6B5210` |
| `converter` | Lime | `#84CC16` | `#4D7C0F` | `#3F6212` |
| `calculator` | Violet | `#C4B5FD` | `#5B21B6` | `#4C1D95` |
| `notes` | Blossom | `#EC4899` | `#DB2777` | `#BE185D` |
| `cloud` | Stone | `#A8A29E` | `#57534E` | `#44403C` |

### Component identity (not a category)

| Component | Identity | Dark | Light | Deep | Companion |
|---|---|---|---|---|---|
| `upload` | Lightning | `#38BDF8` | `#0369A1` | `#075985` | `#FFA31A` |

Deliberately excluded from the fallback wheel so it is never auto-assigned to a
backend category slug.

---

## Why two axes, not one hue wheel

Nineteen categories cannot be spaced on a single 360° hue wheel while keeping
semantic meaning (finance must read green, security must read red-family, PDF
must stay crimson). Forcing it produces a green "Government" and a blue
"Business" — technically separated, semantically wrong.

So the system separates on **hue family + lightness tier**. Where an extended
category shares a hue family with a core one, it takes a clearly different
lightness:

- `security` is the **light-tier rose** sibling of `pdf`'s crimson
- `scanner` is the **light-tier sky** sibling of `text`'s cyan
- `ocr` is the **light-tier teal** sibling of `image`'s emerald
- `calculator` is the **light-tier violet** sibling of `video`'s amethyst
- `government` is **low-saturation bronze** against `business`'s saturated gold
- `cloud` is **low-saturation warm stone** against `utility`'s cool slate

## Verified guarantees

Checked programmatically across all 19 categories in both themes:

- **Contrast** — every accent clears **3:1** (WCAG AA for UI components /
  large text) against its own surface. Worst case: `3.91:1` dark, `3.30:1` light.
- **Distinguishability** — zero confusable pairs. No two categories are within
  14° hue *and* 0.12 lightness *and* 0.30 saturation of each other, in either theme.

Re-run the audit after any token change:

```bash
python3 tool/audit_category_colors.py    # see TODO roadmap, Phase 0
```

---

## Unknown categories

`CategoryColors.of()` never returns null and never falls back to grey:

1. Direct registry hit on the slug
2. Alias table (`accent-pdf`, `documents`, `music`, `code`, `gov`, `math`, …)
3. Deterministic FNV-1a hash → fixed slot on a 10-identity wheel

A backend-added category therefore gets a stable, distinct color on first
render with no client release required.

## Rules

- **Never** hardcode a hex or `Color(0x…)` in a widget.
- **Never** read `AppColors.accentX` directly in feature code — go through
  `CategoryColors`. The raw tokens are not brightness-aware.
- `ToolCategory.color` is the **legacy flat base**, kept for API compatibility.
  Prefer `ToolCategory.identity`.
