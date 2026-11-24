# Color Shift for iOS — Port Plan

> How we take the Color Shift web build and ship it as a native **SwiftUI** iPhone app on the
> **App Store**.
>
> **Source of truth for behavior:** the web app's [`PROJECT_MAP.md`](PROJECT_MAP.md) (a snapshot copied into
> this repo; the canonical copy lives in the web repo at `Build Color Shift Simplified/PROJECT_MAP.md`). Section numbers
> below (e.g. "PM §8") point into it. This doc covers only **what changes for iOS and how we get there**.
>
> **Research (2026-11-24):** [`research/`](research/README.md), one file per topic with sources
> (SwiftUI patterns, Liquid Glass, Unsplash, color/APCA/sampling, accessibility/haptics, sharing,
> App Store release). Its findings are folded in throughout; §2a lists what changed and why.

---

## Contents

1. [Goals](#1-goals)
2. [Decisions made](#2-decisions-made) (incl. [2a. What the research changed](#2a-what-the-research-changed-2026-11-24))
3. [Open questions](#3-open-questions)
4. [v1 scope](#4-v1-scope)
5. [Architecture](#5-architecture)
6. [Feature-by-feature port](#6-feature-by-feature-port)
7. [Color engine](#7-color-engine)
8. [Layout & type](#8-layout--type)
9. [Motion](#9-motion)
10. [Haptics](#10-haptics)
11. [Accessibility](#11-accessibility)
12. [Sharing & deep links](#12-sharing--deep-links)
13. [Assets](#13-assets)
14. [Web bugs we fix rather than port](#14-web-bugs-we-fix-rather-than-port)
15. [Testing](#15-testing)
16. [App Store readiness](#16-app-store-readiness)
17. [Phases & milestones](#17-phases--milestones)
18. [Risks](#18-risks)
19. [Keeping web and iOS in sync](#19-keeping-web-and-ios-in-sync)

---

## 1. Goals

1. **Behavioral parity** with the web app: same photos, same color pair logic, same controls, same
   contrast math (except APCA, which gets more accurate).
2. **Feel native:** SwiftUI controls, haptics, Dynamic Type, VoiceOver, the system share sheet.
3. **Ship on the App Store**, with licensing, privacy, and review requirements handled up front.
4. **Leave room for the Figma roadmap** (OKLCH/HSB/RGB sliders, APCA meter) without building it in v1.

---

## 2. Decisions made

| # | Topic | Decision | Consequence |
|---|---|---|---|
| I1 | Target | **Web parity first.** Figma-only features are a later phase. | v1 uses HSL sliders, sans "Aa" (Manrope), DM Mono. |
| I2 | Platform | **iPhone only, iOS 26+** (changed from 17+ after research) | Native Liquid Glass with no fallback code; one look to design and test. Built with Xcode 27 / Swift 6.4. No iPad layout in v1. |
| I3 | Photos | **Bundle the 12 photos** in the app | Offline, instant, exact aspect ratios measured at build time. Permitted by the Unsplash License; credits required by our own rules (§13, §16). |
| I4 | APCA | **Real APCA 0.0.98G** | Lc values differ from the web's approximation and are **signed** (negative = light text on dark). The apca-w3 license concern raised in research was reviewed and set aside by the owner. |
| I5 | Drawer | **Push the canvas**, like the web | Custom bottom panel, not `.sheet`. Keeps the 340/36/1.7 spring. |
| I6 | v1 extras | **Larger type / Dynamic Type** and **haptics** | Type scale is redesigned (§8). Muted text fixed to pass AA. |
| I7 | Distribution | **App Store** | Privacy manifest, export compliance, screenshots, review notes. |
| I8 | Docs | This file lives in the iOS folder; behavior reference stays in the web `PROJECT_MAP.md` | Update both when behavior changes (§19). |
| I9 | Photo order | **Catalog order matches the web exactly** | `photo=N` in shared links is the 0-based position, so links round-trip between web and iOS. Never reorder one without the other. |
| I10 | Markdown | **Same as web: export a `.md` file** (not a clipboard copy) | `ShareLink` with a `Transferable` `.md` file (Save to Files, AirDrop, etc.). |

### 2a. What the research changed (2026-11-24)

| Area | Before | After | Source |
|---|---|---|---|
| Deployment target | iOS 17+ | **iOS 26+** (I2) | liquid-glass.md, app-store-release.md |
| Look | Custom dark UI | Same, plus **Liquid Glass** on floating controls and the drawer (can't be opted out of from the iOS 27 SDK) | liquid-glass.md |
| Toolchain | Xcode 16+ | **Xcode 27.2+**, Swift 6.4, Default Actor Isolation = MainActor; iOS 27 SDK required for uploads from April 2027 | app-store-release.md, swiftui-patterns.md |
| Color storage | Hex strings | **`SRGB8` struct**; HSL is derived, never stored (removes the web's drift) | color-apca-image-sampling.md |
| APCA | Formula sketch | Constants taken from apca-w3 0.0.98G-4g; Swift and Python ports reproduce every vector. License concern set aside (I4) | color-apca-image-sampling.md |
| Sampling | `CGContext` 32×32 | ImageIO thumbnail → 32×32 sRGB context → un-premultiply, off the main actor; tolerance tests vs the web, not exact | color-apca-image-sampling.md |
| Layout | Height-animated `VStack` | Root `VStack` with the drawer inserted conditionally + `onGeometryChange`; a small custom `Layout` for the photo/specimen split | swiftui-patterns.md |
| Spring | "~650 ms settle" | Mapping confirmed (response 0.444, damping 0.749, 2.88% overshoot); SwiftUI reports 0.88 s settle, within 0.1% by 0.56 s | swiftui-patterns.md |
| Haptics | All `.sensoryFeedback` cases | Only iPhone-playable cases; **in-app Haptics toggle** | accessibility-type-haptics.md |
| Accessibility | General list | Increase Contrast muted color, Differentiate Without Color glyphs, Smart Invert exclusions, 7 Nutrition Labels | accessibility-type-haptics.md |
| Share link | Web URL or `colorshift://` | **Web URL only** in shared content; photo order identical to web (I9); `.md` file export (I10) | sharing-deep-links.md |
| Photos | "Check the license" | Bundling is permitted; web IDs are CDN filenames that must be mapped to photo pages for credits; credit with UTM links | unsplash.md |
| New v1 screen | none | **About sheet**: photo credits, font licenses, privacy policy link, Haptics toggle (needed by 5.1.1(i), OFL, HIG) | several |
| Release | Generic checklist | Privacy policy URL also linked in-app, `CA92.1`, new age-rating descriptors (by 2027-01-12), 6.1" screenshots required, EU DSA trader status, 4.2 "too simple" risk, iPhone Duo | app-store-release.md |

---

## 3. Open questions

Questions you should answer before or during the phase noted. Each has a recommendation so work isn't blocked.

### Before Phase 0 (project setup)

| # | Question | Why it matters | Recommendation |
|---|---|---|---|
| Q1 | **App name and bundle ID?** e.g. "Color Shift", `com.<you>.colorshift` | Needed to create the Xcode project and the App Store record; the name must be unique on the store. | Check name availability in App Store Connect now. |
| Q2 | **Apple Developer Program membership?** Individual or organization? | Required for TestFlight and the App Store ($99/yr). Individual shows your legal name as seller; organization needs a D-U-N-S number. EU needs a DSA trader declaration. | Enroll as an individual **during Phase 0** (approval can take days); declare non-trader if it's a free hobby app (your call). |
| Q3 | ~~Separate git repo for iOS, or a monorepo?~~ | Affects how docs and the web reference are linked. | **Decided:** separate **public** repo `color_shift_simplified_ios` (this one). |
| Q4 | **Who maintains it, and with which tools?** | Xcode version, whether Claude Code drives changes, CI. | Xcode 27.2+ (needs Apple silicon, macOS 26.6+), Swift 6 language mode, Default Actor Isolation = MainActor, no CI until Phase 4. |

### Before Phase 2 (UI)

| # | Question | Why it matters | Recommendation |
|---|---|---|---|
| Q5 | **Portrait only, or landscape too?** | The web's desktop layout is side-by-side; iPhone landscape would need its own layout. | **Portrait only** in v1. |
| Q6 | **Dark UI only, or a light mode?** | The web is dark-only. Light mode doubles the token work. | Dark only (`.preferredColorScheme(.dark)`). |
| Q7 | **What is the canonical web URL for "Copy link"?** | Decided: iOS shares the **web URL** in the web's exact format (I9). Still needed: the fixed base URL, since the web uses whatever host it's on. | Use the published Figma Make URL until there's a custom domain. |
| Q8 | **Should the app open shared web links?** | Universal Links need a domain you control serving `apple-app-site-association`; `figma.site` can't. | v1: no. Later: a tiny site on your own domain that serves the file and forwards to Figma Make. |
| Q9 | ~~Markdown export on iOS~~ | **Decided (I10):** export a `.md` file, same as web. | Consider a shareable palette image later. |

### Before Phase 4 (release)

| # | Question | Why it matters | Recommendation |
|---|---|---|---|
| Q10 | **Free or paid?** Any in-app purchases? | Pricing, StoreKit, and review differ. | Free, no IAP in v1. |
| Q11 | **Analytics or crash reporting?** | Affects the privacy manifest and the App Privacy "nutrition label". | None in v1. Xcode Organizer crash logs are enough. |
| Q12 | **Localization?** | String catalog setup is cheapest at the start. | English only, but use a String Catalog from day one. |
| Q13 | **Fix the web bugs in the web app too?** (§14) | Keeps the two apps behaving the same. | Yes: fix in web, record in `PROJECT_MAP.md`. |
| Q14 | **Is there an app icon and a marketing screenshot style?** | Required for submission. | Layered Icon Composer icon from the jellyfish mark; screenshots from real pairs. |
| Q15 | **Where is the privacy policy hosted?** | Required URL for every app, and must be linked inside the app. | A short page on the web app's host or a GitHub Pages page: "Color Shift collects no data." |
| Q16 | **Add one feature beyond the web to reduce 4.2 risk?** | A single-screen app with 12 photos may be judged too simple. | Ship v1 as is with strong accessibility; if rejected, add PhotosPicker import first. |

---

## 4. v1 scope

### In (parity with web, PM §1 Features)
- F1 Photo browsing: tap, swipe, wraparound, fallback → derived pair, photo reveal.
- F2 Theme filtering: multi-select chips, All, wave-pulse shimmer.
- F3 Automatic pair from photo (sampling algorithm, PM §8.9).
- F4 Manual adjustment: system color picker, swap, FG/BG HSL sliders.
- F5 Contrast: WCAG ratio + meter + AA/AAA jumps; APCA readout (real APCA).
- F6 Share & export: share link, Markdown export, deep-link restore.

### In (iOS additions)
- Dynamic Type, with a type scale meeting Apple's minimum sizes (§8).
- Haptics (§10).
- VoiceOver labels, values, and actions throughout (§11).
- Liquid Glass on the floating controls and drawer (§5).
- **About sheet** (from the brand/identity area): photo credits with Unsplash links, font licenses,
  privacy policy link, Haptics on/off.

### Out (later phases)
- OKLCH / HSB / RGB slider models, APCA meter with Lc ticks (Figma).
- iPad and Mac layouts; landscape.
- Saved pairs or history, user photos, Unsplash API.
- Widgets, App Intents/Shortcuts.

---

## 5. Architecture

### Project
- Xcode project `ColorShift`, SwiftUI App lifecycle, **iOS 26.0** deployment target, Swift 6 language mode,
  Default Actor Isolation = MainActor with pure color math marked `nonisolated` (research/swiftui-patterns.md).
- Test target using **Swift Testing** (`import Testing`) for the engine; XCUITest for one smoke flow.
- **Liquid Glass:** regular, untinted glass only on the floating controls (mixer toggle, prev/next), grouped
  in one `GlassEffectContainer`, and one glass surface for the drawer. Chips, readouts and copy buttons stay
  plain (no glass on glass). See research/liquid-glass.md.
- No third-party dependencies in v1. (`motion` and DialKit aren't needed: SwiftUI has native springs.)

### Structure
```
ColorShift/
├── App/
│   └── ColorShiftApp.swift            @main, dark scheme, deep-link handling (onOpenURL)
├── Model/
│   ├── Theme.swift                    enum Theme: CaseIterable (Outdoors…Objects)
│   ├── Photo.swift                    struct Photo (file name, Unsplash page, photographer, handle, alt, theme, fallback, aspect)
│   └── PhotoCatalog.swift             the 12 photos in the web's exact order (I9), aspects measured from the files
├── Engine/
│   ├── SRGB8.swift                    8-bit sRGB value type, hex parse/format, HSL derived
│   ├── ColorMath.swift                luminance, WCAG contrast, tune, layoutShares (nonisolated)
│   ├── APCA.swift                     APCA 0.0.98G-4g (nonisolated)
│   └── PhotoSampler.swift             ImageIO thumbnail → 32×32 sRGB CGContext → derived pair (@concurrent)
├── State/
│   └── AppModel.swift                 @Observable: all web state (PM §6) + actions
├── Design/
│   ├── Tokens.swift                   colors, spacing, radii (PM §10)
│   ├── Typography.swift               Font extensions using Dynamic Type
│   └── Motion.swift                   drawer spring, photo reveal, chip wave, small transitions
├── Views/
│   ├── RootView.swift                 canvas + drawer layout (push behavior)
│   ├── SpecimenView.swift
│   ├── PhotoPanelView.swift           image, reveal, credit, gestures
│   ├── MixerToggle.swift              glass button
│   ├── AboutSheet.swift               credits, licenses, privacy link, haptics toggle
│   └── Deck/
│       ├── ControlDeckView.swift
│       ├── IdentityView.swift, ThemeChips.swift, ExportActions.swift
│       ├── ColorReadout.swift, SliderGroup.swift, ContrastBlock.swift
├── Resources/
│   ├── Photos/                        12 JPEGs as bundle files (not the asset catalog)
│   ├── AppIcon.icon                   Icon Composer layered icon
│   ├── Assets.xcassets                brand mark, custom SF Symbols
│   ├── Fonts/                         Manrope, DM Mono (+ OFL license files)
│   ├── Localizable.xcstrings
│   └── PrivacyInfo.xcprivacy
└── ColorShiftTests/
    ├── ColorMathTests.swift           PM §8.12 vectors
    ├── APCATests.swift                §7 vectors
    └── AppModelTests.swift            navigation, filtering, deep links
```

### State
`AppModel` mirrors the web's state one-to-one (PM §6), minus the dev-only motion state:

```swift
@Observable final class AppModel {
    var controlsOpen = false
    var selectedThemes: [Theme] = []          // ordered like the catalog when filtering
    var photoIndex = 0                        // index into visiblePhotos
    var foreground: SRGB8                     // 8-bit sRGB; hex and HSL are derived
    var background: SRGB8
    var hapticsEnabled = true                 // persisted in UserDefaults (CA92.1)
    var mode: ContrastMode = .wcag
    var loadedPhotoID: Photo.ID?              // drives the reveal
    private var preserveLinkedColors = false

    var visiblePhotos: [Photo] { … }
    var photo: Photo { visiblePhotos[photoIndex % visiblePhotos.count] }
    var wcag: Double { ColorMath.contrast(foreground, background) }
    var apca: Double { APCA.lc(text: foreground, background: background) }

    func navigate(_ direction: Int)
    func toggleTheme(_ theme: Theme?)        // nil = All
    func setChannel(_ role: ColorRole, _ channel: HSLChannel, _ value: Int)
    func jump(to target: Double)
    func swap()
    func photoDidLoad(_ image: CGImage)       // runs PhotoSampler unless preserveLinkedColors
    func apply(deepLink: URL)
    var shareURL: URL { … }
    var markdown: String { … }
}
```

Store colors as `SRGB8` (exactly what a hex string holds) and convert to `Color` only at the view edge.
HSL slider values are derived from `SRGB8`; a color is only rewritten from HSL when a slider actually moves.
Persist with `UserDefaults` from inside `AppModel` (saved when `scenePhase` goes to background), not
`@AppStorage`, which doesn't combine with `@Observable`. Pure engine types are `nonisolated` so tests call
them synchronously.

---

## 6. Feature-by-feature port

| Web (PM ref) | iOS implementation | Notes |
|---|---|---|
| Photo panel, cover-fit (PM §9) | ImageIO-downsampled `CGImage` → `Image(decorative:)`, `.scaledToFill().clipped().contentShape(Rectangle())` | `clipped()` doesn't limit the tap area, so `contentShape` is required. `accessibilityIgnoresInvertColors()`. |
| Photo reveal on load (PM §12 M2) | Custom `Transition` (opacity, scale 1.04→1, blur 8→0) on a view keyed `.id(photoIndex)` | Bundled images load instantly, so the reveal triggers on change. |
| Derive pair on load (PM §8.9) | `PhotoSampler.derivePair(from: cgImage)` in `.task(id: photo.id)` | Precompute and cache per photo; it's deterministic. |
| Tap photo → next | A plain-style `Button` covering the photo | Exactly one handler (fixes the double-advance, §14); optionally ignore taps until the reveal's completion. |
| Swipe | `DragGesture(minimumDistance: 10)`: translation.width > 35 → previous, < −35 → next | Taps and drags are separate gestures on iOS, so no click-after-touch problem. |
| ←/→, F keys | `.keyboardShortcut` (hardware keyboards) | Low priority on iPhone. |
| Mixer toggle (48×48) | `Button` with regular, untinted `.glassEffect` in a `GlassEffectContainer`, pinned bottom-leading | Keep 48pt (above the 44pt minimum). Don't tint with the photo colors. |
| Drawer push (PM §11) | Root `VStack { canvas; if open { deck.transition(.move(edge: .bottom)) } }` animated with the spring; `onGeometryChange` if the deck height is needed | Not `.sheet`/`presentationDetents` (those overlay). The deck is one glass surface; nothing inside it is glass. See §8. |
| Theme chips | Horizontal `ScrollView` of capsule buttons | Wave pulse via `KeyframeAnimator` (§9). |
| Color picker | `ColorPicker(selection:supportsOpacity: false)` bridged to hex | Convert `Color` → sRGB hex via `UIColor.getRed`. Clamp out-of-gamut (Display P3) values. |
| HSL sliders | `Slider(value:in:step: 1)` with custom gradient tracks | Integer steps, matching the web's rounding. |
| Swap | `Button` → `model.swap()` | Haptic. |
| WCAG/APCA switch | `Picker(.segmented)` or custom capsule segmented control | Custom to match the design. Readouts use `.contentTransition(.numericText(value:))`. |
| Contrast meter + ticks | Custom view: `Capsule` track, fill = `min(1, wcag/12)`, tick buttons at 37.5% / 58.3% | Ticks need 44pt hit areas even though they're drawn 1pt wide. |
| Jump button | `Button("Jump to AA/AAA")` | Haptic on success. |
| Copy link + toast | `UIPasteboard.general.url = model.shareURL` + "Copied" toast (1.6 s, like the web); optional `ShareLink` | Writing to the pasteboard never shows a permission prompt. |
| Markdown download | `ShareLink(item: MarkdownFile(...), preview: SharePreview(...))` with a `Transferable` `.md` file (I10) | Same as web: a file, not a clipboard copy. Save to Files, AirDrop, Mail. |
| Deep link restore | `.onOpenURL { model.apply(deepLink: $0) }`, one strict parser for both `colorshift://` and `https://` forms | Same validation as web (PM §14). Universal Links later need no code change. |
| Reduced motion | `@Environment(\.accessibilityReduceMotion)` | Reveal becomes a fade only; no wave; drawer uses a short ease. |

---

## 7. Color engine

Port PM §8 verbatim, **except APCA**.

### What carries over unchanged
`hexToRgb`, `rgbToHex`, `rgbToHsl` (integer rounding), `hslToHex`, `luminance`, `contrast`,
`tuneToContrast`, `layoutShares`, the contrast-meter geometry, and the sampling algorithm. Port notes:
PM §8.13 (rounding parity, modulo sign, the Swift API sketch).

### APCA 0.0.98G-4g (replaces `apcaApprox`)

Constants come verbatim from Myndex/apca-w3 `src/apca-w3.js`; the reference Swift port in
`research/color-apca-image-sampling.md` reproduces every vector below. Own the ~40-line port (there is no
canonical Swift package).

```
// Screen luminance (simple 2.4 power, NOT the WCAG piecewise curve)
Y = 0.2126729·R^2.4 + 0.7151522·G^2.4 + 0.0721750·B^2.4      // R,G,B = channel/255
if Y < 0.022 { Y += (0.022 − Y)^1.414 }                         // soft clamp near black

if |Ybg − Ytxt| < 0.0005 → Lc = 0
if Ybg > Ytxt (dark text on light):
    S = (Ybg^0.56 − Ytxt^0.57) × 1.14
    Lc = S < 0.1 ? 0 : (S − 0.027) × 100                         // positive
else (light text on dark):
    S = (Ybg^0.65 − Ytxt^0.62) × 1.14
    Lc = S > −0.1 ? 0 : (S + 0.027) × 100                        // negative
```

**Display:** show `round(|Lc|) Lc` to match the web's unsigned style, and optionally a polarity hint.
Keep the signed value in the model.

**Test vectors** (computed with the formula above; the first four match the published APCA reference values):

| Text | Background | Lc |
|---|---|---|
| `#888888` | `#FFFFFF` | 63.056 |
| `#FFFFFF` | `#888888` | −68.541 |
| `#000000` | `#AAAAAA` | 58.146 |
| `#AAAAAA` | `#000000` | −56.241 |
| `#000000` | `#FFFFFF` | 106.041 |
| `#FFFFFF` | `#000000` | −107.885 |
| `#F4C6D9` | `#16172B` | −78.254 |
| `#F2D27A` | `#1F3A5F` | −73.164 |
| `#777980` | `#111214` | −30.957 |

For comparison, the web's approximation gives `#F2D27A` on `#1F3A5F` = 71.08 (real: 73.16).

**WCAG:** the 0.03928 vs 0.04045 linearization threshold makes no difference for 8-bit values; use 0.04045.

### Sampling on iOS
- Decode a small thumbnail with `CGImageSourceCreateThumbnailAtIndex`, draw it into a 32×32 RGBA
  `CGContext` with an explicit **sRGB** color space and `premultipliedLast`, un-premultiply, then read every
  8th pixel exactly as PM §8.9 describes. Display P3 sources are converted and clipped to sRGB.
- Run it off the main actor (`@concurrent`). Don't use `CIAreaAverage` (it averages in linear light).
- Browsers choose their own resampling, so derived colors can differ slightly from the web. Test with a
  tolerance against web-captured pairs, not exact equality.
- Because photos are bundled, **precompute the derived pair for each photo once** (in memory at launch,
  or as a generated table checked by a test) instead of sampling on every navigation.

---

## 8. Layout & type

### iPhone layout (portrait)
The web's ≤ 900px layout, adapted:

```
┌─────────────────────┐
│ Photo  (35–47% of   │  ← layoutShares(aspect).mobile
│ canvas, by aspect)  │
├─────────────────────┤
│                     │
│   Specimen "Aa"     │
│[≡]                  │  ← 48pt mixer toggle, bottom-leading of canvas
├─────────────────────┤  ← drawer pushes the canvas up when open
│ Control deck        │     height = min(60% of screen, 544pt)
│ (scrolls)           │
└─────────────────────┘
```

- Respect safe areas. The photo can bleed under the status bar; the deck sits above the home indicator.
- Deck content follows the web's ≤ 560px single-column order: topline (identity + export icons),
  chips row, color readout, FG mix, BG mix, contrast block.
- Photo/specimen split: a small custom `Layout` taking the `layoutShares` fraction
  (`containerRelativeFrame` measures the screen, not the parent, so it won't follow the drawer).
- Specimen font size: `min(0.30 × width, 0.64 × height)` clamped to 80…512, plus 13.33, from the
  specimen's own geometry (PM §10). It is a fixed-size font, not Dynamic Type: its 80pt minimum already
  exceeds the largest AX5 text style (60pt).
- Test on every simulator size, including **iPhone Duo**; no fixed sizes, no orientation-based layout.

### Type scale (I6: larger type and Dynamic Type)
The web's 8–12px labels fall below Apple's minimum. Map each style to a Dynamic Type text style using
`Font.custom(_:size:relativeTo:)`, so they scale with the user's setting:

| Web style (px) | iOS base size (pt) | `relativeTo:` | Font |
|---|---|---|---|
| tick label (8) | 11 | `.caption2` | DM Mono |
| segment (8.32) | 11 | `.caption2` | DM Mono Medium |
| brand subtitle (8.64) | 11 | `.caption2` | DM Mono |
| field label (8.8) | 11 | `.caption2` | DM Mono |
| button (9.6) | 12 | `.caption` | DM Mono Medium |
| chip / toast / credit (9.92) | 12 | `.caption` | DM Mono Medium |
| section title (10.88) | 13 | `.footnote` | Manrope Bold |
| hex value (11.84) | 15 | `.subheadline` | DM Mono Medium |
| brand title (12.32) | 15 | `.subheadline` | Manrope Bold |
| contrast value (20) | 22 | `.title2` | DM Mono Medium |
| specimen | computed | none (fixed to the layout, not Dynamic Type) | Manrope SemiBold |

At accessibility sizes, let the deck scroll and let rows switch from `HStack` to `VStack` (`AnyLayout`).
Aim for AX5; if a control can't fit, clamp the deck at `.dynamicTypeSize(...accessibility3)`, which still
exceeds 200% and qualifies for the Larger Text nutrition label. Numeric readouts use `.monospacedDigit()`.

### Color fix
`text.muted` `#777980` on `#111214` is 4.31:1. Use **`#83858C`** (5.09:1) for iOS labels and verify
≥ 4.5:1 with `ColorMath.contrast` in a unit test. Under **Increase Contrast**, use about **`#A9ABB1`**
(8.16:1). (Propose the same change to the web, Q13.)

---

## 9. Motion

| Web (PM §12) | SwiftUI |
|---|---|
| M1 Drawer spring 340 / 36 / 1.7 | `.interpolatingSpring(mass: 1.7, stiffness: 340, damping: 36)`, or `.spring(response: 0.444, dampingFraction: 0.749)`. Verified: 2.88% overshoot; within 0.1% of rest by 0.56 s (SwiftUI's `settlingDuration` reports 0.88 s) |
| M2 Photo reveal: opacity 0→1, scale 1.04→1, blur 8→0, 600 ms `cubic-bezier(0.22,0.76,0.32,1)` | Custom `Transition` with `.timingCurve(0.22, 0.76, 0.32, 1, duration: 0.6)`; profile the blur on device |
| M3 Chip wave: 36pt band, 5 s loop, sweep 0–19%, fade in by 2.8%, out by 19% | `keyframeAnimator` with x-offset and opacity tracks, `repeating: true`; clip to `Capsule()` |
| M4 Specimen colors, 180 ms ease | `.animation(.easeInOut(duration: 0.18), value: model.foreground)` |
| M5 Toggle hover | Not applicable on iPhone. Use a pressed state (scale 0.96) instead. |
| M6 Toast, 180 ms, visible 1.6 s | `.transition(.opacity.combined(with: .move(edge: .bottom)))` + `Task.sleep` |

Put all constants in `Design/Motion.swift`, one source like the web's `motionConfig.ts`.
Under Reduce Motion: no reveal blur/scale (fade only, or none), no chip wave, drawer uses `.easeInOut(0.2)`.

---

## 10. Haptics

Using SwiftUI's `.sensoryFeedback`. Only cases that play on iPhone: `.increase`, `.decrease`, `.start`,
`.stop` and `.levelChange` do nothing on iOS (research/accessibility-type-haptics.md).

| Event | Feedback |
|---|---|
| Photo changes (tap/swipe) | `.selection` |
| Theme chip toggled | `.selection` |
| Drawer opens/closes | `.impact(weight: .light)` |
| Swap | `.impact(weight: .medium)` |
| Jump reaches its target | `.success` |
| Jump can't reach its target (`tune` falls short) | `.warning` |
| Slider reaches its end | `.alignment` |
| Contrast rises past 4.5 or 7 while dragging | `.impact(flexibility: .rigid, intensity: 0.6)` |
| Contrast falls below 4.5 while dragging | `.impact(flexibility: .soft, intensity: 0.5)` |
| Link copied | `.success` |

Respect the system haptics setting **and** add an in-app Haptics on/off toggle (HIG: haptics should be
optional). Don't fire them on every slider step.

---

## 11. Accessibility

- **Specimen:** `accessibilityLabel("Color specimen")`, `accessibilityValue("<fg> on <bg>, contrast 7.8 to 1")`.
- **Photo:** label = the photo's `alt`; hint "Double-tap for next photo"; custom actions "Next photo" and
  "Previous photo" (swipes aren't discoverable with VoiceOver).
- **Sliders:** label "Foreground hue", etc. (include the role, unlike the web); value "44 degrees" / "82 percent".
- **Contrast:** announce changes with `AccessibilityNotification.Announcement` after a jump
  ("Contrast now 4.6 to 1, passes AA").
- **Chips:** `.isSelected` trait for selected themes.
- **Drawer:** when closed, its content is removed or hidden from the accessibility tree; the toggle label
  says "Open/Close color controls".
- **Hit targets:** 44×44pt minimum (meter ticks especially).
- **Specimen** stays visible to VoiceOver and describes the colors in words (it is the main content).
- **Reduce Motion** (fade only, no wave), **Reduce Transparency** and **Increase Contrast** (glass adapts on
  its own; muted color → `#A9ABB1`), **Bold Text**, **Differentiate Without Color** (always show pass/fail
  glyphs next to AA/AAA), **Smart Invert** (`accessibilityIgnoresInvertColors()` on the photo and swatches).
- **Nutrition Labels** to claim in App Store Connect: VoiceOver, Voice Control, Larger Text, Dark Interface,
  Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion (verify each before claiming).

---

## 12. Sharing & deep links

- **Share link (v1):** keep the web format so links work in a browser:
  `https://<web-host>/?fg=RRGGBB&bg=RRGGBB&photo=N` (hex without `#`; `N` is the 0-based catalog
  position, identical to the web per I9). Needs the fixed production web URL (Q7).
- **Opening links in the app (v1):** custom scheme `colorshift://pair?fg=…&bg=…&photo=…` handled by
  `onOpenURL` (useful for testing and Shortcuts; Apple recommends Universal Links, and scheme collisions are
  undefined).
- **Later:** Universal Links on a custom domain with an `apple-app-site-association` file, so the same
  web link opens the app if installed. A `figma.site` host can't serve that file; a tiny site on a domain
  you own can serve it and forward everything else to the Figma Make URL. The `colorshift://` scheme is
  internal only and never appears in anything the user shares.
- **Validation** is the same as the web: 6-hex colors (case-insensitive, stored uppercase), photo 0–11,
  and skip the next derivation when both colors are valid.
- **Photo index meaning:** always the **full-catalog** index in links, independent of the filter (§14).

---

## 13. Assets

| Asset | Plan |
|---|---|
| **Photos** | The web's 12 IDs are image-CDN filenames, not photo IDs: first map each to its unsplash.com photo page and record the photographer's name and handle. Download from the photo page at about 2400px on the long edge; ship as high-quality JPEG **bundle files** (not the asset catalog) so ImageIO can downsample; keep the web's order (I9). Record each **measured** aspect ratio. Expect roughly 6–12 MB. |
| **Credits** | "Photo by <Name> on Unsplash", linking to the photographer and Unsplash with `utm_source=color_shift&utm_medium=referral`; on the credit chip and in the About sheet. |
| **Fonts** | Manrope (variable or static 400–700) and DM Mono (400, 500) from Google Fonts. Both are SIL OFL 1.1: bundle them and include the license texts in Settings → Acknowledgements or an About screen. Register them in `Info.plist` (`UIAppFonts`). |
| **Icons** | Export the 5 stroke icons (PM §9) as custom SF Symbols (via the SF Symbols app template) so they scale with Dynamic Type and weight. |
| **Brand mark** | Jellyfish as a vector PDF asset. |
| **App icon** | Layered icon built in Icon Composer from the jellyfish mark on `#111214`, with default, dark and tinted (Liquid Glass) appearances. |

---

## 14. Web bugs we fix rather than port

| Web issue (PM §19) | iOS handling |
|---|---|
| Tap may advance two photos on touch devices | One tap gesture, one action |
| Share link index vs filtered index | Links always use the full-catalog index; the model maps it explicitly |
| HSL round-trip drift | Keep integer HSL for parity, but **don't** rewrite a color from HSL unless a slider actually moved |
| `tuneToContrast` can silently miss | Return `(color, reachedTarget)`; show "Can't reach AAA with this hue" + warning haptic |
| APCA approximation | Real APCA (§7) |
| Muted text fails AA | New muted color (§8) |
| Clipboard errors unhandled | N/A (`UIPasteboard` doesn't throw); toast always confirms |
| Tiny type | New type scale (§8) |

---

## 15. Testing

| Layer | What | How |
|---|---|---|
| Engine | Every PM §8.12 vector; APCA vectors (§7, tolerance 0.001); `tune` reaches or reports a miss | Swift Testing, parameterized `@Test(arguments:)` |
| Sampler | Each bundled photo yields a valid pair that's ≥ 4.5:1 or reports a miss; within a small tolerance of the web's derived pair | Unit test over the catalog |
| Model | Navigation wraparound, filtering resets, All semantics, deep-link parsing and validation, `preserveLinkedColors` skip-once, swap, jump | Unit tests on `AppModel` |
| Tokens | Every text/background token pair used in the UI is ≥ 4.5:1 | Unit test using `ColorMath.contrast` |
| UI | Smoke flow: launch → tap photo → open drawer → select theme → jump to AA → share | XCUITest |
| Visual | Light check against the web at the same photo and pair | Xcode Previews + screenshots |
| Accessibility | VoiceOver pass, AX5 Dynamic Type, Reduce Motion, Increase Contrast | Manual checklist, Accessibility Inspector, `performAccessibilityAudit()` in the UI test |
| Devices | Smallest iPhone, largest iPhone, iPhone Duo | Simulators |

---

## 16. App Store readiness

- **Photo licensing:** bundling is permitted under the Unsplash License (downloaded photos aren't bound by
  the API's hotlinking rule). Limits: don't sell unaltered copies, don't build a competing photo service, and
  the license doesn't cover recognizable people, brands or artworks in a photo, so check the 12 for those.
  Keep credits visible (§13). Not legal advice.
- **Fonts:** OFL, include license text (§13).
- **Privacy:** no data collection. Add `PrivacyInfo.xcprivacy` declaring no tracking, no collected data,
  and `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (the haptics toggle uses it). App
  Privacy answer: "No, we do not collect data". A privacy policy URL is still required, and it must also be
  linked inside the app (About sheet, Q15).
- **Export compliance:** no non-exempt encryption → `ITSAppUsesNonExemptEncryption = NO`.
- **Age rating:** 4+ under the new tiers (4+/9+/13+/16+/18+). Answer the new questionnaire descriptors,
  mandatory for all apps by 2027-01-12.
- **Content rights:** declare third-party content; rights come from the Unsplash License.
- **Review notes:** explain that colors are generated from bundled photos, credited to Unsplash photographers.
- **Store assets:** 6.1" Dynamic Island screenshots (1206×2622) required, 6.9" recommended; iPhone Duo
  screenshots required from April 2027 for builds on the iOS 27.1+ SDK. Description, keywords, support URL,
  privacy policy URL.
- **Account:** EU DSA trader declaration (Q2). Accessibility Nutrition Labels (§11) are optional but cheap.
- **Toolchain deadline:** uploads must use the iOS 27 SDK from April 2027 (Xcode 27 already does).
- **Name:** check that "Color Shift" is available (Q1).

---

## 17. Phases & milestones

| Phase | Deliverable | Exit criteria |
|---|---|---|
| **0. Setup** | Developer Program enrollment started; app name checked; Xcode 27 project (iOS 26, MainActor default isolation), repo, folders, fonts registered, tokens, dark scheme, String Catalog | App launches to a blank `#111214` screen; fonts render; build passes |
| **1. Engine** | `SRGB8`, `ColorMath`, `APCA`, `PhotoSampler`; photo-page mapping + credits; `PhotoCatalog` with bundled photos in web order | All PM §8.12 and §7 vectors pass; every catalog photo derives a pair within tolerance of the web |
| **2. Canvas** | `AppModel`, `RootView`, split `Layout`, specimen, photo panel, tap/swipe, reveal transition, glass mixer toggle, drawer push with the spring | Browsing works end to end on all sizes incl. Duo; drawer animation matches the web side by side |
| **3. Deck** | Identity, chips with wave, export actions, color readout + picker, sliders, contrast block, jumps | Every web control works; model unit tests pass |
| **4. Native polish** | Dynamic Type scale, haptics + toggle, VoiceOver, Reduce Motion / Increase Contrast / Smart Invert, deep links, copy link, Markdown file export, toast, About sheet | Accessibility checklist passes (AX5 or the AX3 clamp); `performAccessibilityAudit` passes; UI smoke test passes |
| **5. Release** | Icon Composer icon, screenshots (6.1", 6.9"), privacy manifest, privacy policy page, age rating, content rights, Nutrition Labels, DSA declaration, TestFlight, submission | TestFlight build reviewed by you; submitted |
| **6. Next (post-v1)** | Figma features: OKLCH/HSB/RGB sliders, APCA meter with Lc ticks, drawer grip; iPad layout; saved pairs | Separate plan |

Suggested order inside each phase: write the test, port the logic, then build the view.

---

## 18. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Recognizable people, brands or artworks in a bundled photo (not covered by the Unsplash License) | Takedown | Review the 12 photos in Phase 1; swap any doubtful ones (and in the web too, to keep I9) |
| APCA license (web-only, non-commercial terms) | Takedown request | Owner accepted the risk (I4); WCAG-only build is a quick fallback |
| Derived pairs differ from the web | Users comparing both see different colors | Accept; document; or ship the precomputed web pairs as data |
| Pushing the canvas with a spring causes layout jank | Choppy animation | Animate the drawer insertion; keep the specimen font size from re-laying out text every frame (cache by size bucket); profile the reveal blur |
| Liquid Glass bugs (taps not registering on glass, dark rendering on device, too many glass views) | Visual or input glitches | Few glass views in one container; explicit `contentShape`; test on a real device early |
| Dynamic Type at AX sizes breaks the deck | Clipped controls | Scrollable deck, wrapping rows, test at AX5 early (Phase 3) |
| Real APCA numbers confuse users comparing with the web | Inconsistent readouts | Update the web to real APCA too (Q13) |
| App name taken | Rebrand late | Check in Phase 0 (Q1) |
| Rejected as too simple (Guideline 4.2) | Delayed release | Polish accessibility; consider PhotosPicker import or palette-image export (research/app-store-release.md) |
| iPhone Duo and new screen sizes crop the photo | Broken layout, extra screenshots | Test on every simulator size including Duo; no fixed sizes |

---

## 19. Keeping web and iOS in sync

- The **web `PROJECT_MAP.md`** stays the behavior reference. When iOS intentionally diverges (APCA,
  type scale, bug fixes), record it in this file under §2 or §14 **and** add a line to PM §19.
- When web behavior changes, check this plan's matching section.
- Shared test vectors (PM §8.12 and §7 here) must pass in both codebases. If one changes, update the vectors.
