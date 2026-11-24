# Research index

Pre-Swift research for the Color Shift iOS port (see `../ios.md`). Gathered 2026-11-24 by parallel
research agents; each file has a TL;DR, open questions, items marked **unverified**, and a numbered
Sources list with the URLs used. Re-check dates and versions before relying on them.

| File | Topic |
|---|---|
| [swiftui-patterns.md](swiftui-patterns.md) | `@Observable` state, Swift 6 MainActor defaults, push-drawer layout, split `Layout`, spring mapping (verified), photo-reveal transition, tap handling, persistence, project structure, Swift Testing |
| [liquid-glass.md](liquid-glass.md) | iOS 26 Liquid Glass APIs and HIG, iOS 27 changes, compatibility opt-out removal, iOS 17 fallbacks, which Color Shift controls get glass |
| [unsplash.md](unsplash.md) | Official picker SDK status, API rules, License vs API terms, bundling vs hotlinking, attribution checklist |
| [color-apca-image-sampling.md](color-apca-image-sampling.md) | APCA 0.0.98G-4g constants + Swift port (reproduces all vectors), **APCA license issue**, WCAG, sRGB handling, 32×32 sampling, HSL drift |
| [accessibility-type-haptics.md](accessibility-type-haptics.md) | Dynamic Type table, minimum sizes, VoiceOver, system settings, haptics mapping (iOS-playable only), Accessibility Nutrition Labels, audits |
| [sharing-deep-links.md](sharing-deep-links.md) | ShareLink/pasteboard, `colorshift://`, universal links + AASA hosting, web-compatible Copy link |
| [app-store-release.md](app-store-release.md) | Xcode 27 / SDK deadlines, Developer Program, privacy manifest, age rating, screenshots (incl. iPhone Duo), TestFlight, 4.2 risk, release checklist |

## Findings that change `ios.md`

Owner decisions (2026-11-24): APCA license concern set aside (keep real APCA); target **iOS 26**;
photo order matches the web exactly; Markdown exports a `.md` file like the web. All recorded in `ios.md` §2.

1. **APCA license (blocker to resolve):** apca-w3 is licensed for web content only and bars commercial
   use without a signed agreement. Ask Myndex for permission, or ship WCAG-only / approximate APCA.
2. **Deployment target:** research recommends **iOS 26** (≈86% of recent iPhones, June 2026; single
   Liquid Glass look). iOS 17 remains workable with a material fallback. Owner decision.
3. **Liquid Glass is unavoidable:** `UIDesignRequiresCompatibility` is ignored when building with the
   iOS 27 SDK, required for uploads from April 2027.
4. **Haptics:** `.increase/.decrease/.start/.stop/.levelChange` don't play on iOS. Use `.selection`,
   `.impact`, `.alignment`, `.success`, `.warning`. Add an in-app Haptics toggle.
5. **Copy link** should emit the web HTTPS URL (`?fg=RRGGBB&bg=RRGGBB&photo=<0-based index>`), so the
   iOS photo order must match the web exactly. Needs the canonical web base URL. Universal links need
   a domain you control (not `figma.site`).
6. **Web "Markdown" downloads a `.md` file**, it doesn't copy. Decide which iOS mirrors.
7. **Spring:** mapping confirmed (response 0.444, dampingFraction 0.749, 2.88% overshoot); SwiftUI
   reports settling at ~0.88s vs the web's ~650ms estimate (within 0.1% by 0.56s).
8. **Store as sRGB8, derive HSL** (fixes the web's round-trip drift, which is from rounding).
9. **Unsplash:** the web's 12 IDs are image-CDN filenames, not photo IDs; map each to its photo page
   for photographer credits. Bundling under the Unsplash License is fine.
10. **Review risk 4.2 (minimum functionality):** consider PhotosPicker import, palette image export,
    favorites. Privacy policy URL is required even with no data collection.
11. **iPhone Duo:** test full-bleed photo layout; Duo screenshots required from April 2027 for 27.1+ SDK builds.
