# Color Shift iOS — PRD & Build Loop

> Product requirements for the native iPhone app, written as an **ordered task list an agent can loop
> through**, one task per iteration. The plan behind it is [`ios.md`](ios.md); web behavior is defined in
> [`PROJECT_MAP.md`](PROJECT_MAP.md) ("PM §n"); evidence is in [`research/`](research/README.md).
> When this file and `ios.md` disagree, fix whichever is wrong in the same commit.

---

## 0. How to run the loop

Start an iteration with, for example: `/loop Work the next task in prd.md` (self-paced), or run one
iteration by hand with "Do the next prd.md task".

**Each iteration:**
1. Read §0, §1 (Project facts) and the §6 Progress log. Run `git status`; if the tree is dirty from a
   previous failed iteration, finish or revert that work first.
2. Pick the **first** task in §5 whose box is `[ ]`, that is **not** tagged `HUMAN`, and whose
   `Depends` tasks are all `[x]`. If none qualify, stop and report which `HUMAN` tasks are blocking.
3. Read the task's `Refs` before writing code. Follow `ios.md` and this repo's `CLAUDE.md` (once T-002 exists).
4. Implement **only that task**. Write tests first where the task lists tests.
5. Run every command in the task's `Verify` line (see §4 for the standard commands). All must pass.
6. If it passes: tick the box (`[x]`), append one line to §6, and commit with message
   `T-0xx: <task title>` (staged by explicit path). At the end of a phase (last task of a phase ticked),
   `git push`.
7. If it can't pass after a reasonable attempt, or needs a decision: set the box to `[!]`, add a
   `Blocked:` note under the task, log it in §6, commit, and **stop the loop** so the owner can decide.

**Rules:**
- Never tick a box without a passing `Verify`. Never weaken a test to make it pass.
- Don't start the next task in the same iteration.
- `HUMAN` tasks are done by the owner. The loop may prepare for them (drafts, checklists) but never ticks
  them, never downloads files, creates accounts or submits anything.
- Placeholders for missing human input (bundle ID, web URL, privacy URL) live in one place,
  `ColorShift/App/AppConfig.swift`, marked `// TODO(H-0x)`.
- No third-party Swift dependencies. XcodeGen is the only extra tool (T-001).
- Keep `PROJECT_MAP.md` read-only here; it's a snapshot of the web repo.

---

## 1. Project facts

| Fact | Value | Source |
|---|---|---|
| App name | **KDP Color** (App Store and home screen); the in-app brand stays "Color Shift" | ios.md Q1, H-01 |
| Bundle ID | `com.kierandelpasqua.colorshift` (tests: `.tests`, `.uitests`) | ios.md Q1, H-01 |
| Developer Program | Not enrolled yet (H-02, later); EU DSA status: **non-trader** | ios.md Q2, H-02 |
| Web base URL for share links | _TBD (H-03)_ | ios.md Q7 |
| Privacy policy URL | `https://kierandelpasqua.github.io/color_shift_simplified_ios/privacy-policy.html` (text: docs/privacy-policy.md; live once GitHub Pages serves `main` → `/docs`) | ios.md Q15, H-07 |
| Deployment target | iOS 26.0, iPhone only, portrait, dark | ios.md I2, Q5, Q6 |
| Toolchain | Xcode 27.2 (27B52), Swift 6 language mode, Default Actor Isolation = MainActor | ios.md §5 |
| Simulators | iPhone 18 Pro (default), iPhone 17e (small), iPhone 18 Pro Max (large), iPhone Duo | `xcrun simctl list` |
| URL scheme | `colorshift` | ios.md §12 |

---

## 2. Product requirements

### 2.1 Problem and users
Designers and developers want a fast way to find good-looking, accessible foreground/background color
pairs. Color Shift pulls a pair from a photograph, lets you tune it, and tells you whether it passes
contrast. The web app does this; the iOS app brings it to iPhone with native feel and accessibility.

### 2.2 Goals
- G1 **Parity:** every web feature F1–F6 (PM §1) works the same, with the same photos, order and math.
- G2 **Native:** SwiftUI controls, Liquid Glass, haptics, Dynamic Type, VoiceOver.
- G3 **Shippable:** passes App Review on the first or second submission.

### 2.3 Non-goals (v1)
OKLCH/HSB/RGB sliders, APCA meter with Lc ticks, iPad/Mac/landscape, saved pairs, user photos,
Unsplash API, widgets, Shortcuts, analytics, accounts, light mode, localization beyond English.

### 2.4 Functional requirements

