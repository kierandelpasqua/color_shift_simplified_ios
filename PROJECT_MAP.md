# Color Shift — Project Map

> **Snapshot** of the web repo's `PROJECT_MAP.md`, copied 2026-11-24 for the iOS port and re-checked
> against web commit `3dc46c2` (identical apart from paths; the "uncommitted work" noted below is now
> committed as `e0509a1` and `3dc46c2`). The web repo's
> copy is canonical for web behavior; when it changes, re-copy this file (see `ios.md` §19).
> Relative links in this file point into the web repo and won't resolve here.

> A complete map of the Color Shift web build: what it is, how it's built, every file, every component,
> every algorithm, every external dependency, and every decision made so far. Written as the foundation
> for porting the app to **native iOS (Swift / SwiftUI)**.
>
> **Snapshot:** commit `665b91b` on `main`, plus uncommitted work (dev-only DialKit split, Agentation,
> drawer spring retune). Line numbers refer to that state. Update this file when behavior changes.

---

## Contents

1. [What the app is](#1-what-the-app-is)
   - [Screen anatomy](#screen-anatomy) · [Features](#features) · [Key user flows](#key-user-flows) · [Out of scope](#out-of-scope-web-build)
2. [Repository & locations](#2-repository--locations)
3. [File map](#3-file-map)
4. [Tech stack & toolchain](#4-tech-stack--toolchain)
5. [Architecture](#5-architecture)
6. [State model](#6-state-model)
7. ["Back-end" pieces & external services](#7-back-end-pieces--external-services)
8. [Color algorithms](#8-color-algorithms)
9. [UI components](#9-ui-components)
10. [Design tokens](#10-design-tokens)
11. [Layout & responsive behavior](#11-layout--responsive-behavior)
12. [Motion](#12-motion)
13. [Interactions, input & accessibility](#13-interactions-input--accessibility)
14. [Data: photo catalog, share links, export](#14-data-photo-catalog-share-links-export)
15. [Build, run, deploy](#15-build-run-deploy)
16. [Dev-only tooling](#16-dev-only-tooling)
17. [Decision log](#17-decision-log)
18. [Constraints](#18-constraints)
19. [Known issues & code-vs-Figma gaps](#19-known-issues--code-vs-figma-gaps)
20. [iOS porting notes](#20-ios-porting-notes)
21. [Glossary](#21-glossary)

---

## 1. What the app is

**Color Shift** turns a photo into a readable two-color pair.

- It shows a curated photo next to a large **"Aa" specimen** rendered in a foreground/background pair.
- When a photo loads, the app **samples it** and proposes a pair: background = the photo's most saturated
  color, foreground = a constructed partner tuned to at least **4.5:1** WCAG contrast.
- A slide-up **control deck** (the "mixer drawer") lets you filter photos by theme, edit both colors with
  HSL sliders or a color picker, swap them, read **WCAG** or **APCA** contrast, jump to AA/AAA, copy a
  share link, or download a Markdown summary.

One screen. No accounts, no server, no persistence. Everything runs in the browser.

### Screen anatomy

```
Desktop (> 900px wide)                         Phone (≤ 900px wide)
┌──────────────────────┬─────────────────┐      ┌───────────────────┐
│                      │                 │      │      Photo        │  ← photo share 35–47%
│   Specimen  "Aa"     │     Photo       │      ├───────────────────┤
│   (fg on bg)         │  (photo share   │      │                   │
│                      │   39–50%)       │      │  Specimen "Aa"    │
│[≡]                   │        [credit] │      │[≡]                │
├──────────────────────┴─────────────────┤      ├───────────────────┤
│  Control deck (drawer, 320px tall)     │      │ Control deck      │
└────────────────────────────────────────┘      │ min(60vh, 544px)  │
                                                └───────────────────┘
[≡] = mixer toggle, pinned to the bottom-left of the canvas area
```

Opening the drawer **pushes the canvas up** (it shrinks by the drawer height); it does not overlay it.

### Features

| # | Feature | Behavior |
|---|---|---|
| F1 | **Photo browsing** | 12 curated Unsplash photos, 2 per theme. Next: tap/click photo, **→**, or swipe left. Previous: **←** or swipe right > 35px. Wraps within the filtered set. On navigation the photo's **fallback pair** applies immediately, then the **derived pair** replaces it on load. Each photo reveals with fade/scale/blur. |
| F2 | **Theme filtering** | Chips All, Outdoors, Urban, People, Animals, Abstract, Objects. Multi-select toggle. **All** is on when nothing is selected; tapping it clears. Changing the filter resets to the first photo of the new set and applies its fallback. Selected chips shimmer. |
| F3 | **Automatic pair from photo** | Background = most saturated sampled pixel; foreground = constructed partner tuned to ≥ 4.5:1 (§8.9). Falls back to the photo's fallback pair on error. |
| F4 | **Manual adjustment** | FG/BG readouts open the system color picker; Swap exchanges them; FG/BG mix HSL sliders. |
| F5 | **Contrast scoring** | WCAG (`7.81:1`) or APCA (`71 Lc`) readout; WCAG meter with AA 4.5 / AAA 7 ticks; tick or "Jump to …" button tunes foreground lightness to the target. |
| F6 | **Share & export** | Copy link (`?fg&bg&photo`, "Copied" + toast 1.6 s); opening it restores the pair and photo. Markdown download with photo, credit, colors, ratio. |

### Key user flows

- **Explore:** open → photo 1 with its derived pair → tap the photo to browse → open the drawer to read contrast.
- **Tune for accessibility:** open the drawer → ratio < 4.5 → "Jump to AA" → foreground lightness shifts to ≥ 4.5:1 → optionally AAA.
- **Narrow the source:** open the drawer → tap Animals + Abstract → browse only those 4 photos.
- **Share:** set a pair → Copy link → send → the recipient opens the same pair and photo.

### Out of scope (web build)

No accounts, persistence, saved palettes, or history (state survives only in a share link). No
user-uploaded photos; the catalog is fixed. No OKLCH/HSB/RGB slider models (Figma only, §19).

---

## 2. Repository & locations

| What | Where |
|---|---|
| Local project root | `~/GitHub/Color_Shift_Simplified_web/Build Color Shift Simplified/` |
| Outer folder (not in git) | `~/GitHub/Color_Shift_Simplified_web/` — also holds `Build Color Shift Simplified.zip` (original Figma Make export) |
| iOS port (sibling) | `~/GitHub/Color_Shift_Simplified_iOS/` — public repo `https://github.com/kierandelpasqua/color_shift_simplified_ios` (plan, research, PRD) |
| GitHub | `https://github.com/kierandelpasqua/Color_Shift_Simplified_Figma` — **private**, branch `main` |
| Figma design | `https://www.figma.com/design/6Qbnqcd9C5lXrWTo9htKgk/Color-Shift-Simplified` (file key `6Qbnqcd9C5lXrWTo9htKgk`) |
| Figma pages | `0:1` Cover · `1:2` Foundations · **`1:3` Components** · `1:4` Screens · `1:5` Archive |
| Local dev URL | `http://localhost:5199/` (ad-hoc; Figma Make's default is port 8443) |

### Commit history

| Commit | Change |
|---|---|
| `d50bfac` | Initial commit: Figma Make export |
| `68b8909` | Wave-pulse shimmer on selected theme chips (CSS) |
| `c26b5a7` | Mixer icon: full-width middle line, shorter top/bottom bars |
| `927c1c3` | DialKit controls for photo reveal + mixer drawer motion |
| `f6fa44b` | Mixer toggle 56 → 48px |
| `665b91b` | Specimen "Aa" +10pt |
| *(uncommitted)* | DialKit/Agentation dev-only, drawer spring retune to ~3% overshoot, this file |

---

## 3. File map

```
Build Color Shift Simplified/
├── PROJECT_MAP.md            ← this file
├── AGENTS.md                 Agent guide from Figma Make (stack, styling rules)
├── CLAUDE.md                 "@AGENTS.md" (includes AGENTS.md)
├── index.html                HTML shell: #root, title, theme-color, inline SVG favicon
├── package.json              Scripts + dependencies
├── pnpm-lock.yaml            Lockfile (pnpm 10.34.3)
├── tsconfig.json             Strict TS, bundler resolution, "@/*" → src/*
├── vite.config.ts            Vite config + 5 Figma Make plugins (see §15)
├── .mise.toml                Toolchain pins: node 22, pnpm 10.34.3
├── .gitignore                node_modules, dist, .env*, logs, .DS_Store, …
├── .gitattributes            Git LFS rules for binaries (images, video, fonts, archives…)
├── public/
│   ├── favicon.png           PNG favicon (exempt from LFS)
│   └── .gitattributes        "favicon.png -filter -diff -merge -text"
├── .figma/
│   ├── README.md             Why .figma/ is committed
│   └── make/                 Figma Make lifecycle scripts (install, dev, deploy, …) + site.json
└── src/
    ├── main.tsx              Entry: mounts <App/> in React.StrictMode, imports index.css
    ├── App.tsx               THE APP: catalog, color math, all UI, all state (~710 lines)
    ├── index.css             All styles (~640 lines), plain CSS classes
    ├── motionConfig.ts       Shipped motion defaults + toCssTransition() (spring → CSS)
    ├── DialKitPanels.tsx     DEV ONLY: DialKit live-tuning panels
    └── vite-env.d.ts         Vite type reference
```

### Where things live in `src/App.tsx`

| Lines | Content |
|---|---|
| 1–18 | Imports; lazy dev-only `DialKitPanels` and `Agentation` |
| 20–31 | Types: `Theme`, `ColorRole`, `Photo` |
| 33–142 | `photos` catalog (12 entries) |
| 144–152 | `themes` list (All + 6) |
| 154–159 | `layoutShares(aspect)` |
| 161–212 | `hexToRgb`, `rgbToHex`, `rgbToHsl`, `hslToHex` |
| 214–246 | `luminance`, `contrast`, `apcaApprox`, `tuneToContrast` |
| 248–296 | Icons: `SlidersIcon`, `JellyfishMark`, `Icon` (swap/copy/download/arrow) |
| 298–316 | `App` state + motion state |
| 318–344 | Derived values; `setFromFallback`; `navigate` |
| 346–358 | Keyboard shortcuts |
| 360–391 | `deriveFromPhoto` (canvas sampling) |
| 393–433 | `toggleTheme`, `setChannel`, `jumpThreshold`, `copyLink`, `downloadMarkdown` |
| 435–446 | Deep-link parsing on mount |
| 448–461 | CSS custom properties; `photoKey` |
| 463–711 | JSX: specimen, photo panel, toggle, control deck, toast, dev tools |

### Where things live in `src/index.css`

| Lines | Content |
|---|---|
| 1–31 | Font import (Google Fonts), Tailwind import, base layer (root colors, focus ring) |
| 33–69 | `.app` grid + drawer transitions; `.specimen`; `.specimen-type` |
| 71–120 | `.photo-panel`, photo reveal, `.photo-credit` |
| 122–176 | `.mixer-toggle`, `.control-deck`, open state |
| 178–283 | Topline, identity, theme chips, chip wave `@keyframes chip-wave` |
| 285–432 | Export buttons, control grid, color readout, swap, sliders |
| 434–519 | Contrast block, mode switch, track, ticks, next-pass |
| 521–544 | Toast |
| 546–627 | Breakpoints ≤ 900px, ≤ 560px |
| 629–640 | `prefers-reduced-motion` |

---

## 4. Tech stack & toolchain

| Layer | Choice | Version |
|---|---|---|
| UI | React + React DOM | ^19.0.0 |
| Language | TypeScript (strict) | ^5.7.0 |
| Bundler / dev server | Vite (Rolldown) + `@vitejs/plugin-react` | ^8.0.5 / ^6.0.0 |
| Styling | Hand-written CSS in `src/index.css`; Tailwind v4 is imported via `@tailwindcss/vite` but **no utility classes are used** | ^4.0.0 |
| Motion math | `motion` (only `spring()` is used, to generate CSS `linear()` curves) | ^14.14.0 |
| Dev tuning | `dialkit` (runtime dep, but only loaded in dev) | ^2.2.1 |
| Dev feedback | `agentation` (devDependency) | ^3.1.2 |
| Formatter | `oxfmt` | ^0.76.0 |
| Package manager | pnpm | 10.34.3 (via `.mise.toml`; run as `npx pnpm@10.34.3` if pnpm isn't installed) |
| Runtime | Node | 22 (pinned); works on 26 locally |
| Large files | Git LFS | installed; currently tracks nothing (favicon is exempt) |

No router, no state library, no data fetching library, no test framework.

---

## 5. Architecture

### Shape

A **single React component** (`App`) owns all state and renders the whole screen. Pure helper functions
(color math, layout) sit above it in the same file. Styling is driven by **CSS custom properties** that
`App` writes onto the root `<main>` element plus one state class (`controls-open`).

```
main.tsx ──► <App/> (StrictMode)
               │
               ├─ pure helpers: layoutShares, hex/rgb/hsl, luminance, contrast, apcaApprox, tuneToContrast
               ├─ motionConfig.ts: photoRevealDefaults, drawerDefaults, toCssTransition
               │
               ├─ state (useState/useRef) ──► derived values ──► CSS vars on <main>
               │
               └─ render:
                    <main class="app [controls-open]" style="--foreground…">
                      <section.specimen>        "Aa"
                      <section.photo-panel>     <img key=url#replay> + credit
                      <button.mixer-toggle>
                      <section.control-deck>    topline + control grid
                      <div.toast>
                      [dev] <DialKitPanels/> <Agentation/>
```

### Data flow

```
 user input                     image onLoad
 ───────────                    ─────────────
 tap/swipe/arrows ─► navigate ─┐        │
 chips ────────────► toggleTheme ┤      ▼
                                 ├─► photoIndex ─► photo ─► <img> loads ─► deriveFromPhoto ─┐
                                 └─► fallback pair ──────────────────────────────┐          │
 sliders/picker/swap/jumps ────────────────────────────────────────────────────► fg, bg ◄──┘
 deep link (?fg&bg&photo) on mount ────────────────────────────────────────────►    │
                                                                                     ▼
                                    wcag, apca, layout shares, CSS vars ─► every view updates
```

**Color update order on navigation:** fallback pair applied immediately → new image mounts in its reveal
start state → `onLoad` marks it loaded (reveal animates) and runs `deriveFromPhoto`, replacing the pair.
The specimen's 180 ms color transition smooths both changes.

### CSS custom properties set by `App`

| Variable | Source |
|---|---|
| `--foreground`, `--background` | color state |
| `--photo-share`, `--mobile-photo-share` | `layoutShares(photo.aspect)` |
| `--drawer-duration`, `--drawer-ease` | `toCssTransition(drawerDial.transition)` |
| `--photo-duration`, `--photo-ease` | `toCssTransition(photoDial.transition)` |
| `--photo-from-opacity`, `--photo-from-scale`, `--photo-from-blur` | `photoDial` |
| `--deck-height` | set by CSS: 0 closed; 320px (desktop) / `min(60dvh, 34rem)` (≤ 900px) when `.controls-open` |
| `--range-color` | per slider row: the color being edited |

---

## 6. State model

All in `App` (`src/App.tsx:299-316`).

| State | Type | Initial | Written by |
|---|---|---|---|
| `controlsOpen` | bool | `false` | Mixer toggle, **F** key, tap specimen/photo while open, touch while open |
| `selectedThemes` | `Theme[]` | `[]` (means All) | Theme chips |
| `photoIndex` | int | `0`, or `?photo=` | `navigate`, `toggleTheme` (→ 0), deep link |
| `foreground` | hex string | `photos[0].fallback[1]` = `#F4C6D9` | derive, fallback, sliders, picker, swap, jump, deep link |
| `background` | hex string | `photos[0].fallback[0]` = `#16172B` | derive, fallback, sliders, picker, swap, deep link |
| `mode` | `"WCAG" \| "APCA"` | `"WCAG"` | Mode switch |
| `copied` | bool | `false` | `copyLink` → true, auto-false after 1600 ms |
| `loadedPhoto` | string \| null | `null` | `<img onLoad>` → current `photoKey` |
| `photoReplay` | int | `0` | Dev-only DialKit "Replay" |
| `photoDial` | `PhotoReveal` | `photoRevealDefaults` | Dev-only DialKit |
| `drawerDial` | `DrawerMotion` | `drawerDefaults` | Dev-only DialKit |

| Ref | Purpose |
|---|---|
| `touchStart` | Touch-start X for swipe detection |
| `suppressPhotoClick` | Swallow the click that follows a touch that closed the drawer |
| `preserveLinkedColors` | After a deep link sets both colors, skip **one** `deriveFromPhoto` |

| Derived | Formula |
|---|---|
| `visiblePhotos` | all photos if no theme selected, else those whose `theme` is selected (catalog order) |
| `photo` | `visiblePhotos[photoIndex % visiblePhotos.length]` |
| `shares` | `layoutShares(photo.aspect)` |
| `wcag` | `contrast(foreground, background)` |
| `apca` | `apcaApprox(foreground, background)` |
| `photoKey` | `` `${photo.url}#${photoReplay}` `` (remounts `<img>` per photo) |

### Actions

| Action | Effect |
|---|---|
| `navigate(dir)` | `photoIndex = (i + dir + n) mod n` over visible photos; apply that photo's fallback pair |
| `toggleTheme(t)` | All → clear; else toggle `t`. Reset `photoIndex` to 0; apply first visible photo's fallback |
| `setChannel(role, h\|s\|l, v)` | Rebuild role's color from its (rounded) HSL with one channel replaced |
| `jumpThreshold(target)` | `foreground = tuneToContrast(foreground, background, target)` |
| swap | exchange `foreground` and `background` |
| `copyLink()` | write share URL to clipboard; `copied = true` for 1.6 s |
| `downloadMarkdown()` | build Markdown, download as a Blob |

---

## 7. "Back-end" pieces & external services

**There is no back-end.** No server code, API, database, auth, analytics, or environment variables. The
production build is a **static site**. Everything below is either a third-party CDN the browser calls
directly or a browser API.

| Piece | What it does | Details / constraints |
|---|---|---|
| **Unsplash image CDN** | Serves all 12 photos | `https://images.unsplash.com/photo-…?auto=format&fit=crop&w=1800&q=88`. Hotlinked; no API key; **no Unsplash API calls**. Loaded with `crossOrigin="anonymous"` so the canvas can read pixels (CDN sends CORS headers). If CORS fails, sampling throws and the fallback pair is used. |
| **unsplash.com profiles** | Credit links | `https://unsplash.com/@<handle>`, opened in a new tab. |
| **Google Fonts** | Manrope (400–700), DM Mono (400, 500) | `@import` in `src/index.css:1`, `display=swap`. Offline or blocked → system fallbacks. |
| **Canvas 2D API** | Color sampling | 32×32 offscreen canvas, `getImageData`. See §8.9. |
| **Clipboard API** | Copy link | `navigator.clipboard.writeText`. Needs a secure context (HTTPS or localhost). **Rejection isn't handled** (§19). |
| **Blob + object URL** | Markdown download | Synthesized `<a download>` click. |
| **URL / query string** | Share-link state | `?fg=&bg=&photo=` read once on mount. |
| **Figma Make hosting** | Production deploy | `figma make deploy --build-dir dist` (static adapter). `robots.index: false` → `robots.txt` Disallow-all + `noindex` meta. |
| **GitHub** | Source hosting | Private repo. No CI configured. |
| **Figma file** | Design source | Read via the Figma MCP during development; not used at runtime. |

**For iOS:** the same picture. A self-contained client that loads remote images. Bundle the photos and
fonts, or keep hotlinking (see §20).

---

## 8. Color algorithms

All pure functions in `src/App.tsx:154-246`, plus `deriveFromPhoto` at `:360`. Colors are `#RRGGBB` sRGB
strings; HSL is **integer-rounded** (h 0–359, s 0–100, l 0–100).

### 8.1 `hexToRgb(hex)`
Strip `#`, parse pairs base-16 → `{r, g, b}` 0–255. **No validation.**

### 8.2 `rgbToHex(r, g, b)`
`Math.round` each channel, 2-digit hex, uppercase, prefixed `#`. **No clamping.**

### 8.3 `rgbToHsl(hex)`
```
r,g,b ← c/255;  max,min;  d ← max − min
l ← (max + min)/2
s ← d = 0 ? 0 : d / (1 − |2l − 1|)
h ← d = 0 ? 0 : max=r → ((g−b)/d) % 6   (JS %: sign of dividend)
                max=g → (b−r)/d + 2
                else  → (r−g)/d + 4
→ { h: round((h·60 + 360) % 360), s: round(s·100), l: round(l·100) }
```

### 8.4 `hslToHex(h, s, l)`
```
s,l ← /100;  c ← (1 − |2l − 1|)·s;  x ← c·(1 − |((h/60) % 2) − 1|);  m ← l − c/2
sector of h (60° steps): (c,x,0) (x,c,0) (0,c,x) (0,x,c) (x,0,c) (c,0,x)
→ rgbToHex((r+m)·255, (g+m)·255, (b+m)·255)
```

### 8.5 `luminance(hex)`: WCAG 2.x relative luminance
```
v ← c/255;  lin ← v ≤ 0.04045 ? v/12.92 : ((v + 0.055)/1.055)^2.4
L ← 0.2126·R + 0.7152·G + 0.0722·B
```

### 8.6 `contrast(a, b)`: WCAG ratio
`(L_light + 0.05) / (L_dark + 0.05)`, range 1–21, order-independent.

### 8.7 `apcaApprox(fg, bg)`
`|(L_bg^0.56 − L_fg^0.57) × 114|`. A **rough approximation** of APCA Lc. It skips APCA's soft clamp,
low-contrast offset, and polarity-specific exponents, and reuses WCAG luminance. Not symmetric. Displayed
as `round(x) Lc`.

### 8.8 `tuneToContrast(color, fixed, target = 4.5)`
```
hsl ← rgbToHsl(color)
dir ← luminance(fixed) > 0.45 ? −1 : +1          // darken against light, lighten against dark
for i in 0…100:
  cand ← hslToHex(hsl.h, hsl.s, clamp(hsl.l + dir·i, 0, 100))
  if contrast(cand, fixed) ≥ target → return cand
return last cand                                  // may fall short of target
```
Only **lightness** moves; hue and saturation are preserved. Used by Jump to AA/AAA and by photo derivation.

### 8.9 `deriveFromPhoto(img)`: photo → pair
1. If `preserveLinkedColors` is set → clear it, **return** (deep link wins once).
2. Draw the image into a **32×32** canvas (`willReadFrequently: true`).
3. Read RGBA; take **every 8th pixel** (byte stride 32) → **128 samples** (rows 0–31, columns 0/8/16/24).
4. Per sample: hex, luminance (computed but unused), HSL saturation.
5. Stable-sort by saturation, descending. **base** = first.
6. Partner:
   - `luminance(base) > 0.45` → `tuneToContrast(hslToHex(base.h, 55, 15), base)` (dark, same hue)
   - else → `tuneToContrast(hslToHex((base.h + 35) % 360, 70, 88), base)` (light, hue +35°)
7. `background = base`, `foreground = partner`.
8. Any exception → the photo's fallback pair.

### 8.10 `layoutShares(aspect)`

| aspect (w/h) | desktop photo width | mobile photo height |
|---|---|---|
| < 0.85 | 39% | 47% |
| 0.85 – < 1.2 | 44% | 42% |
| 1.2 – < 1.45 | 48% | 38% |
| ≥ 1.45 | 50% | 35% |

### 8.11 Contrast meter geometry
Fill `= min(100%, wcag / 12)`. Ticks at `4.5/12 = 37.5%` (AA) and `7/12 = 58.3%` (AAA). The meter is
always WCAG, even in APCA mode.

### 8.12 Test vectors (generated by running the real source)

| `rgbToHsl` | h, s, l |
|---|---|
| `#F2D27A` | 44, 82, 71 |
| `#1F3A5F` | 215, 51, 25 |
| `#16172B` | 237, 32, 13 |
| `#F4C6D9` | 335, 68, 87 |
| `#808080` | 0, 0, 50 |
| `#FF0000` | 0, 100, 50 |

| `hslToHex` | out |
|---|---|
| 45, 82, 71 | `#F2D378` |
| 214, 51, 25 | `#1F3B60` |
| 0, 100, 50 | `#FF0000` |
| 200, 0, 50 | `#808080` |

| Round trip `hslToHex(rgbToHsl(x))` | out |
|---|---|
| `#F2D27A` | `#F2D178` (drift) |
| `#1F3A5F` | `#1F3A60` (drift) |

| `luminance` | L |
|---|---|
| `#FFFFFF` / `#000000` | 1.000 / 0.000 |
| `#F2D27A` | 0.664 |
| `#1F3A5F` | 0.041 |
| `#111214` | 0.006 |

| `contrast` | ratio |
|---|---|
| `#FFFFFF` · `#000000` | 21.000 |
| `#F2D27A` · `#1F3A5F` | 7.806 |
| `#F4C6D9` · `#16172B` | 11.687 |
| `#777980` · `#111214` | 4.312 |

| `apcaApprox(fg, bg)` | Lc |
|---|---|
| `#F2D27A` on `#1F3A5F` | 71.080 |
| `#1F3A5F` on `#F2D27A` | 72.051 |
| `#000000` on `#FFFFFF` | 114.000 |
| `#FFFFFF` on `#000000` | 114.000 |

| `tuneToContrast(color, fixed, target)` | result | achieved |
|---|---|---|
| `#8899AA`, `#1F3A5F`, 4.5 | `#97A6B5` | 4.614 |
| `#8899AA`, `#1F3A5F`, 7 | `#C3CCD5` | 7.064 |
| `#8899AA`, `#F4F4EF`, 4.5 | `#5D7083` | 4.630 |
| `#556677`, `#FFFFFF`, 7 | `#4A5968` | 7.192 |

| `layoutShares` | desktop, mobile |
|---|---|
| 0.67 | 39, 47 |
| 0.85 | 44, 42 |
| 1.2 / 1.33 | 48, 38 |
| 1.45 / 1.56 | 50, 35 |

### 8.13 Porting notes for the color engine

- **Port this first.** The functions are pure and dependency-free; unit-test them against §8.12.
- **Rounding parity:** JavaScript `Math.round` rounds .5 toward +∞. Swift's default `.rounded()` rounds
  away from zero. They only differ for negative values (which shouldn't occur here); for exact parity use
  `(x + 0.5).rounded(.down)`.
- **Modulo:** JS `%` keeps the dividend's sign, like Swift's `truncatingRemainder(dividingBy:)`.
- **Derived pairs aren't fixtures.** Sampling depends on how the platform resamples the image to 32×32, so
  iOS may pick slightly different colors than the browser. That's fine; test the functions, not the derived pairs.
- **Keep the hex-string API at the boundary** for parity with the web and share links; use `Double` internally.

```swift
struct HSL { var h, s, l: Int }   // integer-rounded, like the web

enum ColorMath {
    static func hexToRGB(_ hex: String) -> (r: Double, g: Double, b: Double)
    static func rgbToHex(_ r: Double, _ g: Double, _ b: Double) -> String
    static func rgbToHSL(_ hex: String) -> HSL
    static func hslToHex(_ hsl: HSL) -> String
    static func luminance(_ hex: String) -> Double
    static func contrast(_ a: String, _ b: String) -> Double
    static func apcaApprox(text: String, background: String) -> Double
    static func tune(_ color: String, against fixed: String, target: Double = 4.5) -> String
    static func layoutShares(aspect: Double) -> (desktop: Int, mobile: Int)
}

enum PhotoSampler {
    /// 32×32 resample, every 8th pixel, most-saturated base, partner via ColorMath.tune.
    static func derivePair(from image: CGImage) -> (background: String, foreground: String)?
}
```

---

## 9. UI components

Figma nodes refer to the **Components** page (`1:3`).

```
App                                   <main.app>
├── Specimen                          .specimen          Figma build›canvas›color 18:975
├── PhotoPanel                        .photo-panel       Figma build›canvas›photo 18:977
│   ├── Photo                         img (reveal)
│   └── PhotoCredit                   .photo-credit
├── MixerToggle                       .mixer-toggle      Figma controls toggle 16:88
├── ControlDeck                       .control-deck      Figma control deck 18:606 (desktop 18:304 / phone 18:456)
│   ├── Topline                       .control-topline   Figma top line 18:153
│   │   ├── Identity                  .identity          Figma identity 17:155, logo 17:19
│   │   ├── ThemeChips                .theme-list        Figma theme chips 17:124 → chip 16:67
│   │   └── ExportActions             .export-actions    Figma export 17:139 → button 16:60
│   └── ControlGrid                   .control-grid      Figma control grid 18:194
│       ├── ColorReadout              .color-readout     Figma colors 17:58, color value 17:53, swatch 16:25
│       │   └── SwapButton            .swap-button       Figma icon container 16:79
│       ├── SliderGroup (FG mix)      .slider-group      Figma color sliders 17:95 → sliders 17:28 → slider 17:20
│       ├── SliderGroup (BG mix)
│       └── ContrastBlock             .contrast-block    Figma contrast 17:266, mode switch 17:181, meter 17:209, score 17:168
└── Toast                             .toast
```

| Component | Behavior & states |
|---|---|
| **Specimen** | Fills with bg; "Aa" in fg (Manrope 600). Colors transition 180 ms. Tap closes the drawer if open. a11y label `Color specimen, <fg> on <bg>`; "Aa" hidden from a11y. |
| **PhotoPanel** | Cover-fit image, placeholder `#232427`. Tap: close drawer if open, else next photo. Swipe (touch). a11y label "Next source photo". |
| **Photo** | Keyed by `photoKey`; starts at opacity 0 / scale 1.04 / blur 8px; `.is-loaded` on load animates to rest. |
| **PhotoCredit** | `Photo` (55% white) + name. Links to the Unsplash profile in a new tab; stops propagation so it doesn't advance. |
| **MixerToggle** | 48×48 square at the canvas's bottom-left; rides up with the canvas. `#151619`, hover `#292B30` + scale 1.04. Label "Open/Close color controls"; `aria-expanded`. Figma states: default, hover. |
| **ControlDeck** | Fixed bottom drawer, `#111214`, scrolls on overflow. Closed: translated 100% down + `visibility:hidden` + `aria-hidden`. |
| **Identity** | Jellyfish mark + "Color Shift" / "PHOTO → PAIR". |
| **ThemeChips** | All + 6 themes; multi-select; horizontal scroll. States: default (border `#303237`, text `#95979D`), selected (fill/border `#F4F4EF`, text `#111214`, wave shimmer). Figma also has a hover state (text `#E5E0E0`). |
| **ExportActions** | Copy link (→ "Copied" 1.6 s) and Markdown. Icon-only ≤ 560px. Figma `button`: ghost default/hover/selected, filled default/hover. |
| **ColorReadout** | FG/BG fields: label, swatch (23.2px circle), hex; tap opens the native color picker (hidden `input[type=color]`). Swap button (32px circle) between them. |
| **SliderGroup** | "FG MIX"/"BG MIX" + `H° · S% · L%`. Hue 0–360 (rainbow track), Sat 0–100, Light 0–100 (track `#24262B` → color). Thumb 12px. |
| **ContrastBlock** | WCAG/APCA segmented switch; score (`7.81:1` / `71 Lc`); WCAG meter with AA/AAA tick buttons (each jumps); "Jump to AA/AAA →" button (AA if < 4.5, else AAA). |
| **Toast** | "Link copied to clipboard", bottom center, fade + 16px rise, 180 ms, while `copied`. |

### Icons (24×24 stroke, no fill, round caps)

| Icon | Path |
|---|---|
| Mixer | `M4 7h4m4 0h8M8 5v4M4 17h8m4 0h4m-4-2v4M4 12h16` |
| Swap | `m7 7-3 3 3 3` + `M4 10h13M17 17l3-3-3-3M20 14H7` |
| Copy | `rect 8,8 11×11 rx2` + `M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2` |
| Download | `M12 3v12m0 0 4-4m-4 4-4-4M4 19h16` |
| Arrow | `M5 12h14m-5-5 5 5-5 5` |
| Jellyfish (36×36, filled) | `#FFFFFF` body, `#B9BAC0` and `#777983` facets (`src/App.tsx:256`) |

On iOS, export these as custom SF Symbols or PDF vector assets. Close but non-identical SF Symbols:
`slider.horizontal.3` (mixer), `arrow.left.arrow.right` (swap), `doc.on.doc` (copy),
`arrow.down.to.line` (download), `arrow.right` (arrow).

### Figma-only components (not built in code)

| Figma component | Node | Notes |
|---|---|---|
| `color mode` | 17:73 | Slider model switch: OKLCH / HSB / RGB |
| `switch option` | 16:95 | default / selected (used by `color mode`) |
| `meter` APCA variant, `contrast` APCA variant | 17:194, 17:235 | APCA ticks Lc 45/60/75/90, "Jump to Lc 75" |
| `grip` | 16:31 | expanded=false / true: a drawer drag handle |
| `marker`, `track`, `slider values` | 17:182, 16:26, 16:32 | Meter and slider parts |
| `icon / left`, `icon / right` | 16:21, 16:24 | Previous/next photo affordances |
| `chip` hover, `button` ghost/filled states | 16:63, 16:60 | Pointer hover states |

These hint at the next design iteration; see §20 for the code-vs-design decision.

---

## 10. Design tokens

Raw values from `src/index.css`. Names are **proposed** for iOS. 1 rem = 16px; px ≈ pt on iOS.

### Colors

| Token | Value | Use |
|---|---|---|
| `surface.canvas` | `#111214` | App/deck bg, selected-chip text |
| `surface.photoPlaceholder` | `#232427` | Photo before load |
| `surface.toggle` / `.toggleHover` | `#151619` / `#292B30` | Mixer toggle |
| `surface.button` | `#242529` | Buttons, toast |
| `surface.segmented` | `#202125` | Mode switch bg |
| `surface.track` | `#34363A` | Contrast track |
| `surface.sliderStart` | `#24262B` | S/L slider start |
| `text.primary` / `.deck` | `#F4F4F1` / `#F3F3EF` | Text |
| `text.button` | `#D4D5D2` | Button labels |
| `text.chip` | `#95979D` | Unselected chip |
| `text.muted` | `#777980` | Labels ⚠️ 4.31:1 on canvas |
| `text.subtle` | `#7D7F86` | Subtitle |
| `text.tick` | `#7F8187` | Tick labels |
| `icon.swap` | `#DADBD8` | Swap icon |
| `selected.fill` | `#F4F4EF` | Selected chip |
| `selected.segment` | `#EEEEEE` | Active segment, meter fill |
| `line.chip` / `.swap` / `.tick` | `#303237` / `#34363B` / `#A7A8AC` | Borders, ticks |
| `thumb.fill` / `.ring` | `#F5F5F1` / `#61636A` | Slider thumb |
| `focus.ring` | `#FFFFFF`, 2px, offset 3px | Focus |
| `credit.bg` | `rgba(10,10,10,.68)` + blur 8 | Credit chip |
| `credit.label` | `rgba(255,255,255,.55)` | "Photo" |
| `swatch.border` | `rgba(255,255,255,.15)` | Swatches |
| `chip.wave` | `rgba(17,18,20,.08)` peak | Shimmer |
| Hue gradient | `#F55 #FF5 #5F5 #5FF #55F #F5F #F55` | Hue track |

### Typography

Fonts: **Manrope** (UI, specimen), **DM Mono** (labels, values, controls). Both SIL OFL.

| Style | Font | Size px | Notes |
|---|---|---|---|
| specimen | Manrope 600 | `clamp(80, min(30% w, 64% h), 512) + 13.33` of the specimen box | lh 0.72, tracking −0.1em, x −0.04em |
| brand title | Manrope 700 | 12.32 | |
| brand subtitle | DM Mono 400 | 8.64 | uppercase |
| section title | Manrope 700 | 10.88 | uppercase |
| field label | DM Mono 400 | 8.8 | uppercase, muted |
| hex value | DM Mono 500 | 11.84 | |
| chip | DM Mono 500 | 9.92 | |
| button | DM Mono 500 | 9.6 | |
| segment | DM Mono 500 | 8.32 | |
| contrast value | DM Mono 500 | 20 | |
| tick label | DM Mono 400 | 8 | |
| toast / credit | DM Mono 400 / 500 | 9.92 | |

⚠️ Most sizes are under 11pt, Apple's recommended minimum. Scale them up on iOS and support Dynamic Type.
The specimen size is relative to the **specimen box**, not the screen. On iOS, compute it from a
`GeometryReader` around the specimen view. Figma uses **Geist Mono** where the code uses DM Mono (§19).

### Spacing & radii (px)

| Item | Value |
|---|---|
| Deck height | 320 desktop; `min(60vh, 544)` ≤ 900 |
| Deck padding | 16 / 22.4 / 19.2 (top / sides / bottom); 16 ≤ 900 |
| Topline | cols `160 · 1fr · auto`, gap 24, margin-bottom 18.4 |
| Control grid | `1.15fr 1fr 1fr 1.2fr`, gap `clamp(16, 3vw, 48)` |
| Mixer toggle | 48 square, icon 20, stroke 1.6, radius 0 |
| Chip | pad 7.68×11.2, gap 4.48, 1px border, pill |
| Button | pad 8×9.92, radius 4.8, icon 14.4 / stroke 1.7, gap 6.4 |
| Segmented | pad 2.4; segment pad 6.08×7.68; pill |
| Swatch / swap | 23.2 / 32 circles |
| Slider | track 4, thumb 12 (2px border + 1px ring), label col 35.2, gap 7.2, rows gap 10.24 |
| Contrast track | 5.12 high, inset 4, 32 below; ticks 1×14.4 at −4.8 |
| Credit | inset 16, pad 7.68×10.4, radius 4.48, shadow `0 2 12 rgba(0,0,0,.18)` |
| Toast | bottom 19.2, pad 11.52×14.4, radius 4.8 |

---

## 11. Layout & responsive behavior

| Width | Canvas | Deck |
|---|---|---|
| > 900px | Grid columns: specimen `100% − share` \| photo `share` (39–50%) | 320 tall; 4-column grid; chips centered |
| ≤ 900px | Stacked rows: photo (35–47%) on top, specimen below | `min(60dvh, 544)`; 2-column grid; chips on their own row, left-aligned; contrast spans both columns |
| ≤ 560px | (same) | 1 column; export buttons icon-only; readout max 320 |

- The canvas height is `100dvh − --deck-height`, so opening the deck **pushes the canvas up** (not an
  overlay). Grid column/row sizes and height animate with the drawer motion.
- The whole page is `overflow: hidden`; only the deck scrolls.
- The mixer toggle is positioned `top: 100%; translateY(-100%)` on `.app`: always the bottom-left
  corner of the canvas.

---

## 12. Motion

| # | Animation | Spec | Source |
|---|---|---|---|
| M1 | **Mixer drawer** open/close (deck translateY, canvas height, grid tracks) | **Spring: stiffness 340, damping 36, mass 1.7** → ~2.9% overshoot, ~650 ms settle. Rendered as CSS `650ms linear(…)` from `motion`'s `spring()`. | `src/motionConfig.ts` `drawerDefaults` |
| M2 | **Photo reveal** on load | opacity 0→1, scale 1.04→1, blur 8px→0; easing `cubic-bezier(0.22, 0.76, 0.32, 1)`, 600 ms | `photoRevealDefaults` |
| M3 | **Chip wave pulse** (selected chips) | 36px band, gradient transparent→`rgba(17,18,20,.08)`→transparent, moves from −36px to `left:100%`; 5 s loop, ease-in-out; opacity 0→1 by 2.8%, held to 15%, →0 by 19%, rest to 100%. All selected chips run in sync. | `index.css` `@keyframes chip-wave` (matches Figma node 41:732) |
| M4 | Specimen color change | bg + text color, 180 ms ease | `.specimen` |
| M5 | Mixer toggle hover | bg + scale 1.04, 180 ms ease | `.mixer-toggle` |
| M6 | Toast | opacity + translateY 16→0, 180 ms ease; visible 1600 ms | `.toast` |

**Reduced motion:** all transitions are forced to 0.01 ms and the chip wave is disabled
(`index.css:629-640`). The photo reveal and drawer still change state, just instantly.

**Motion history:** drawer went from easing 450 ms `cubic-bezier(0.22,0.76,0.32,1)` → spring 541/37/1.7
(~9% overshoot) → spring 340/36/1.7 (~3%).

**SwiftUI equivalents:**
- M1 → `.interpolatingSpring(mass: 1.7, stiffness: 340, damping: 36)` — or `.spring(response: 0.444, dampingFraction: 0.749)`
- M2 → `.timingCurve(0.22, 0.76, 0.32, 1, duration: 0.6)`
- M3 → `KeyframeAnimator` / `PhaseAnimator` (iOS 17+) or a `TimelineView` loop
- Reduced motion → `@Environment(\.accessibilityReduceMotion)`

---

## 13. Interactions, input & accessibility

| Input | Result |
|---|---|
| Click/tap photo | Drawer open → close it. Else → next photo. |
| Touch swipe on photo | Drawer open → close it (and swallow the click). Else: right swipe > 35px → previous; anything else → next. |
| Click/tap specimen | Close the drawer if open. |
| **F** key | Toggle the drawer (ignored when focus is in an `<input>`). |
| **→ / ←** | Next / previous photo. |
| Mixer toggle | Toggle the drawer. |
| Chip | Toggle theme (All clears). |
| Swatch/hex | Open the native color picker. |
| Swap | Exchange fg/bg. |
| Slider | Set H/S/L channel. |
| AA / AAA tick, Jump button | Tune foreground lightness to 4.5 / 7. |
| Copy link / Markdown | Share / export. |

**Accessibility as built:** focus-visible ring (2px white, 3px offset); labels on the toggle, swap, pickers,
ticks, photo panel, specimen; `aria-expanded` on the toggle; deck `aria-hidden` when closed; decorative
SVGs `aria-hidden`; reduced-motion support. **Gaps:** muted text is 4.31:1 (< AA); tiny type (8–12px);
slider rows rely on `<label>` text "Hue/Sat/Light" without the color role; no live region announcing the
contrast score; the photo panel is a `<section>` with a click handler, so it isn't keyboard-focusable
(arrows cover navigation).

---

## 14. Data: photo catalog, share links, export

### Photo catalog (`src/App.tsx:33-142`)

`Photo = { url, photographer, handle, alt, theme, fallback: [bg, fg], aspect }`

| # | Theme | Photographer (@handle) | Alt | Fallback bg / fg | Aspect |
|---|---|---|---|---|---|
| 0 | Outdoors | Simon Berger (@simon_berger) | Mountain ridges under a vivid pink and blue sky | `#16172B` / `#F4C6D9` | 1.56 |
| 1 | Outdoors | Daniela Kokina (@danielakokina) | Green mountain ridge and yellow wildflowers | `#152D24` / `#F2D77D` | 0.67 |
| 2 | Urban | Zoshua Colah (@zoshuacolah) | Colorful apartment buildings in Hong Kong | `#222127` / `#F3A33C` | 1.33 |
| 3 | Urban | Zoshua Colah (@zoshuacolah) | Red van passing colorful residential buildings | `#391B18` / `#FFD0A1` | 0.67 |
| 4 | People | Olena Bohovyk (@olenkasergienko) | Portrait in a vivid red shirt | `#381018` / `#F8CFC6` | 0.67 |
| 5 | People | Brian Lawson (@visualartery) | Portrait in pink and green with sunglasses | `#17352D` / `#FFB7D5` | 0.67 |
| 6 | Animals | Alexander Sinn (@swimstaralex) | Iridescent green and blue bird feathers | `#102A32` / `#8FE1C1` | 1.5 |
| 7 | Animals | Rob Potter (@robpotter) | Green and yellow chameleon in close-up | `#173423` / `#D9E66D` | 0.67 |
| 8 | Abstract | Sean Sinclair (@seanwsinclair) | Soft rainbow color field | `#2C1836` / `#F4B8A5` | 1.5 |
| 9 | Abstract | Marvin van Beek (@marvinvanbeek) | Flowing purple, red and warm orange shapes | `#271531` / `#F1A45E` | 0.67 |
| 10 | Objects | Runda Choo (@rundachoo) | Bowl of colorful objects and plants | `#21302A` / `#F3C9A6` | 1.5 |
| 11 | Objects | Alex Gruber (@alex_gruber) | Headset, scissors and teapot arranged on a table | `#28231D` / `#E9C782` | 0.67 |

URLs: `https://images.unsplash.com/photo-<id>?auto=format&fit=crop&w=1800&q=88` (IDs in source).
`aspect` is hand-entered, not measured.

### Share link

`<current URL>?fg=RRGGBB&bg=RRGGBB&photo=N`. Hex without `#`; `photo` = index in the **full** catalog.
On load: `fg`/`bg` must match `/^[0-9a-f]{6}$/i` (stored uppercase); `photo` must be an integer
0–11. When **both** colors are valid, the next `deriveFromPhoto` is skipped so the link's pair is kept.

### Markdown export

File name `color-shift-<FG>-<BG>.md`; MIME `text/markdown`:
```markdown
# Color Shift

![<alt>](<photo url>)

Photo by [<photographer>](https://unsplash.com/@<handle>) on Unsplash.

- Foreground: `#RRGGBB`
- Background: `#RRGGBB`
- WCAG contrast: **N.NN:1**
```

---

## 15. Build, run, deploy

| Task | Command |
|---|---|
| Install | `pnpm install` (or `npx -y pnpm@10.34.3 install`) |
| Dev server | `pnpm dev` → port `$PORT` or 8443, host `0.0.0.0`, strict port |
| Type-check | `pnpm exec tsc --noEmit -p .` |
| Production build | `pnpm build` → `dist/` (~209 kB JS, ~15 kB CSS; dev tools excluded) |
| Preview build | `pnpm preview` |
| Format | `pnpm format` (oxfmt) |
| Deploy (Figma Make) | `.figma/make/deploy` → `pnpm run build && figma make deploy --build-dir dist` |
| Deploy preview | `.figma/make/deploy-preview` → dev-mode build (inline sourcemaps, no minify) + `figma make deploy-preview` |

### `vite.config.ts`
- `base` = `$FIGMA_PUBLIC_URL/` if set, else `/`.
- `--mode development` → inline sourcemaps, no minification.
- Alias `@` → `src/` (unused so far). Dev watcher ignores `.figma/**`.
- Plugins: `react()`, `tailwindcss()`, plus Figma Make plugins:
  - **figmaSiteConfiguration**: applies `.figma/make/site.json` (description, `noindex`, favicon `/favicon.png`, OG tags, `robots.txt`).
  - **figmaErrorOverlayReplay** (dev): replays the last build error to reconnecting clients.
  - **figmaReactRefreshBoundaryFallback** (dev): forces a full reload when a module loses its React Refresh boundary.
  - **figmaMakeKitPlugin** (dev): serves `/.figma/make/kit.html` with a registry of `src/**/*.stories.*` (none exist).
  - **figmaLinkedPackageSourcemaps**: rewrites sourcemap paths for linked packages.

### `.figma/make/` scripts
`install` (`pnpm install --prefer-offline --no-frozen-lockfile`), `dev`, `deploy`, `deploy-preview`,
`format`, `langserver` (vtsls), `analyze-routes`; config `deploy.json` (`adapter: static`), `dev.json`
(reinstall on `package.json` change), `site.json`.

---

## 16. Dev-only tooling

Both load via `import.meta.env.DEV ? lazy(import(...)) : null`. Vite removes them from production builds
(verified: no DialKit or Agentation code in `dist/`).

| Tool | Purpose | Where |
|---|---|---|
| **DialKit** | Live panels "Photo reveal" (transition, start opacity/scale/blur, Replay) and "Mixer drawer" (transition). Values flow up to `App` state. "Copy parameters" exports values to paste back as defaults. | `src/DialKitPanels.tsx`; defaults in `src/motionConfig.ts` |
| **Agentation** | Bottom-right toolbar: click elements, annotate, copy structured feedback (selectors + source paths) for an AI agent. PolyForm Shield license. Optional MCP sync (`npx agentation-mcp server`) is **not** set up. | `src/App.tsx` (lazy import) |

**Do not port these to iOS.**

---

## 17. Decision log

| # | Decision | Why | Alternatives rejected |
|---|---|---|---|
| D1 | Repo initialized in the inner `Build Color Shift Simplified/` folder; outer folder and `.zip` left out | Inner folder is the project | Committing the zip |
| D2 | GitHub repo is **private** | Safe default | Public |
| D3 | Keep `.figma/` committed | Figma Make needs it to re-import | Ignoring it |
| D4 | Git LFS installed to honor `.gitattributes`; `.DS_Store` ignored | Avoid pointer/blob mismatches later | Deleting LFS rules |
| D5 | Chip wave pulse built in **pure CSS** (`::after` + `@keyframes`), animating `left` to 100% | No dependency; works for any chip width (Figma's +108px only fits 72px chips) | `motion` library (Figma's generated code) |
| D6 | Chip waves run **in sync** | Simplest; stagger offered as an option | Per-chip delay |
| D7 | Mixer icon: no middle knob, full-width middle line, top/bottom knobs 2px shorter (`M8 5v4`, `m-4-2v4`) | Design request | — |
| D8 | **DialKit** drives motion via CSS variables, not a JS animation rewrite | Keeps CSS transitions; minimal change | Rewriting with `motion` components |
| D9 | Springs converted to CSS `linear()` with `motion`'s `spring()` | DialKit can output springs; CSS can't run springs natively | Easing-only controls |
| D10 | Photo reveal triggers on **image load** (`<img key>` remount + `.is-loaded`) | Never animate a blank image | Animate on index change |
| D11 | DialKit + Agentation **dev-only**, lazy-loaded behind `import.meta.env.DEV` | Bundle dropped from >500 kB to 209 kB | Shipping them hidden |
| D12 | Motion defaults centralized in `src/motionConfig.ts` | One place to edit shipped values; shared by app and DialKit | Inline in `App.tsx` |
| D13 | Mixer toggle 56 → **48px** (4px less padding per side) | Agentation feedback | — |
| D14 | Specimen `+10pt` via `calc(clamp(…) + 10pt)` | Keep fluid sizing, add a constant | Changing the clamp bounds |
| D15 | Drawer spring retuned to **340 / 36 / 1.7** (~3% overshoot, 650 ms) | "Less bouncy" made specific: 3% overshoot, keep 650 ms, keep spring | Critically damped; easing curve |
| D16 | Documentation lives **in the repo** as a single `PROJECT_MAP.md` | Versioned with code; one file is easier to manage than a `docs/` tree; readable by the iOS port | External docs; multi-file `docs/` folder |

---

## 18. Constraints

- **Static only.** No server; any future feature that needs storage or accounts needs new infrastructure.
- **Figma Make compatibility.** Keep `.figma/`, the `vite.config.ts` plugins, port/host env handling,
  and `pnpm` (scripts call `pnpm`). Figma Make expects the dev server on `$PORT` (8443).
- **Toolchain pins:** Node 22, pnpm 10.34.3 (`.mise.toml`).
- **CORS:** sampling only works for images served with CORS headers (`crossOrigin="anonymous"`).
- **Clipboard** needs a secure context (HTTPS/localhost).
- **Unsplash:** photos are hotlinked. Attribution (photographer + Unsplash) must stay visible. Re-check
  Unsplash's license/API guidelines before shipping to an app store.
- **Fonts** load from Google at runtime; both are OFL and can be self-hosted or bundled.
- **No tests** exist; the color-math vectors in §8.12 are the regression baseline.
- **Reduced motion** must stay respected.
- **Indexing disabled** (`robots: noindex`) for the deployed site.
- **Licenses:** DialKit MIT; Agentation PolyForm Shield 1.0.0 (dev-only; prohibits building a competing product).

---

## 19. Known issues & code-vs-Figma gaps

### Bugs / risks (from reading the code; ✅ = confirmed by running it)

| Issue | Detail |
|---|---|
| **Tap may advance twice on touch devices** | `onTouchEnd` calls `navigate(1)` and the browser's follow-up `click` calls it again (`suppressPhotoClick` is only set when closing the drawer). *Not yet verified on a device.* |
| **Share link photo index vs filter** | `photoIndex` indexes the **filtered** list; the link writes the **full-catalog** index. Restoring is correct only because filters reset on load, but the two meanings are easy to mix up when porting. |
| **HSL round-trip drift** ✅ | `rgbToHsl` rounds to integers, so moving any slider re-quantizes the whole color (`#F2D27A` → `#F2D178`). The picker can set colors the sliders can't reproduce. |
| **`tuneToContrast` can miss the target** | Returns the last candidate when 0/100% lightness can't reach the ratio (e.g. mid-gray against mid-gray at 7:1). No feedback to the user. |
| **APCA is approximate** | See §8.7; the label "Lc" overstates precision. The meter and jumps ignore APCA. |
| **Muted text fails AA** ✅ | `#777980` on `#111214` = 4.31:1. |
| **Tiny type** | 8–12px for most labels. |
| **Clipboard errors unhandled** | A rejected `writeText` throws an unhandled promise rejection; no user feedback. |
| **Side effect inside a state updater** | `navigate` calls `setFromFallback` inside `setPhotoIndex(updater)`. Under StrictMode the updater runs twice in dev. Harmless (idempotent), but not idiomatic. |
| **Duplicate favicons** | `index.html` has an inline SVG favicon and the Figma plugin injects `/favicon.png`. |
| **Unused luminance in sampling** | `deriveFromPhoto` computes `lum` per sample and never uses it. |
| **Hand-entered aspect ratios** | `aspect` isn't measured from the image; a wrong value mis-sizes the layout. |

### Code vs Figma

| Area | Code | Figma |
|---|---|---|
| Slider model | HSL only (Hue/Sat/Light) | **OKLCH / HSB / RGB** switch; FG/BG MIX with **L / C / H** |
| APCA meter | Readout only; meter always WCAG | APCA variant: ticks **Lc 45/60/75/90**, "Jump to Lc 75" |
| Mono font | DM Mono | **Geist Mono** |
| Specimen "Aa" | Manrope 600 (sans) | Serif in the `build` frame |
| Brand title | "Color Shift" | "Color Shift Simplified" |
| Drawer | Toggle button only | `grip` component (expanded true/false): suggests a drag handle |
| Photo nav | Tap/swipe/arrows | `icon / left`, `icon / right` components |
| Chip hover | none | hover state (text `#E5E0E0`) |

---

## 20. iOS porting notes

The full port plan lives in the iOS folder:
[`../../Color_Shift_Simplified_iOS/ios.md`](../../Color_Shift_Simplified_iOS/ios.md), with
sourced research in [`research/`](../../Color_Shift_Simplified_iOS/research/README.md). This section
only summarizes what the web side must know.

### Decisions (2026-11-24)
| Topic | Decision |
|---|---|
| Target | Web parity first; Figma-only features later |
| Platform | iPhone only, **iOS 26+**, Liquid Glass on floating controls and the drawer; Xcode 27 |
| Photos | Bundled in the app, **in exactly this repo's catalog order** (§14) |
| APCA | Real APCA 0.0.98G-4g on iOS (signed Lc); the web still uses `apcaApprox` (§8.7) |
| Drawer | Pushes the canvas, same spring (340 / 36 / 1.7) |
| Share link | iOS emits this web app's URL format `?fg=RRGGBB&bg=RRGGBB&photo=N` |
| Markdown | iOS exports a `.md` file, same as the web |
| Extras | Dynamic Type type scale (11pt minimum), haptics with an in-app toggle, About sheet |

### Contracts the web must keep (or change in both places)
- **Photo catalog order (§14):** `photo=N` is the 0-based catalog position. Reordering, inserting or
  removing photos breaks shared links between web and iOS.
- **Share-link format (§14):** param names, 6-hex without `#`, validation rules.
- **Color-math test vectors (§8.12):** both codebases must pass them.
- **Motion constants (§12, `src/motionConfig.ts`):** iOS mirrors the shipped defaults.

### Web → iOS mapping

| Web | iOS |
|---|---|
| `useState` in `App` | `@Observable final class AppModel`, owned with `@State` |
| Hex strings | `SRGB8` value type; HSL derived, never stored |
| CSS vars | View state / environment |
| Canvas `getImageData` | ImageIO thumbnail → 32×32 sRGB `CGContext`, same stride; small differences expected |
| `<img crossOrigin>` | Bundled JPEG files, downsampled with ImageIO |
| `input[type=color]` | `ColorPicker` (`supportsOpacity: false`), clamped to sRGB |
| `input[type=range]` | `Slider` (custom track for gradients) |
| Drawer | Root `VStack` with the deck inserted conditionally (push), not `.sheet` |
| Copy link | `UIPasteboard` + toast |
| Markdown download | `ShareLink` with a `Transferable` `.md` file |
| Deep link `?fg&bg&photo` | `onOpenURL`; `colorshift://` internally; Universal Links later (needs a domain you control, not `figma.site`) |
| Swipe / tap | `DragGesture` (35pt) and a single tap `Button` (fixes the double-advance) |
| Reduced motion | `accessibilityReduceMotion` |

### Web changes the port suggests (not yet made; see §19 and `ios.md` Q13)
Real APCA, muted text `#83858C`, the double-advance tap fix, and storing colors without HSL round-trips.

---

## 21. Glossary

| Term | Meaning |
|---|---|
| **Pair** | The foreground + background colors |
| **Specimen** | The "Aa" panel showing the pair |
| **Fallback pair** | Hand-picked colors per photo, used before or instead of sampling |
| **Derived pair** | Colors computed from the photo by `deriveFromPhoto` |
| **Mixer / control deck / drawer** | The slide-up controls panel |
| **Photo share** | Percentage of the canvas given to the photo |
| **WCAG ratio** | `(L1+0.05)/(L2+0.05)`; AA = 4.5, AAA = 7 for body text |
| **APCA / Lc** | Accessible Perceptual Contrast Algorithm; Lightness contrast value (approximated here) |
| **Jump** | Auto-adjusting foreground lightness to hit a contrast target |
| **Wave pulse** | The shimmer on selected theme chips |
| **DialKit** | Dev-only live parameter tuning panel |
| **Agentation** | Dev-only click-to-annotate feedback toolbar |
