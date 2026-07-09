# Farvixo Tools — Homepage Master Build Specification
### (Matches uploaded mockup 100% — Full Detail Edition)

**Project:** Farvixo Tools
**Company:** Farvixo Technologies · **Owner:** Faruk Mondal
**Production URL:** https://tools.farvixo.com
**Dev URL:** https://farvixo.vercel.app
**Tagline:** "Build Beyond."
**Theme:** Deep-space dark, Violet primary, Gold premium accents, category accent colors

---

## 1. Global Design Tokens

### 1.1 Color System
| Token | Hex (approx) | Usage |
|---|---|---|
| `--bg-base` | #0A0A12 | Page background (deep space navy-black) |
| `--bg-surface` | #12121C | Cards, panels |
| `--bg-surface-2` | #1A1A28 | Nested cards, hover states |
| `--border-subtle` | #2A2A3C | Card borders, dividers |
| `--brand-primary` | #7C3AED | Violet — primary buttons, links, active states |
| `--brand-primary-hover` | #8B5CF6 | Hover state |
| `--brand-gradient` | linear-gradient(135deg, #7C3AED, #C026D3) | Hero gradient text, hero cube |
| `--gold-premium` | #F5B93D | Crown icon, Upgrade to Pro, PRO badge |
| `--text-primary` | #F5F5FA | Headings |
| `--text-secondary` | #A0A0B8 | Body/subtext |
| `--text-muted` | #6B6B85 | Captions, meta |
| `--success-green` | #22C55E | Uptime stat, checkmarks |
| `--accent-pdf` | #EF4444 (red) | PDF category icons |
| `--accent-image` | #22C55E (green) | Image category icons |
| `--accent-video` | #A855F7 (purple) | Video category icons |
| `--accent-audio` | #F97316 (orange) | Audio category icons |
| `--accent-ai` | #C026D3 (magenta/violet) | AI category icons + "AI"/"NEW" badges |
| `--accent-dev` | #3B82F6 (blue) | Developer/Watermark tool icons |

### 1.2 Typography
- **Display/Headings:** Sora or Cabinet Grotesk, weights 600–800
- **Body:** Inter, 400–500
- **Data/Mono (code, hashes, JSON):** JetBrains Mono
- H1 (hero): 48–56px desktop / 32px mobile, tight line-height 1.1
- Body: 16px desktop / 15px mobile

### 1.3 Effects
- Glassmorphism cards: `background: rgba(26,26,40,0.6); backdrop-filter: blur(12px); border: 1px solid rgba(255,255,255,0.06)`
- Soft shadow: `0 8px 32px rgba(124,58,237,0.15)` on hover for tool cards
- Rounded corners: 12px cards, 8px buttons, full-round pills for badges
- All interactive elements: Framer Motion `whileHover={{ scale: 1.02 }}`, `whileTap={{ scale: 0.98 }}`

### 1.4 Performance Targets
- Lighthouse Mobile ≥ 90
- LCP < 2.0s
- Hero cube/graphic lazy-loaded, SVG/CSS-based (not heavy 3D lib) or deferred Three.js chunk
- Tool grid images/icons as inline SVG sprite, no per-icon network request

---

## 2. Header (Sticky, Full Width)

**Layout:** `Logo | Nav Links | Search | AI Assistant | Utilities`

- **Logo block (left):** Purple hexagon glyph icon + "Farvixo Tools" wordmark (bold, white) + micro-tagline "Build Beyond." beneath in muted gray, small caps.
- **Primary Nav (row 2, full width, sticky under header):**
  Home · All Tools · AI Tools `[NEW badge, violet pill]` · PDF · Image · Video · Audio · Developer · Text · SEO · Business · Converter · Utilities · More `[chevron dropdown]`
- **Top-right controls:**
  1. "All Categories" dropdown selector (attached to search bar, left side)
  2. Global search input — placeholder: *"Search any tool... (PDF to Word, Image Compressor, etc.)"* with `⌘K` keyboard-shortcut hint pinned right inside input
  3. **AI Assistant** button — violet filled, sparkle icon, label "AI Assistant"
  4. Language selector — globe icon + "English" + chevron
  5. Theme toggle — sun/moon icon
  6. Notification bell — red badge counter
  7. User avatar (circular photo) + name "Faruk Mondal" + gold **PRO** badge pill underneath

---

## 3. Hero Section

**Grid:** 2-column desktop (60/40), stacks on mobile

### 3.1 Left Column
1. Eyebrow badge: ✨ "Smart Tools Ecosystem" (violet outline pill, small sparkle icon)
2. H1 (3 lines):
   - "One Platform." (white)
   - "Infinite Tools." (white)
   - "Powered by AI." (gradient violet→magenta text)
3. Subtext: "Everything you need to work faster, smarter and better — all in one place." (gray, max-width ~480px)
4. Hero search bar: rounded pill input, placeholder "Search any tool or type your task...", trailing violet search button (magnifying glass icon)
5. Quick-suggestion chips (below search): `PDF to Word` `Image Compressor` `Background Remover` `AI Chat` `Video Converter` — small rounded gray pills, hover → violet border
6. CTA row:
   - Primary button: "Explore All Tools →" (solid violet, white text)
   - Secondary button: "✨ Try AI Assistant" (outline violet, transparent bg)
7. Social proof row: 4–5 overlapping circular user avatars + 5 gold stars + "Trusted by 25M+ users worldwide" (gray text)

### 3.2 Center — Hero Visual
- Large rotating 3D-style hexagonal/cube graphic in violet-to-cyan gradient with glowing ring beneath (CSS radial-gradient glow)
- 7 floating category icon chips orbiting the cube (staggered Framer Motion float animation, y-axis bob ±8px, 3–4s loop, different delay each):
  - 🖼 Image (green square)
  - 🤖 AI/Robot (violet square)
  - 📄 PDF (red square)
  - `</>` Code (violet outline square)
  - ▶ Video (blue square)
  - 🎵 Music (orange square)
  - T Text (blue square)

### 3.3 Right Column — "Why Farvixo Tools?" Card
Glass card, top-right gold crown icon, heading "Why Farvixo Tools?"
Checklist (green checkmarks):
- 120+ Powerful Tools
- AI-Powered Features
- Blazing Fast Processing
- Secure & Private
- Cloud Storage (100GB)
- No Ads, Ever

CTA button: "👑 Upgrade to Pro" (gold gradient fill, dark text)
Caption beneath: "No credit card required" (muted, centered)

---

## 4. Stats Bar

Full-width strip, 6 columns, glass card background, icon above each number:

| Icon | Number | Label |
|---|---|---|
| 👥 | 25M+ | Happy Users |
| ▦ | 120+ | Powerful Tools |
| 🛡 | 99.9% | Uptime |
| ✓ | 50M+ | Tasks Completed |
| 🌐 | 150+ | Countries |
| 🔒 | 100% | Secure & Private |

---

## 5. Main Tools Explorer (Sidebar + Grid)

### 5.1 Left Sidebar — "Browse by Category"
Vertical list, icon + label + count badge (right-aligned, muted pill), active item = violet filled background:

- ▦ All Tools — `120+` *(active/selected state)*
- 📄 PDF Tools — `20+`
- 🖼 Image Tools — `25+`
- ▶ Video Tools — `20+`
- 🎵 Audio Tools — `15+`
- 🤖 AI Tools — `30+` `[NEW]`
- `</>` Developer Tools — `25+`
- T Text Tools — `15+`
- 🔍 SEO Tools — `20+`
- 💼 Business Tools — `15+`
- ⇄ Converter Tools — `20+`
- ⚙ Utilities — `20+`
- 🛡 Security Tools — `10+`
- ⚡ Productivity — `15+`
- 📁 File Tools — `15+`
- 📊 Data Tools — `15+`
- ▦ All Categories *(link to full category page)*

### 5.2 Right Panel Header
- H2: "All Tools (120+)"
- Subtext: "Discover and use powerful tools for all your needs."
- Controls row: "All Categories" dropdown · "Sort by: Popular" dropdown · Grid/List view toggle icons (grid active, violet)

### 5.3 Tool Card Grid (5 columns desktop / 2 mobile)
Each card: colored icon tile (top-left) → optional badge top-right (`NEW` teal-green pill or `AI` violet pill) → tool name (bold) → 1-line description (gray) → status tag ("Popular" small label, bottom-left) → circular arrow button (bottom-right, violet)

**Visible cards (exact set from mockup, 15 shown + Load More):**

Row 1: PDF to Word · Image Compressor · Background Remover · AI Chat Assistant `[AI]` · Merge PDF
Row 2: PDF Compressor · Image to PDF · Video Converter · Audio Converter · AI Image Generator `[NEW]`
Row 3: OCR Image · PDF to Excel · Watermark Remover · Video Compressor · AI Writer `[NEW]`

Below grid: centered "↻ Load More Tools" ghost button (loads next batch via pagination/infinite-scroll, Universal Processing Engine hook)

---

## 6. Feature Strip (5 columns)

Icon + bold label + 1-line description, centered, divider-free, glass background:

1. ⚡ **AI Powered** — Smart AI tools to boost your productivity
2. ✈ **Blazing Fast** — Lightning-fast processing for all your tasks
3. 🛡 **Secure & Private** — Your data is 100% safe and encrypted
4. ☁ **Cloud Storage** — Save and access your files anywhere
5. ⊘ **No Ads** — Pure experience, no interruptions

---

## 7. Newsletter Section

Glass rounded banner, left text block + right form + decorative violet cube graphic (far right, matches hero style, smaller):
- Envelope/bell icon
- Heading: "Stay in the Loop with **Farvixo Tools**" (brand name in violet)
- Subtext: "Get the latest tools, new features, productivity tips and exclusive content straight to your inbox."
- Email input (rounded, envelope icon prefix) + "Subscribe Now ➤" violet button
- Micro-note: "✓ No spam. Unsubscribe anytime."

---

## 8. Footer (5-Column + Brand Column = 6 Total)

### Column 1 — Brand
- Logo + "Farvixo Tools" + "Build Beyond." tagline
- Short description: "All the tools you need to work faster, smarter and better — all in one beautifully simple platform."
- Social icons row: Facebook, X (Twitter), LinkedIn, YouTube, Instagram, GitHub

### Column 2 — Explore
All Tools · AI Tools `[NEW]` · PDF Tools · Image Tools · Video Tools · Audio Tools · Developer Tools · Text Tools · Business Tools · Converter Tools

### Column 3 — Top Features
AI Assistant · Bulk Processing · Cloud Storage · File Converter · Batch Tools · Recently Added · Popular Tools · Trending Tools · Tool Collections · Keyboard Shortcuts

### Column 4 — Resources
Blog · Help Center · How It Works · Video Tutorials · API Documentation · Developer API · Status Page · Community · Changelog

### Column 5 — Company
About Us · Careers `[We're Hiring — green badge]` · Contact Us · Press Kit · Partners · Affiliate Program

### Column 6 — Get Farvixo Tools App
- Download badges: App Store · Google Play · Windows · macOS (2x2 grid, dark rounded buttons)
- "🛡 Trusted & Secure" mini-panel:
  - ✓ 256-bit SSL Encrypted
  - ✓ GDPR Compliant
  - ✓ Your Data is 100% Safe
  - ✓ No Ads, Ever

### Footer Bottom Bar
`© 2026 Farvixo Technologies. All Rights Reserved.` · `Made with ❤️ by Farvixo Team` · `Sitemap` · `Status 🟢` (live green dot indicator)

---

## 9. Universal Engines Powering the Homepage
(Shared across every tool page — build once, reuse everywhere)

- **Universal Theme Engine** — dark/light token switch, no hardcoded colors
- **Universal Search Engine** — powers header search + hero search + `⌘K` command palette
- **Universal Upload Engine** — drag/drop + click, used by every tool's own page
- **Universal Processing Engine** — job queue (BullMQ/Redis) triggered from "Load More" / tool actions
- **Universal Download Engine** — signed URL delivery, Cloudflare R2
- **Universal Authentication Engine** — Google/GitHub/Email login, JWT, powers avatar/PRO state in header
- **Universal AI Engine** — backs AI Assistant button, AI Chat, AI Writer, AI Image Generator cards
- **Universal Settings / Notification / Analytics / Billing Engines** — power bell icon, PRO badge, Upgrade to Pro flow

---

## 10. Responsive Behavior

| Breakpoint | Sidebar | Tool Grid Columns | Hero Layout |
|---|---|---|---|
| Desktop ≥1280px | Fixed left, visible | 5 | 2-col (60/40) |
| Laptop 1024–1279 | Fixed left, narrower | 4 | 2-col |
| Tablet 768–1023 | Collapsible drawer | 3 | Stacked |
| Mobile <768 | Bottom sheet / hidden behind filter button | 2 | Stacked, center-aligned text |

---

## 11. Accessibility & SEO
- WCAG AA contrast on all text vs `--bg-base`/`--bg-surface`
- All icon-only buttons have `aria-label`
- Search input has `role="search"`, `⌘K` bound via `useHotkeys`
- Semantic `<header>`, `<nav>`, `<main>`, `<aside>`, `<footer>`
- OG/meta tags per Universal SEO defaults; Schema.org `WebApplication` markup for homepage
- Category and tool cards use `<Link>` (real anchors) for crawlability, not JS-only onClick nav

---

# 12. Full Tool Catalog — 128 Tools / 15 Categories
*(Official Farvixo Tools Catalog v1.0 — Final Edition, verbatim)*

## 🏛 Government Tools (8)
1. Passport Photo Maker
2. Passport Signature Resizer
3. PAN Card Photo Resizer
4. Aadhaar Photo Resizer
5. Aadhaar PDF Compressor
6. Voter ID Photo Resizer
7. Driving Licence Photo Resizer
8. Exam Photo & Signature Resizer

## 📄 PDF Tools (12)
9. PDF Converter
10. PDF Editor
11. Merge PDF
12. Split PDF
13. Compress PDF
14. PDF OCR
15. PDF to Word
16. Word to PDF
17. PDF to Excel
18. Excel to PDF
19. Protect PDF
20. Sign PDF

## 🖼 Image Tools (12)
21. Image Converter
22. Image Compressor
23. Image Resizer
24. Crop Image
25. Rotate & Flip Image
26. Background Remover
27. Background Changer
28. AI Image Upscaler
29. AI Photo Enhancer
30. AI Object Remover
31. Image OCR
32. Watermark Image

## 🎥 Video Tools (8)
33. Video Converter
34. Video Compressor
35. Video Trimmer
36. Video Merger
37. Video Splitter
38. Video Watermark
39. Video to GIF
40. AI Subtitle Generator

## 🎵 Audio Tools (8)
41. Audio Converter
42. Audio Compressor
43. Audio Cutter
44. Audio Merger
45. Text to Speech
46. Speech to Text
47. Voice Changer
48. AI Noise Remover

## 🤖 AI Tools (12)
49. AI Chat
50. AI Writer
51. AI Image Generator
52. AI Resume Builder
53. AI Translator
54. AI Summarizer
55. AI Email Writer
56. AI SEO Writer
57. AI Code Generator
58. AI Research Assistant
59. AI Presentation Maker
60. AI PDF Assistant

## 💻 Developer Tools (8)
61. JSON Formatter
62. JSON Validator
63. Base64 Encoder & Decoder
64. URL Encoder & Decoder
65. JWT Decoder
66. UUID Generator
67. Hash Generator
68. API Tester

## 📝 Text Tools (8)
69. Case Converter
70. Word Counter
71. Character Counter
72. Text Compare
73. Remove Duplicate Lines
74. Reverse Text
75. Text Sorter
76. Lorem Ipsum Generator

## 🌐 SEO Tools (8)
77. SEO Analyzer
78. Meta Tag Generator
79. Sitemap Generator
80. Robots.txt Generator
81. Open Graph Generator
82. Schema Markup Generator
83. Keyword Density Checker
84. Canonical URL Generator

## ⚙ Utility Tools (8)
85. QR Code Generator
86. Barcode Generator
87. Password Generator
88. Password Strength Checker
89. Unit Converter
90. Currency Converter
91. Timestamp Converter
92. Random Number Generator

## 🔐 Security Tools (8)
93. MD5 Generator
94. SHA1 Generator
95. SHA256 Generator
96. SHA512 Generator
97. File Checksum Generator
98. SSL Checker
99. URL Scanner
100. Encryption Tool

## 💼 Business Tools (8)
101. Invoice Generator
102. GST Calculator
103. EMI Calculator
104. Profit Margin Calculator
105. Salary Calculator
106. Receipt Generator
107. Business Card Generator
108. Quotation Generator

## 📱 Social Media Tools (8)
109. YouTube Thumbnail Downloader
110. Instagram DP Downloader
111. Instagram Caption Generator
112. Hashtag Generator
113. YouTube Thumbnail Maker
114. YouTube Tag Generator
115. Social Media Post Generator
116. Bio Generator

## 🧮 Calculator Tools (6)
117. Age Calculator
118. BMI Calculator
119. Percentage Calculator
120. Loan EMI Calculator
121. Discount Calculator
122. Scientific Calculator

## 📦 File Converter Tools (6)
123. ZIP Creator
124. ZIP Extractor
125. CSV to Excel
126. Excel to CSV
127. XML to JSON
128. JSON to XML

---

## Category Summary Table

| Category | Tool Count |
|---|---|
| Government | 8 |
| PDF | 12 |
| Image | 12 |
| Video | 8 |
| Audio | 8 |
| AI | 12 |
| Developer | 8 |
| Text | 8 |
| SEO | 8 |
| Utility | 8 |
| Security | 8 |
| Business | 8 |
| Social Media | 8 |
| Calculator | 6 |
| File Converter | 6 |
| **Total Categories** | **15** |
| **Total Tools** | **128** |

**Status:** Final Official Farvixo Tools Tool Catalog v1.0

---

## 13. Future Expansion (Post-Launch Roadmap)
- 200+ Professional Tools
- AI Agents
- Workflow Automation
- API Platform
- Plugin Marketplace
- Mobile Apps (iOS + Android)
- Desktop Apps (Windows + macOS)
- Enterprise Features

---

## 14A. Notes on Mapping Homepage Mockup ↔ Catalog

The 15 tool cards visible on the homepage grid should map to real catalog entries, not placeholders:

| Homepage Card | Catalog Source |
|---|---|
| PDF to Word | PDF Tools #15 |
| Image Compressor | Image Tools #22 |
| Background Remover | Image Tools #26 |
| AI Chat Assistant | AI Tools #49 (AI Chat) |
| Merge PDF | PDF Tools #11 |
| PDF Compressor | PDF Tools #13 |
| Image to PDF | (new alias of PDF Converter #9, image-input mode) |
| Video Converter | Video Tools #33 |
| Audio Converter | Audio Tools #41 |
| AI Image Generator | AI Tools #51 |
| OCR Image | Image Tools #31 (Image OCR) |
| PDF to Excel | PDF Tools #17 |
| Watermark Remover | (new alias — inverse of Watermark Image #32) |
| Video Compressor | Video Tools #34 |
| AI Writer | AI Tools #50 |

"Popular" tags on the homepage should be driven by the Universal Analytics Engine (real usage ranking), not static.

---

## 14. Folder / File Architecture (Next.js 15 App Router)

```
farvixo/
├── app/
│   ├── (marketing)/
│   │   ├── page.tsx                     # Homepage
│   │   ├── layout.tsx                   # Marketing layout (header+footer)
│   │   └── loading.tsx
│   ├── (tools)/
│   │   ├── tools/
│   │   │   ├── page.tsx                 # All Tools directory
│   │   │   └── [category]/
│   │   │       ├── page.tsx             # Category listing
│   │   │       └── [tool]/
│   │   │           └── page.tsx         # Individual tool page
│   ├── (auth)/
│   │   ├── login/page.tsx
│   │   ├── signup/page.tsx
│   │   └── layout.tsx
│   ├── dashboard/
│   │   ├── page.tsx
│   │   ├── history/page.tsx
│   │   ├── billing/page.tsx
│   │   └── settings/page.tsx
│   ├── api/
│   │   ├── tools/[toolId]/route.ts
│   │   ├── ai/chat/route.ts
│   │   ├── ai/writer/route.ts
│   │   ├── upload/route.ts
│   │   ├── download/[fileId]/route.ts
│   │   ├── search/route.ts
│   │   ├── auth/[...nextauth]/route.ts
│   │   ├── billing/webhook/route.ts
│   │   └── analytics/track/route.ts
│   └── globals.css
├── components/
│   ├── layout/
│   │   ├── Header.tsx
│   │   ├── NavBar.tsx
│   │   ├── Footer.tsx
│   │   ├── Sidebar.tsx
│   │   └── MobileDrawer.tsx
│   ├── homepage/
│   │   ├── HeroSection.tsx
│   │   ├── HeroCubeGraphic.tsx
│   │   ├── StatsBar.tsx
│   │   ├── WhyFarvixoCard.tsx
│   │   ├── CategorySidebar.tsx
│   │   ├── ToolGrid.tsx
│   │   ├── ToolCard.tsx
│   │   ├── FeatureStrip.tsx
│   │   └── NewsletterSection.tsx
│   ├── search/
│   │   ├── SearchBar.tsx
│   │   ├── CommandPalette.tsx           # ⌘K modal
│   │   └── SearchResultsDropdown.tsx
│   ├── ai/
│   │   ├── AIAssistantButton.tsx
│   │   ├── AIChatPanel.tsx
│   │   └── AIStreamingResponse.tsx
│   ├── tools/
│   │   ├── ToolUploader.tsx             # Universal Upload Engine UI
│   │   ├── ToolProcessingState.tsx
│   │   ├── ToolResultDownload.tsx
│   │   └── ToolPageTemplate.tsx
│   └── ui/                               # shadcn/ui primitives
│       ├── button.tsx
│       ├── input.tsx
│       ├── dropdown-menu.tsx
│       ├── dialog.tsx
│       ├── badge.tsx
│       ├── tooltip.tsx
│       └── toast.tsx
├── lib/
│   ├── engines/
│   │   ├── theme-engine.ts
│   │   ├── search-engine.ts
│   │   ├── upload-engine.ts
│   │   ├── processing-engine.ts
│   │   ├── download-engine.ts
│   │   ├── auth-engine.ts
│   │   ├── ai-engine.ts
│   │   ├── notification-engine.ts
│   │   ├── analytics-engine.ts
│   │   └── billing-engine.ts
│   ├── supabase/
│   │   ├── client.ts
│   │   └── server.ts
│   ├── gemini/
│   │   └── client.ts
│   └── utils.ts
├── store/                                # Zustand
│   ├── useThemeStore.ts
│   ├── useAuthStore.ts
│   ├── useToolStore.ts
│   ├── useSearchStore.ts
│   └── useUploadStore.ts
├── data/
│   ├── categories.ts                     # 15 categories, icons, colors, counts
│   └── tools.ts                          # 128 tools, metadata, routes
├── public/
│   ├── icons/                            # SVG sprite for tool icons
│   └── images/
├── styles/
│   └── tokens.css                        # CSS custom properties (design tokens)
└── middleware.ts                          # auth + rate limiting
```

---

## 15. Database Schema (Supabase / PostgreSQL)

```sql
-- Users
create table users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  full_name text,
  avatar_url text,
  plan text default 'free',           -- 'free' | 'pro' | 'enterprise'
  storage_used_mb integer default 0,
  storage_limit_mb integer default 500,
  created_at timestamptz default now()
);

-- Categories
create table categories (
  id serial primary key,
  slug text unique not null,
  name text not null,
  icon text not null,
  accent_color text not null,
  tool_count integer default 0,
  sort_order integer default 0
);

-- Tools
create table tools (
  id serial primary key,
  slug text unique not null,
  name text not null,
  description text,
  category_id integer references categories(id),
  icon text not null,
  badge text,                          -- 'popular' | 'new' | 'ai' | null
  is_ai_powered boolean default false,
  usage_count bigint default 0,
  is_active boolean default true
);

-- Jobs (Universal Processing Engine)
create table jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  tool_id integer references tools(id),
  status text default 'queued',        -- queued | processing | completed | failed
  input_file_url text,
  output_file_url text,
  error_message text,
  created_at timestamptz default now(),
  completed_at timestamptz
);

-- Search analytics
create table search_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  query text not null,
  results_count integer,
  clicked_tool_id integer,
  created_at timestamptz default now()
);

-- Newsletter subscribers
create table newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  subscribed_at timestamptz default now(),
  unsubscribed_at timestamptz
);

-- Billing / subscriptions
create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  plan text not null,
  status text not null,                -- active | canceled | past_due
  stripe_customer_id text,
  stripe_subscription_id text,
  current_period_end timestamptz
);
```

---

## 16. API Routes (Contracts)

| Route | Method | Purpose | Auth |
|---|---|---|---|
| `/api/search?q=` | GET | Universal search across 128 tools | No |
| `/api/tools` | GET | List all tools (filter by category, sort) | No |
| `/api/tools/[toolId]` | GET | Single tool metadata | No |
| `/api/tools/[toolId]/process` | POST | Submit a processing job | Yes |
| `/api/jobs/[jobId]` | GET | Poll job status (or Socket.IO event) | Yes |
| `/api/upload` | POST | Upload file to R2, returns signed upload URL | Yes |
| `/api/download/[fileId]` | GET | Signed, expiring download URL | Yes |
| `/api/ai/chat` | POST | Streaming AI Chat (Gemini) | Yes (free-tier limited) |
| `/api/ai/writer` | POST | AI Writer generation | Yes |
| `/api/ai/image-generate` | POST | AI Image Generator | Yes (Pro-gated beyond free quota) |
| `/api/auth/[...nextauth]` | ALL | Auth.js — Google/GitHub/Email | — |
| `/api/billing/checkout` | POST | Create Stripe Checkout session | Yes |
| `/api/billing/webhook` | POST | Stripe webhook handler | Signed |
| `/api/newsletter/subscribe` | POST | Add email to `newsletter_subscribers` | No |
| `/api/analytics/track` | POST | Fire-and-forget event tracking | No |

**Response shape (standard):**
```json
{
  "success": true,
  "data": { },
  "error": null,
  "meta": { "requestId": "uuid", "timestamp": "iso8601" }
}
```

---

## 17. Component Prop Contracts (Key Homepage Components)

### `<ToolCard />`
```ts
interface ToolCardProps {
  id: string;
  name: string;
  description: string;
  icon: string;                 // icon key -> resolves to SVG sprite symbol
  accentColor: string;          // token, e.g. 'accent-pdf'
  badge?: 'popular' | 'new' | 'ai';
  href: string;                 // /tools/[category]/[slug]
  onQuickAction?: () => void;   // arrow button click (opens tool in modal/quick mode)
}
```

### `<CategorySidebarItem />`
```ts
interface CategorySidebarItemProps {
  slug: string;
  label: string;
  icon: string;
  count: number;
  isActive: boolean;
  badge?: 'new';
}
```

### `<StatsBarItem />`
```ts
interface StatsBarItemProps {
  icon: string;
  value: string;    // pre-formatted e.g. "25M+"
  label: string;
}
```

### `<HeroSearchBar />`
```ts
interface HeroSearchBarProps {
  placeholder: string;
  suggestions: string[];        // quick chips below input
  onSearch: (query: string) => void;
  onChipClick: (chip: string) => void;
}
```

---

## 18. Animation Specification (Framer Motion)

| Element | Trigger | Animation | Duration / Easing |
|---|---|---|---|
| Hero heading | On mount | Fade + slide up 20px, staggered per line | 0.5s, `easeOut`, 0.1s stagger |
| Hero cube + orbit icons | Continuous | Cube: slow Y-rotation loop; icons: independent float bob ±8px | Cube 12s linear infinite; icons 3–4s ease-in-out infinite, staggered delay |
| Tool card | On hover | `scale: 1.02`, shadow glow intensifies, arrow button shifts right 2px | 0.2s `easeOut` |
| Tool card | On viewport enter | Fade + slide up 16px | 0.4s, staggered 0.05s per card (max 12 stagger, then reset) |
| CTA buttons | On hover/tap | `whileHover scale 1.03`, `whileTap scale 0.97` | 0.15s |
| Category sidebar item | On select | Background color cross-fade to violet | 0.2s |
| Stats bar numbers | On viewport enter | Count-up animation from 0 to target | 1.2s `easeOut` |
| Newsletter cube | Continuous | Slow rotate + subtle pulse glow | 8s linear infinite |
| Mobile drawer / filter sheet | Open/close | Slide from bottom, backdrop fade | 0.3s `easeInOut` |
| Command palette (⌘K) | Open/close | Scale from 0.95→1 + fade, backdrop blur fade-in | 0.2s |
| Toast notifications | Enter/exit | Slide in from top-right, auto-dismiss fade after 4s | 0.3s |

**Rule:** Respect `prefers-reduced-motion` — disable float/rotate loops, keep only opacity fades.

---

## 19. Interaction States (Every Component Needs All Four)

For **ToolCard**, **SidebarItem**, **Buttons**, **Search input**:
1. **Default** — base tokens as specified in section 1
2. **Hover** — elevated shadow / border brightens to `--brand-primary` at 40% opacity
3. **Active/Pressed** — scale down 2%, shadow flattens
4. **Disabled** (Pro-gated tools for free users) — 50% opacity, cursor `not-allowed`, small lock icon overlay top-right, tooltip "Upgrade to Pro to unlock"

**Loading states:**
- Tool grid: skeleton shimmer cards (same dimensions as `ToolCard`, animated gradient sweep) while `usage_count`/list fetches
- Search: inline spinner in input suffix while querying
- Tool processing (on tool pages, referenced from homepage cards): progress bar + percentage + "Processing your file..." with cancel button

**Empty states:**
- Search with 0 results: illustration + "No tools found for '{query}'" + "Browse all 128 tools" link
- "Load More Tools" exhausted: button replaced with "You've seen all 120+ tools ✓"

**Error states:**
- Upload/processing failure: red-bordered toast + retry button, job marked `failed` in `jobs` table

---

## 20. Spacing & Grid System

- Base unit: **4px**. All padding/margin/gap values are multiples of 4 (4, 8, 12, 16, 24, 32, 48, 64, 96).
- Max content width: `1280px` (`--container-max`), centered, `px-6` mobile / `px-8` desktop gutters.
- Section vertical rhythm: `py-16` mobile, `py-24` desktop between major homepage sections (Hero → Stats → Explorer → Features → Newsletter → Footer).
- Tool grid gap: `16px` mobile, `20px` desktop.
- Card internal padding: `20px` all sides.
- Border radius scale: `8px` (buttons/inputs), `12px` (cards), `16px` (large panels/hero card), `999px` (pills/avatars).

---

## 21. Pro vs Free Feature Gating (Homepage-Visible Logic)

| Feature | Free | Pro |
|---|---|---|
| Tool usage | 5 jobs/day per tool, watermarked output on some tools | Unlimited, no watermark |
| Cloud Storage | 500MB | 100GB (as advertised in "Why Farvixo Tools?" card) |
| AI Assistant (chat) | 10 messages/day | Unlimited + priority model |
| AI Image Generator | 3 images/day, standard quality | Unlimited, HD quality |
| Ads | Shown between tool cards (non-Pro only) | None ("No Ads, Ever") |
| Batch processing | Not available | Available |
| File size limit | 25MB | 2GB |

The header PRO badge, hero "Upgrade to Pro" card, and footer "No Ads Ever" trust badge all read live from `users.plan`.

---

## 22. Recommended Build Order (Phased)

1. **Design tokens & theme engine** — `styles/tokens.css`, dark/light CSS variables, Tailwind config extension
2. **Layout shell** — Header, NavBar, Footer, Sidebar (static, no data)
3. **Data layer** — `data/categories.ts` (15 entries), `data/tools.ts` (128 entries) seeded from Section 12 catalog
4. **Homepage static sections** — Hero, Stats Bar, Feature Strip, Newsletter (no backend yet)
5. **Tool Explorer** — CategorySidebar + ToolGrid + ToolCard wired to `data/tools.ts`, client-side filter/sort
6. **Search Engine** — header search + hero search + `⌘K` command palette, client-side fuzzy match first, then `/api/search`
7. **Auth Engine** — login/signup, header avatar + PRO badge wiring
8. **Upload/Processing/Download Engines** — generic, reused by first tool page (pick PDF Compressor as pilot)
9. **AI Engine** — AI Assistant button → chat panel, Gemini streaming
10. **Billing Engine** — Stripe Checkout, Upgrade to Pro flow, Pro gating from Section 21
11. **Analytics + Notification Engines** — usage tracking → drives real "Popular" badges, bell icon
12. **Remaining 127 tool pages** — generated from `ToolPageTemplate.tsx` + per-tool config, category by category (PDF → Image → AI → Video → Audio → Developer → Text → SEO → Utility → Security → Business → Social → Calculator → File Converter → Government)
13. **Performance pass** — Lighthouse audit, image optimization, code-splitting, LCP < 2.0s target
14. **Accessibility pass** — WCAG AA audit, keyboard nav, screen reader labels
15. **SEO pass** — meta tags, Schema.org, sitemap.xml, robots.txt (dogfooding own SEO tools)

---

## 23. Final Objective (Restated)

Build Farvixo Tools as a world-class, AI-powered, multi-tool SaaS platform where the homepage above is the single source of truth for visual design, and the 139+-tool catalog above is the single source of truth for scope. Every tool inherits the same Universal Engines (Section 9), the same design tokens (Section 1), and the same interaction states (Section 19) — so the platform feels like **one product**, not 139 separate mini-apps stitched together.