| ID | Requirement | Acceptance |
|---|---|---|
| FR1 | Browse 12 bundled photos in the web's order; tap = next, swipe left/right = next/previous, wraparound; while the drawer is open, tapping or swiping the photo or tapping the specimen closes it instead (PM §13) | One tap advances exactly one photo; swipe threshold 35pt |
| FR2 | Photo reveal on change (opacity, scale 1.04→1, blur 8→0, 0.6 s) | Matches PM §12 M2; fade only under Reduce Motion |
| FR3 | Derive a fg/bg pair from each photo (PM §8.9); show the hand-picked fallback first | Each photo yields a pair; within tolerance of the web |
| FR4 | Theme filter chips, multi-select plus "All"; selected chip plays the wave | Filtering semantics match PM §6/§13 |
| FR5 | Edit colors with the system color picker and FG/BG HSL sliders; swap | Integer HSL steps; no drift unless a slider moves |
| FR6 | Contrast: WCAG ratio + meter with AA/AAA ticks; APCA Lc (real 0.0.98G); Jump to AA/AAA | Vectors pass; a jump that can't reach its target says so |
| FR7 | Drawer opens from the mixer toggle and pushes the canvas up with the 340/36/1.7 spring | Not a sheet; canvas resizes |
| FR8 | Copy link copies the web URL `?fg=RRGGBB&bg=RRGGBB&photo=N` (N = 0-based catalog index); toast "Copied" 1.6 s | Link opens the same pair and photo on the web |
| FR9 | Markdown exports a `.md` file via the share sheet | Same content as the web's download |
| FR10 | Open `colorshift://pair?...` links in the app; the parser also accepts the `https://<web>/?...` form, ready for Universal Links later (ios.md Q8) | Same validation as web; derivation skipped once |
| FR11 | About sheet: photo credits with Unsplash links (UTM), font licenses, privacy policy link, Haptics toggle | All links work; toggle persists |
| FR12 | Haptics per ios.md §10, off when the toggle is off | Only iPhone-playable feedback types |

### 2.5 Non-functional requirements

| ID | Requirement |
|---|---|
| NFR1 | iOS 26+, iPhone only, portrait, dark appearance |
| NFR2 | All UI text ≥ 11pt base, scales with Dynamic Type to AX5 (or clamps at AX3 where it can't fit) |
| NFR3 | Every text/background token pair ≥ 4.5:1; muted `#83858C`, `#A9ABB1` under Increase Contrast |
| NFR4 | Hit targets ≥ 44×44pt |
| NFR5 | VoiceOver can do everything a sighted user can (labels, values, actions) |
| NFR6 | Honors Reduce Motion, Reduce Transparency, Increase Contrast, Bold Text, Differentiate Without Color, Smart Invert |
| NFR7 | No network calls, no data collection, privacy manifest with `CA92.1` |
| NFR8 | Launch to interactive < 1 s on iPhone 18 Pro simulator; drawer and reveal animate without dropped frames |
| NFR9 | Layout works on iPhone 17e, 18 Pro, 18 Pro Max and Duo; no fixed screen sizes |
| NFR10 | Swift 6 strict concurrency with zero warnings in the app target |

---

## 3. Definition of done (v1)
All `T-` tasks `[x]`; all `HUMAN` tasks done; test suite green; UI smoke test and accessibility audit
green on iPhone 18 Pro and iPhone Duo; build uploaded to TestFlight and submitted for review.

---

## 4. Standard commands

```bash
# Generate the Xcode project from project.yml (after any change to it)
xcodegen generate

# Build
xcodebuild -project ColorShift.xcodeproj -scheme ColorShift \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build | xcbeautify || true   # xcbeautify optional

# Unit tests (Swift Testing)
xcodebuild -project ColorShift.xcodeproj -scheme ColorShift \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:ColorShiftTests test

# UI tests
xcodebuild -project ColorShift.xcodeproj -scheme ColorShift \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:ColorShiftUITests test

# Screenshot on a simulator (after installing and launching the app)
xcrun simctl io booted screenshot docs/screens/<name>.png
```

Shorthand used in tasks: **BUILD**, **UNIT**, **UI** = the commands above; **BUILD@Duo** = BUILD with
`name=iPhone Duo`. Don't pipe through `|| true` when checking for failure; it's only for readable logs.

---

## 5. Tasks

Status: `[ ]` todo · `[x]` done · `[!]` blocked (see note) · `HUMAN` = owner does it.

### Phase 0 — Setup

#### H-01 · Choose the app name and bundle ID `HUMAN`
- [x] Check name availability in App Store Connect; record name and bundle ID in §1. (ios.md Q1)

#### H-02 · Enroll in the Apple Developer Program `HUMAN`
- [ ] Individual enrollment ($99/yr); decide EU DSA trader status. (ios.md Q2, research/app-store-release.md)

#### H-03 · Provide the published web URL `HUMAN`
- [ ] Record the Figma Make URL (or custom domain) in §1. (ios.md Q7)

#### H-04 · Add the fonts `HUMAN`
- [x] Download Manrope (400–700) and DM Mono (400, 500) from Google Fonts with their OFL license files
  into `ColorShift/Resources/Fonts/`. (ios.md §13)

#### T-001 · Generate the Xcode project with XcodeGen
- [x] **Depends:** none · **Refs:** ios.md §5, §1 of this file
- **Do:** `brew install xcodegen` if missing. Write `project.yml` with targets `ColorShift` (iOS app,
  iOS 26.0, iPhone only, portrait, `UIUserInterfaceStyle = Dark`), `ColorShiftTests` (unit, Swift
  Testing) and `ColorShiftUITests`. Settings: Swift 6 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor`, approachable concurrency on, strict concurrency complete, warnings as errors in the app
  target. Info.plist: `CFBundleURLTypes` (`colorshift`), `ITSAppUsesNonExemptEncryption = NO`,
  `UIAppFonts` (empty until T-004). Create the folder structure from ios.md §5 with a `ColorShiftApp`
  showing a full-screen `#111214`. Add `AppConfig.swift` with placeholder bundle ID, web URL and privacy
  URL (`// TODO(H-01/H-03/H-07)`). Add `ColorShift.xcodeproj/` to `.gitignore` (regenerated).
- **Verify:** `xcodegen generate` → BUILD → UNIT (one trivial passing `@Test`).

#### T-002 · Repo CLAUDE.md
- [x] **Depends:** T-001 · **Refs:** §0, §4
- **Do:** Write `CLAUDE.md`: what the repo is, the §4 commands, the loop rules (point to prd.md §0),
  architecture summary from ios.md §5, conventions (no dependencies, `nonisolated` engine, colors as
  `SRGB8`, motion constants only in `Motion.swift`, keep web photo order).
- **Verify:** BUILD still passes; file links resolve.

#### T-003 · Design tokens, typography and motion constants
- [x] **Depends:** T-001 · **Refs:** ios.md §8, §9; PM §10, §12
- **Do:** `Tokens.swift` (colors incl. muted `#83858C` and its Increase Contrast `#A9ABB1`, spacing,
  radii), `Typography.swift` (the ios.md §8 type scale via `Font.custom(_:size:relativeTo:)`, falling
  back to system fonts until H-04), `Motion.swift` (drawer spring, reveal curve/duration, chip wave
  timings, color 0.18 s, toast 1.6 s, reduce-motion variants). Add an empty `Resources/Localizable.xcstrings`
  String Catalog (ios.md Q12).
- **Verify:** BUILD; UNIT includes a test that every token text/background pair is ≥ 4.5:1 (can use a
  temporary WCAG helper until T-011; replace with `ColorMath` then).

#### T-004 · Register fonts
- [x] **Depends:** T-003, H-04 · **Refs:** ios.md §13
- **Do:** Add font files to the target and `UIAppFonts`; switch `Typography` to the bundled fonts.
- **Verify:** BUILD; UNIT test asserts `UIFont(name:size:)` resolves each PostScript name.

### Phase 1 — Engine

#### T-010 · `SRGB8` value type and HSL
- [x] **Depends:** T-001 · **Refs:** ios.md §5 State, §7; PM §8.1–8.4, §8.12, §8.13
- **Do:** `SRGB8` (r, g, b `UInt8`), hex parse (with/without `#`, case-insensitive, reject invalid),
  hex format (uppercase), `Color` conversion, HSL derive and HSL→`SRGB8` with the web's integer
  rounding and hue modulo. `nonisolated`, `Sendable`, `Hashable`, `Codable`.
- **Verify:** UNIT: every PM §8.12 hex/RGB/HSL vector, invalid-input cases, round-trip of all 4,096
  12-bit grid colors through hex.

#### T-011 · `ColorMath`
- [x] **Depends:** T-010 · **Refs:** PM §8.5, §8.6, §8.8, §8.10, §8.11, §8.12
- **Do:** WCAG luminance (0.04045), `contrast`, `tuneToContrast` returning `(color, reachedTarget)`,
  `layoutShares`, meter geometry.
- **Verify:** UNIT: all PM §8.12 vectors for these functions; a case where tune can't reach 7:1 reports
  `reachedTarget == false`.

#### T-012 · APCA 0.0.98G-4g
- [x] **Depends:** T-010 · **Refs:** ios.md §7; research/color-apca-image-sampling.md
- **Do:** `APCA.lc(text:background:)` with the apca-w3 constants; signed result.
- **Verify:** UNIT: the 9 vectors in ios.md §7, tolerance 0.001.

#### T-013 · Photo model and catalog (metadata)
- [x] **Depends:** T-010 · **Refs:** PM §14; ios.md I9, §13
- **Do:** `Theme`, `Photo` (id = web image ID, file name, theme, alt, fallback fg/bg, aspect,
  photographer name/handle/page URL as optionals until H-05), `PhotoCatalog.all` in **exactly** the
  web's order.
- **Verify:** UNIT: 12 photos; IDs equal the web list in order (hard-coded expected array copied from
  the web's `src/App.tsx` photo URLs; PM §14 doesn't list them); every fallback pair ≥ 4.5:1 or documented.

#### H-05 · Map, review and download the photos `HUMAN`
- [x] For each of the 12 web IDs, find its unsplash.com photo page and photographer (the loop may
  draft this table in `docs/photo-sources.md` beforehand). Check each photo for recognizable people,
  brands or artworks. Download ~2400px JPEGs into `ColorShift/Resources/Photos/<id>.jpg`.
  (ios.md §13, §16; research/unsplash.md)

#### T-014 · Photo credits and measured aspects
- [x] **Depends:** T-013, H-05 · **Refs:** ios.md §13
- **Do:** Fill photographer fields from `docs/photo-sources.md`; build credit URLs with
  `utm_source=color_shift&utm_medium=referral`; replace hand-entered aspects with ones measured from the
  bundled files (ImageIO, no full decode).
- **Verify:** UNIT: every photo has a credit and a file in the bundle; aspects within 0.5% of measured.

#### T-015 · `PhotoSampler`
- [x] **Depends:** T-011, T-014 · **Refs:** ios.md §7 Sampling; PM §8.9; research/color-apca-image-sampling.md
- **Do:** ImageIO thumbnail → 32×32 RGBA sRGB `CGContext` (`premultipliedLast`) → un-premultiply →
  PM §8.9 algorithm → `ColorPair`. `@concurrent`, `nonisolated`. Cache results per photo.
- **Verify:** UNIT: synthetic solid and two-tone images give expected pairs; every catalog photo
  derives a pair that's ≥ 4.5:1 or reports a miss.

#### T-016 · Web parity fixture for derived pairs
- [x] **Depends:** T-015 · **Refs:** ios.md §15
- **Do:** Run the web app locally (see the web repo's CLAUDE.md), and for each photo record the derived
  `--foreground`/`--background` into `ColorShiftTests/Fixtures/web-derived-pairs.json`.
- **Verify:** UNIT: each iOS-derived color is within ΔE (or per-channel ±6) of the web value; failures
  listed by photo. If many fail, set `[!]` with the numbers rather than loosening the tolerance.

### Phase 2 — Canvas

- **Blocked:** iOS vs web (Chrome 158, the web's own code on the web's AVIF images) per-channel Δ, max of bg/fg, in
  catalog order: 11, 4, 7, 68, 14, 3, 4, 9, 1, 12, 2, 2 → 6 of 12 over ±6. A sweep of ImageIO thumbnail sizes
  (full/512/256/128/64) × CG interpolation (none/low/medium), on both the bundled JPEGs and the web's own 1800px
  images, never got below 4 failures (worst 69). Cause: the algorithm keeps the **single** most saturated of 128
  pixels, so tiny resampling differences change which pixel wins (photo 3: iOS #4096B7 vs web #267A73). Fixture and
  test are committed; the per-photo test is `.disabled` until the owner decides (no tolerance change).
- **Resolved (owner, 2026-11-25):** iOS uses the web's captured pairs (`Photo.derived`, from the fixture) and keeps
  `PhotoSampler` as the fallback for photos without one. The test now checks what the app applies.

#### T-020 · `AppModel`
- [x] **Depends:** T-011, T-012, T-013 · **Refs:** ios.md §5 State; PM §6
- **Do:** `@Observable` model: controls open, selected themes, photo index, fg/bg `SRGB8`, mode, derived
  `wcag`/`apca`, `preserveLinkedColors`, `hapticsEnabled` (UserDefaults, saved on background). Actions:
  `navigate`, `toggleTheme`, `setChannel`, `jump`, `swap`, `photoDidDerive`, `apply(deepLink:)`,
  `shareURL`, `markdown`.
- **Verify:** UNIT: wraparound, filter reset and All semantics, deep-link parse/validate (good, bad hex,
  out-of-range photo), skip-derivation-once, swap, jump reached/missed, shareURL format with
  full-catalog index, markdown matches the web's output for a fixed pair.

#### T-021 · Root layout and specimen
- [x] **Depends:** T-020, T-003 · **Refs:** ios.md §8; PM §10, §11
- **Do:** `RootView` (root `VStack`, drawer slot), `SplitLayout` custom `Layout` using `layoutShares`,
  `SpecimenView` with geometry-based fixed-size "Aa" (80…512 + 13.33), colors animated 0.18 s.
- **Verify:** BUILD; BUILD@Duo; screenshots on 17e, 18 Pro Max and Duo saved to `docs/screens/`
  show no clipping.

#### T-022 · Photo panel
- [x] **Depends:** T-021, T-015 · **Refs:** ios.md §6; PM §9, §12 M2, §13
- **Do:** Downsampled image, `scaledToFill().clipped().contentShape(Rectangle())`, single plain
  `Button` tap → next, `DragGesture` 35pt swipe, reveal `Transition` keyed by photo, fallback pair then
  derived pair, credit chip, `accessibilityIgnoresInvertColors()`.
- **Verify:** BUILD; UI test: one tap advances exactly one photo; swipe left/right moves ±1.

#### T-023 · Mixer toggle and push drawer
- [x] **Depends:** T-021 · **Refs:** ios.md §5 Liquid Glass, §6, §9 M1
- **Do:** 48pt glass toggle in a `GlassEffectContainer`; drawer inserted in the root `VStack` with the
  340/36/1.7 spring; one glass surface for the drawer; Reduce Motion uses the short ease.
  While open, a tap or swipe on the photo, or a tap on the specimen, closes the drawer and doesn't navigate.
- **Verify:** BUILD; UI test opens and closes the drawer, and checks that tapping the photo while open closes
  it without changing the photo; screenshot shows the canvas pushed up, not covered.

### Phase 3 — Deck

#### T-030 · Deck skeleton
- [x] **Depends:** T-023 · **Refs:** ios.md §8 (deck order); PM §9
- **Do:** Scrollable `ControlDeckView` with the web's single-column order; placeholder sections.
- **Verify:** BUILD; screenshot.

#### T-031 · Theme chips with wave
- [x] **Depends:** T-030 · **Refs:** PM §9, §12 M3; ios.md §9
- **Do:** Horizontal chip row, multi-select + All, `.isSelected` trait, `keyframeAnimator` wave on the
  selected chip, none under Reduce Motion.
- **Verify:** BUILD; UNIT for selection logic already in T-020; UI test toggles a chip.

#### T-032 · Color readout, picker and swap
- [x] **Depends:** T-030 · **Refs:** ios.md §6
- **Do:** Hex readouts (`monospacedDigit`), `ColorPicker` bridged to `SRGB8` with sRGB clamping, swap.
- **Verify:** BUILD; UNIT test for the `Color`→`SRGB8` clamp of a Display P3 color.

#### T-033 · HSL sliders
- [x] **Depends:** T-030 · **Refs:** ios.md §6; PM §8.13
- **Do:** FG and BG H/S/L sliders, integer steps, gradient tracks, labels with role.
- **Verify:** BUILD; UNIT: moving one slider changes only that channel; untouched colors keep their hex.

#### T-034 · Contrast block
- [x] **Depends:** T-030, T-012 · **Refs:** ios.md §6; PM §9
- **Do:** WCAG/APCA switch, score with `.contentTransition(.numericText(value:))`, meter, AA/AAA ticks
  with 44pt hit areas, Jump button with reached/missed message, pass/fail glyphs.
- **Verify:** BUILD; UI test: Jump to AA yields ≥ 4.5:1 shown.

#### T-035 · Export actions
- [x] **Depends:** T-030, T-020 · **Refs:** ios.md §6, §12, I10
- **Do:** Copy link (`UIPasteboard`, toast 1.6 s); Markdown `.md` via `ShareLink` + `Transferable`.
- **Verify:** BUILD; UNIT for the `.md` file name and contents; UI test sees the "Copied" toast.

### Phase 4 — Native polish

#### T-040 · Dynamic Type
- [x] **Depends:** T-031…T-035 · **Refs:** ios.md §8; NFR2
- **Do:** Apply the type scale everywhere; `AnyLayout` HStack→VStack at accessibility sizes; clamp at
  `.accessibility3` only where needed.
- **Verify:** BUILD; screenshots at Large, AX3 and AX5 (via `-UIPreferredContentSizeCategoryName`)
  show no clipped controls.

#### T-041 · Haptics
- [x] **Depends:** T-031…T-035 · **Refs:** ios.md §10
- **Do:** `.sensoryFeedback` per the table, gated by `hapticsEnabled`.
- **Verify:** BUILD; grep shows no `.increase/.decrease/.start/.stop/.levelChange`.

#### T-042 · VoiceOver
- [x] **Depends:** T-031…T-035 · **Refs:** ios.md §11
- **Do:** Labels, values, hints, custom actions (Next/Previous photo), announcements after Jump, specimen
  described in words, drawer content hidden when closed.
- **Verify:** BUILD; UI test with `performAccessibilityAudit()` passes on the main screen and open drawer.

#### T-043 · System accessibility settings
- [x] **Depends:** T-042 · **Refs:** ios.md §11; NFR6
- **Do:** Increase Contrast muted color, Differentiate Without Color glyphs, Smart Invert exclusions,
  Bold Text check, Reduce Transparency check.
- **Verify:** BUILD; screenshots with each setting on (simulator environment overrides) in `docs/screens/a11y/`.

#### T-044 · Deep links
- [x] **Depends:** T-020, T-022 · **Refs:** ios.md §12
- **Do:** `.onOpenURL` for `colorshift://pair?...`; the same parser also accepts `https://<web>/?...`
  (unit-tested; reachable once Universal Links exist).
- **Verify:** UNIT (parser); `xcrun simctl openurl booted "colorshift://pair?fg=F2D27A&bg=1F3A5F&photo=3"`
  shows that pair and photo (screenshot).

#### T-045 · About sheet
- [ ] **Depends:** T-014, T-041 · **Refs:** ios.md §4, §13, §16; FR11
- **Do:** Credits list with links, font licenses (OFL texts), privacy policy link from `AppConfig`,
  Haptics toggle, app version.
- **Verify:** BUILD; UI test opens it and finds the toggle and every credit.

#### T-046 · Smoke test and device sweep
- [ ] **Depends:** T-040…T-045 · **Refs:** ios.md §15; NFR8, NFR9
- **Do:** UI smoke flow (launch → tap photo → open drawer → select theme → Jump to AA → copy link);
  run on iPhone 17e, 18 Pro, 18 Pro Max and Duo.
- **Verify:** UI on all four simulators; zero concurrency warnings in the build log.

### Phase 5 — Release

#### T-050 · Privacy manifest
- [x] **Depends:** T-001 · **Refs:** ios.md §16
- **Do:** `PrivacyInfo.xcprivacy`: no tracking, no collected data, UserDefaults `CA92.1`.
- **Verify:** BUILD; the file is in the built `.app`.

#### H-06 · App icon `HUMAN`
- [ ] Layered Icon Composer icon from the jellyfish mark (default, dark, tinted); add `AppIcon.icon`.

#### H-07 · Privacy policy page `HUMAN`
- [ ] Publish a "Color Shift collects no data" page; record the URL in §1. (The loop may draft the
  text in `docs/privacy-policy.md`.)

#### T-051 · Store metadata draft
- [ ] **Depends:** T-046 · **Refs:** ios.md §16; research/app-store-release.md
- **Do:** `docs/store/metadata.md`: name, subtitle, description, keywords, support URL, review notes,
  age-rating answers (incl. the new descriptors), content rights, App Privacy answers, Nutrition Labels
  to claim.
- **Verify:** Every field within Apple's character limits (cite them in the file).

#### T-052 · Screenshots
- [ ] **Depends:** T-046, H-06 · **Refs:** research/app-store-release.md
- **Do:** UI-test-driven screenshots at the required and recommended iPhone sizes (and Duo when required),
  using real photo pairs, saved to `docs/store/screenshots/`.
- **Verify:** Pixel sizes match Apple's current spec listed in the research file.

#### H-08 · TestFlight and submission `HUMAN`
- [ ] Create the App Store Connect record, upload, TestFlight internally, then submit for review.

---

## 6. Progress log

Append one line per iteration: `YYYY-MM-DD · T-0xx · done|blocked · one-line note`.

- 2026-11-24 · — · setup · PRD created; repo initialized with ios.md, PROJECT_MAP.md snapshot, research/.
- 2026-11-24 · T-001 · done · XcodeGen 2.48 project; BUILD + UNIT green (UI launch test also green). UI-test target uses nonisolated default isolation (XCTestCase overrides); TARGETED_DEVICE_FAMILY set per target; dropped deprecated UIRequiresFullScreen.
- 2026-11-24 · T-002 · done · CLAUDE.md via /init: commands (incl. single-test syntax), loop summary, architecture, conventions, web-repo read-only rule. BUILD green, links resolve.
- 2026-11-24 · T-003 · done · Tokens/Typography/Motion + empty String Catalog; 16 token text pairs ≥ 4.5:1 (temporary WCAG helper in tests until T-011). iOS fix: credit label 55%→75% white (3.43→4.85:1 over white photos). System-font fallback until T-004.
- 2026-11-24 · T-010 · done · SRGB8 + HSL with JS rounding; PM §8.12 vectors, 16 invalid inputs, 4,096-color round trip pass. One-off exhaustive check: identical to the web's JS for all 2^24 rgb→hsl and all 361×101×101 hsl→hex. Codable as "#RRGGBB".
- 2026-11-24 · T-011 · done · ColorMath (luminance, contrast, tune → (color, reachedTarget), layoutShares, Meter incl. Jump target); PM §8.12 vectors + unreachable-7:1 miss pass; token test now uses ColorMath. One-off: tune/contrast identical to web JS on 200k random pairs.
- 2026-11-24 · T-012 · done · APCA 0.0.98G-4g (signed Lc, apca-w3 constants, attribution header) + displayValue round(|Lc|); 9 ios.md §7 vectors within 0.001, input-range, ΔY and Lc-10 clip edge cases pass.
- 2026-11-24 · T-013 · done · Theme, Photo, ColorPair, PhotoCatalog (web order, IDs from web App.tsx). Photographer name/handle filled from the web source (only the Unsplash page URL is optional until H-05). All 12 fallback pairs ≥ 4.5:1; visible(for:) and full-catalog index tested.
- 2026-11-24 · T-020 · done · AppModel + DeepLink parser + ColorMath.formatRatio (exact JS toFixed; matched node on 300k values). 26 model tests: wraparound, filters/All, tap-to-close, derive skip-once (no lingering skip), stale derive ignored, deep links (good/bad hex, out-of-range, foreign hosts), swap, sliders without drift, jump reached/missed, shareURL catalog index, markdown == web output. Running-app link rules recorded in ios.md §12.
- 2026-11-24 · T-021 · done · RootView + animatable SplitLayout (layoutShares.mobile) + SpecimenView (geometry size 80…512 + 13.33, a11y label/value, tap closes drawer); app owns AppModel, saves on background. BUILD + BUILD@Duo green; screenshots 17e / 18 Pro Max / Duo (outer display; Duo needs `--display=1`) show no clipping. Fixed: SwiftUI trailing tracking clipped the "a", so only the "A" is tracked (+0.01em offset keeps the web's position); canvas ignores bottom safe area.
- 2026-11-24 · T-023 · done · 48pt glass MixerToggle (web mixer path) in a GlassEffectContainer, bottom-leading of the canvas; deck inserted in the root VStack with the 340/36/1.7 spring (Reduce Motion: 0.2 s ease), one glass surface, height min(60% of full screen, 544) incl. the home-indicator inset; tappable PhotoPanelView stub for T-022. UI: open/close + tap-photo-closes-without-navigating pass; screenshot shows canvas pushed up. Added DEBUG launch arg -openControlsOnLaunch for screenshots. One unit-test run failed to launch the test host (no tests ran); rerun back-to-back with UI tests passed.
- 2026-11-24 · H-04 · done · Downloaded by Claude at the owner's request: DM Mono 400/500 and both OFL texts from google/fonts; Manrope 400/500/600/700 static TTFs from googlefonts/manrope (google/fonts only ships the variable font). PostScript names verified with CoreText.
- 2026-11-24 · T-004 · done · UIAppFonts lists the 6 TTFs; FontTests: every PostScript name resolves, every type style uses a bundled face, both OFL files are in the bundle. Screenshot shows Manrope.
- 2026-11-24 · T-030 · done · ControlDeckView in the web's ≤ 560px order (topline identity + export, chips row, readout, FG mix, BG mix, contrast) with web gaps (12.8 / 18.4 / 24); IdentityView + JellyfishMark (web SVG paths) built here; other sections are placeholders. BUILD + screenshot.
- 2026-11-24 · T-031 · done · ThemeChips (All + 6, horizontal scroll, web chip sizes, 44pt hit height, .isSelected). Wave via a wall-clock TimelineView (all selected chips in sync, D6) instead of keyframeAnimator, using the CSS keyframes with ease-in-out per segment; off under Reduce Motion. 4 ChipWave keyframe unit tests; UI test toggles Animals → first Animals photo, All → back to photo 0.
- 2026-11-24 · T-032 · done · ColorReadout (label, 23.2pt swatch, DM Mono hex; whole field is a 44pt button) + swap (32pt circle in a 44pt target). Picker: system UIColorPickerViewController presented from our button (SwiftUI ColorPicker only offers its own small well), continuous updates; SRGB8(UIColor) clamps extended-sRGB to 0…1. UNIT: P3 red → #FF0000, P3 gray, 4,096-color round trip. UI: swap exchanges values; tapping a field shows the picker (asserts its Grid/Spectrum/Sliders tabs; first version of the test was a false positive and was fixed).
- 2026-11-24 · T-033 · done · SliderGroup ×2 (heading + `H° · S% · L%`, Hue/Sat/Light rows with web gradient tracks and ringed 12pt thumb). Custom drawn slider (system Slider can't take gradient tracks) with a real Slider as accessibilityRepresentation ("Foreground hue", "44 degrees"); only calls setChannel when the integer value changes; 44pt rows replace the web's 10pt gaps. UNIT: SliderMath ends/clamp/101-step round trip (+ existing model test: one slider changes only its color). UI: track tap moves FG lightness, BG hex unchanged. XCTest on iOS has no slider decrement; VoiceOver adjust is left for T-042's audit.
- 2026-11-24 · T-034 · done · ContrastBlock: capsule WCAG/APCA switch (.isSelected, 44pt), score with numericText (WCAG = JS toFixed(2), APCA = round(|Lc|)), meter (fill min(1, r/12), AA 37.5% / AAA 58.3% tick buttons, 44pt targets), always-on ✓/✗ glyphs, Jump to AA/AAA with "Can't reach … with this hue" shown until the pair changes. UI: darkening FG then Jump to AA gives ≥ 4.5 and AA tick "passes"; APCA mode shows "78 Lc" for the initial pair.
- 2026-11-24 · T-035 · done · ExportActions (icon-only like the web ≤ 560px, web copy/download paths, 44pt targets). Copy link: UIPasteboard url = shareURL, model.linkCopied for 1.6 s (web `copied`), button label "Copied", bottom toast "Link copied to clipboard" + VoiceOver announcement. Markdown: ShareLink with a Transferable MarkdownFile (.md, plain-text-conforming) written to tmp. UNIT: file name/contents, .md type, pasteboard write. UI: toast appears and clears; share sheet names color-shift-F4C6D9-16172B.md and offers Save to Files. Full UI suite (12 tests) green.
- 2026-11-24 · T-040 · done · AdaptiveStack (AnyLayout HStack→VStack at accessibility sizes) for topline, readout, slider headings/rows, contrast head and jump row; tick labels move to a legend row at AX sizes (they collide under the ticks); icons scale via @ScaledMetric; segment/score single-line. No clamp needed: AX5 fits. Screenshots at Large/AX3/AX5 (docs/screens/t040-*). Found and fixed a real bug: the slider's DragGesture(minimumDistance: 0) captured vertical scrolls (scrolling the deck changed colors); now a UIKit horizontal-only pan + tap. Regression UI test fails on the old gesture, passes now.
- 2026-11-24 · T-041 · done · Model emits HapticEvents from its actions (photo, chip, drawer via didSet, swap, jump reached/missed, link copied, slider end, contrast crossing AA/AAA up or below AA while dragging); one root HapticsModifier maps them to iPhone-playable SensoryFeedback, gated by hapticsEnabled. 6 unit tests incl. "no .increase/.decrease/.start/.stop/.levelChange"; grep of app sources finds them only in a doc comment. Full UI suite (16) green. The on/off toggle UI comes with the About sheet (T-045).
- 2026-11-24 · T-042 · done · Photo Next/Previous custom actions; Jump announces "Contrast now N to 1, passes AA" (or can't-reach); sliders are adjustable elements (label with role, "87 percent", ±1) instead of a hidden Slider; HSL readout spoken. performAccessibilityAudit passes on the main screen and 3 drawer scroll positions. Fixes the audit drove: 11pt styles relativeTo .caption (caption2 = "partially unsupported"); muted/subtle/tick → #8E9097 because the glass deck renders at ~#15171A (token test now also checks deck text on glass); tick label 8pt below its line. Documented exemptions: fixed-size "Aa"; contrast of elements outside the visible deck; the unselected WCAG/APCA segment (audit compares two dark fills, 1.29:1; measured text 5.83:1 on its capsule). Full suites: 86 unit, 20 UI green.
- 2026-11-24 · T-043 · done · Increase Contrast: secondary labels → #A9ABB1, chip/swap borders #6A6C73 at 1.5pt (≥ 3:1 on the glass). Bold Text: each style steps up one bundled weight (specimen → Manrope Bold); measured +21–22% text ink on DM Mono Regular labels, heaviest faces unchanged. Smart Invert: photo, specimen, swatches and slider tracks excluded (iOS doesn't invert dark-mode apps, so not visible in screenshots). Differentiate Without Color: ✓/✗ always on (screenshot identical to baseline by design). Reduce Transparency: system glass turns solid (mixer toggle). Screenshots for all six in docs/screens/a11y/ (simctl ui + com.apple.Accessibility defaults).
- 2026-11-24 · T-050 · done · PrivacyInfo.xcprivacy: no tracking, no tracking domains, no collected data; UserDefaults with CA92.1 (haptics preference). plutil lint OK; file present in the built .app; unit test parses the bundled manifest. No other required-reason APIs used (no file timestamps, uptime or disk space).
- 2026-11-25 · H-01 · done (owner) · Name "KDP Color" (App Store and home-screen display name; in-app brand stays "Color Shift"); bundle ID com.kierandelpasqua.colorshift (+ .tests, .uitests) in project.yml and AppConfig. 89 unit tests green.
- 2026-11-25 · H-05 · done (owner-approved download) · 12 JPEGs in ColorShift/Resources/Photos at 2400px long side (6.6 MB); docs/photo-sources.md table with photographers (from the web), review: portraits #4/#5 kept, minor signage in #2/#3 accepted. Photo page links optional; credits link to the photographer profile, as on the web.
- 2026-11-25 · H-07 · drafted · docs/privacy-policy.md (no data collected; haptics setting on device only; no network). URL set in AppConfig. Owner still enables GitHub Pages (Settings → Pages → main, /docs) before ticking.
- 2026-11-25 · H-06 · drafted · ColorShift/Resources/AppIcon.icon: three glass layers (body, bell, rim) from the jellyfish mark on a dark automatic gradient; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon. actool compiles it; ictool renders Default/Dark/ClearLight/TintedDark (docs/screens/icon/h06-renditions.png); shows on the simulator home screen as "KDP Color". Owner polishes in Icon Composer, then ticks.
- 2026-11-25 · T-014 · done · Aspects are bundled-file pixel ratios (e.g. 2400/1543); all stay in the web's layout buckets. Photo.photographerURL and Photo.unsplashURL carry utm_source=color_shift&utm_medium=referral. Tests: every photo is a bundle file ≥ 2000px long side (ImageIO properties only), aspect within 0.5%, credit present. 93 unit tests green.
- 2026-11-25 · T-015 · done · PhotoSampler: ImageIO thumbnail (256px) → 32×32 sRGB premultipliedLast context → un-premultiply → every 8th pixel → most saturated (stable) → partner tuned to 4.5:1, with reachedTarget. Interpolation .medium, not .high: .high rings at edges and invents over-saturated samples (caught by the two-tone test). DerivedPairCache actor caches per photo. Expected synthetic pairs computed by the web's own JS in Node. All 12 photos derive a pair; 101 unit tests green.
- 2026-11-25 · T-016 · blocked · Web pairs captured (ColorShiftTests/Fixtures/web-derived-pairs.json, headless Chrome via CDP, web code + web image URLs). 6/12 photos exceed ±6 per channel; no resampling variant gets below 4/12. Max-saturation pick is unstable across resamplers. Needs an owner decision.
- 2026-11-25 · T-016 · done · Owner chose exact parity: PhotoCatalog carries the 12 web-captured pairs (Photo.derived); DerivedPairCache returns them (reachedTarget from the real ratio), PhotoSampler only when absent. Tests: catalog table == fixture; every applied pair within ±6 of the web (exact). Note: 4 web pairs are below 4.5:1 (#1 2.15, #5 3.07, #9 2.55, #11 2.67) because the web's light partner can't reach AA on mid-light bases; iOS reports these as misses. 104 unit tests green.
- 2026-11-25 · T-022 · done · PhotoPanelView: ImageIO downsample to the cover-fit pixel size (128px buckets, 4-image actor cache), scaledToFill + clipped + contentShape; plain Button tap → next; DragGesture(10) as highPriorityGesture so a swipe never also taps (±35pt → ±1; shorter drags only close an open drawer); M2 reveal as an insertion-only Transition keyed by photo (fade only under Reduce Motion); fallback pair, then the derived pair via DerivedPairCache; credit chip (Link to photographer with UTM, ≥44pt, outside the button, fixedSize after the audit flagged 'Text clipped'). UI: one tap = one photo, swipes ±1 with wrap, swipe with drawer open only closes. 7 older UI tests that check exact launch colors now pass DEBUG -disablePhotoDerivation (assertions unchanged). 24 UI, 104 unit green. docs/screens/t022-photo-panel.png.
- 2026-11-25 · T-044 · done · .onOpenURL → model.apply(deepLink:) (parser unit-tested since T-020, both colorshift:// and https forms). simctl openurl leaves iOS's "Open in KDP Color?" prompt, so the Verify runs as DeepLinkTests (opens the link, taps Open): cold and warm starts show photo 3 with #F2D27A on #1F3A5F, and photo 3's derived pair doesn't overwrite them. Screenshots docs/screens/t044-cold.png, t044-warm.png.
