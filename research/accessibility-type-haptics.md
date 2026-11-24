# Accessibility, Typography & Haptics in SwiftUI — Color Shift iOS port

Last checked: 2026-11-24

Scope: single-screen iPhone app, iOS 17+ deployment target. This covers Dynamic Type, minimum sizes and fonts, VoiceOver, system accessibility settings, haptics, App Store Accessibility Nutrition Labels, and testing. Every API name below was checked against Apple's documentation JSON (developer.apple.com) on the date above unless marked **[unverified]**.

---

## TL;DR

- **Dynamic Type.** Use text styles (`.caption2`, `.footnote`, `.body`) or `Font.custom(_:size:relativeTo:)` for every drawer label. Use `@ScaledMetric` for paddings and chip heights. Switch HStack→VStack with `AnyLayout` when `dynamicTypeSize.isAccessibilitySize` is true [4][9]. Apple's Larger Text label needs text to reach **≥200%**, and on iOS **AX3 already exceeds 200%** [33]. You can therefore clamp the drawer at `.dynamicTypeSize(...DynamicTypeSize.accessibility3)` if AX4/AX5 breaks the layout, and still qualify.
- **The giant "Aa" specimen should not follow Dynamic Type.** Size it from the container geometry (the web `clamp()` translated to `GeometryReader` math) with a fixed-size font. Its 80pt floor is already larger than the biggest AX5 Large Title (60pt) [1]. **Don't hide it from VoiceOver.** It is the app's main content, so give it one combined element whose label describes the colors in words.
- **Minimums.** iOS text should be at least **11pt** (default 17pt) [1][2]. The web's 9–10px labels must become ≥11pt (`.caption2`). Hit targets should be **44×44pt** by default, with 28×28pt as the absolute minimum [2]. Use `.monospacedDigit()` on contrast ratios and hex readouts [12]. The web's Manrope and DM Mono are both **SIL OFL** licensed [14], so you can bundle them via `UIAppFonts` [13]. Otherwise, SF Pro / SF Mono come from `Font.system(..., design: .monospaced)` and must not be embedded [1].
- **Haptics.** Use `.sensoryFeedback(_:trigger:)` (iOS 17) [30]. **Gotcha:** on iOS, `.increase`, `.decrease`, `.start`, `.stop` and `.levelChange` **play nothing**. Per Apple's docs they only play on watchOS/visionOS/macOS [29]. Build on these instead: `.selection`, `.impact(...)`, `.success`, `.warning`, `.error`, `.alignment` and `.pathComplete` (17.5+). HIG: use the patterns for their documented meaning, don't overuse them, and **make haptics optional** (add an in-app toggle) [3].
- **Settings.** Respect Reduce Motion (drop the scale/blur reveal and stop the chip shimmer), Reduce Transparency (make the drawer opaque) and Increase Contrast (brighten muted label `#83858C`, currently 5.09:1, to roughly `#A9ABB1`, 8.16:1). Respect Differentiate Without Color (show pass/fail glyphs) and Bold Text (`legibilityWeight`). Add `accessibilityIgnoresInvertColors()` on photos and color swatches [23–28].
- **Nutrition Labels.** Plausible claims: VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color Alone, Sufficient Contrast and Reduced Motion. Captions and Audio Descriptions don't apply (no media). Declare them in App Store Connect › app › **App Accessibility** › Get Started [31][32].
- **Testing.** In Xcode Previews, use Variants › **Dynamic Type Variants** [4]. Use Accessibility Inspector, and add `try app.performAccessibilityAudit()` in an XCUITest (iOS 17+) [38][39].

---

## 1. Dynamic Type

### 1.1 Text styles and default sizes (iOS, Large = default)

Source: HIG Typography › Specifications [1]. All values are in points. Weight is Regular unless noted; Headline is Semibold.

| Style | xS | S | M | **L (default)** | xL | xxL | xxxL | AX1 | AX2 | AX3 | AX4 | AX5 | Leading @L |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Large Title | 31 | 32 | 33 | **34** | 36 | 38 | 40 | 44 | 48 | 52 | 56 | 60 | 41 |
| Title 1 | 25 | 26 | 27 | **28** | 30 | 32 | 34 | 38 | 43 | 48 | 53 | 58 | 34 |
| Title 2 | 19 | 20 | 21 | **22** | 24 | 26 | 28 | 34 | 39 | 44 | 50 | 56 | 28 |
| Title 3 | 17 | 18 | 19 | **20** | 22 | 24 | 26 | 31 | 37 | 43 | 49 | 55 | 25 |
| Headline (Semibold) | 14 | 15 | 16 | **17** | 19 | 21 | 23 | 28 | 33 | 40 | 47 | 53 | 22 |
| Body | 14 | 15 | 16 | **17** | 19 | 21 | 23 | 28 | 33 | 40 | 47 | 53 | 22 |
| Callout | 13 | 14 | 15 | **16** | 18 | 20 | 22 | 26 | 32 | 38 | 44 | 51 | 21 |
| Subhead | 12 | 13 | 14 | **15** | 17 | 19 | 21 | 25 | 30 | 36 | 42 | 49 | 20 |
| Footnote | 12 | 12 | 12 | **13** | 15 | 17 | 19 | 23 | 27 | 33 | 38 | 44 | 18 |
| Caption 1 | 11 | 11 | 11 | **12** | 14 | 16 | 18 | 22 | 26 | 32 | 37 | 43 | 16 |
| Caption 2 | 11 | 11 | 11 | **11** | 13 | 15 | 17 | 20 | 24 | 29 | 34 | 40 | 13 |

Takeaways for Color Shift:
- **Caption 2 never drops below 11pt**, even at xSmall. That matches the HIG 11pt minimum [1]. It is the natural home for the web's 9–11px uppercase mono labels.
- Body scales from 17pt to 53pt at AX5, about 312%. Apple's Larger Text criteria say "AX3 exceeds 200% and AX5 allows body text over 300%" [33].
- `DynamicTypeSize` cases: `.xSmall`, `.small`, `.medium`, `.large`, `.xLarge`, `.xxLarge`, `.xxxLarge`, `.accessibility1` through `.accessibility5`, plus `isAccessibilitySize` [6]. The type is `Comparable`, so you can write `>= .accessibility1` [6].

### 1.2 Fonts that scale

```swift
// System font: scales automatically
Text("CONTRAST").font(.caption2.weight(.medium))

// Bundled custom font that scales relative to a text style (iOS 14+) [8]
extension Font {
    static func manrope(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Manrope", size: size, relativeTo: style)   // PostScript/family name — verify with UIFont.familyNames [13]
    }
    static func dmMono(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption2) -> Font {
        .custom("DMMono-Regular", size: size, relativeTo: style)
    }
}

Text("BACKGROUND").font(.dmMono(11, relativeTo: .caption2))
```

`Font.custom(_:size:)` without `relativeTo:` *also* scales relative to `.body` **[unverified from docs fetched; widely documented behaviour]**. `Font.custom(_:fixedSize:)` does not scale. Use it only for the specimen.

### 1.3 `@ScaledMetric` for non-text dimensions

```swift
struct ThemeChip: View {
    @ScaledMetric(relativeTo: .caption2) private var chipHeight: CGFloat = 32
    @ScaledMetric(relativeTo: .caption2) private var hPad: CGFloat = 12
    @ScaledMetric(relativeTo: .caption2) private var swatch: CGFloat = 14
    // …
}
```

`init(wrappedValue:relativeTo:)` is iOS 14+ [7]. WWDC24 uses `@ScaledMetric var imageWidth = 125.0` to scale essential images with text [4].

### 1.4 Clamping with `.dynamicTypeSize(_:)`

`dynamicTypeSize(_:)` takes a `RangeExpression` of `DynamicTypeSize` (iOS 15+). Multiple ranges intersect, and a later fixed size wins [5].

```swift
DrawerView()
    .dynamicTypeSize(...DynamicTypeSize.accessibility3)   // still satisfies the ≥200% Larger Text bar [33]
```

When you clamp, Apple suggests also adding a Large Content Viewer: `accessibilityShowsLargeContentViewer()` [5][11]. Apple also says not to use the Large Content Viewer *instead of* Dynamic Type. Reserve it for controls that must stay small, such as tab-bar-like chip rows [11][4].

```swift
ThemeChip(theme)
    .accessibilityShowsLargeContentViewer {
        Label(theme.name, systemImage: "circle.lefthalf.filled")
    }
```

(The closure form appears in the WWDC24 sample [4].)

### 1.5 The giant "Aa" specimen: don't tie it to Dynamic Type

The web uses `clamp(5rem, min(30cqw, 64cqh), 32rem) + 10pt`, which is 80–512px driven by container size. In SwiftUI:

```swift
struct Specimen: View {
    let fontName: String
    var body: some View {
        GeometryReader { geo in
            let fluid = min(geo.size.width * 0.30, geo.size.height * 0.64)
            let size = min(max(fluid, 80), 512) + 10        // clamp(80, fluid, 512) + 10
            Text("Aa")
                .font(.custom(fontName, fixedSize: size))   // fixedSize: does NOT scale with Dynamic Type
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(specimenDescription)  // e.g. "Sample text Aa in Manrope, warm off-white on deep charcoal"
        .accessibilityAddTraits(.isImage)          // trait choice is a judgement call
    }
}
```

Why:
- At 80pt minimum it is already larger than AX5 Large Title (60pt) [1]. Scaling it further would only push the photo and drawer off-screen. HIG: "Prioritize important content when responding to text-size changes… they don't always want to increase the size of every word" [1]. WWDC24: "apps should prioritize scaling essential content over decorative views" [4].
- **Don't use `accessibilityHidden(true)`** [22]. The specimen *is* the result of the user's color choices, so VoiceOver users need it described. Hide only truly decorative layers, such as the shimmer overlay and gradient scrims.
- Free space taken by larger drawer text should come out of the specimen. Let the geometry calculation shrink it naturally as the drawer grows.

### 1.6 Layout adaptation at accessibility sizes

`AnyLayout` (iOS 16+) swaps a container type without destroying subview state. Apple's doc example switches HStack/VStack on `dynamicTypeSize` [9]. WWDC24 uses `isAccessibilitySize` [4].

```swift
struct ReadoutRow: View {
    @Environment(\.dynamicTypeSize) private var dts
    var body: some View {
        let layout = dts.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        layout {
            Text("CONTRAST").font(.caption2)
            Text("5.09 : 1").font(.body).monospacedDigit()
            CopyButton(value: "5.09")
        }
    }
}
```

`ViewThatFits` (iOS 16+) picks the first child whose ideal size fits the proposed size, in the order you provide [10]. This is good for chip rows: one row, then a 2-row grid, then a horizontal scroll.

```swift
ViewThatFits(in: .horizontal) {
    HStack { ForEach(themes) { ThemeChip($0) } }
    ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(themes) { ThemeChip($0) } } }
}
```

At accessibility sizes the screen layout should probably change from "specimen beside photo" to "specimen above photo", or the photo should shrink to a thumbnail. HIG says to use stacked layouts and fewer columns at large sizes, and to keep primary elements near the top [1]. Truncation should be minimal; wrap to more lines instead [1][33].

---

## 2. Minimum sizes, legibility, fonts

### 2.1 Numbers to design to

| Thing | iOS value | Source |
|---|---|---|
| Default text size | 17pt | HIG Typography / Accessibility [1][2] |
| Minimum text size | **11pt** | [1][2] |
| Default control size | **44×44pt** | HIG Accessibility [2] |
| Minimum control size | 28×28pt | [2] |
| Padding around bezeled controls | ~12pt | [2] |
| Padding around bezel-less controls | ~24pt | [2] |
| Contrast, text ≤17pt | 4.5:1 | WCAG AA, as used by Accessibility Inspector [2] |
| Contrast, text ≥18pt or bold | 3:1 | [2] |
| Non-text control/state contrast | 3:1 "commonly recommended" | Sufficient Contrast criteria [34] |
| Text enlargement | ≥200% | [2][33] |

Implications:
- Web 9px and 10px labels → **11pt minimum** (`.caption2`). With a mono font at small sizes, prefer Regular or Medium. HIG says to avoid Ultralight/Thin/Light at small sizes, and to go larger than the minimum if a custom font is thin [1].
- Copy buttons and slider thumbs can look small, but their tappable frame must be ≥44pt. Use `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` and keep the visual glyph small.
- Muted label `#83858C` on `#111214` = **5.09:1**, which passes 4.5:1 for small text. Its Increase Contrast variant should go higher (see §4).

### 2.2 Uppercase / tracked labels

The HIG pages fetched do not explicitly address all-caps legibility **[not found in HIG Typography/Accessibility on 2026-11-24]**. Practical guidance:
- Keep the source string in sentence case and apply `.textCase(.uppercase)`. Add `.tracking(0.5…1.0)` for small caps-style labels. Whether VoiceOver reads the un-transformed string is **[unverified]**, but it avoids hard-coded all-caps strings, which VoiceOver may spell as acronyms **[unverified, commonly reported]**. If in doubt, set an explicit `.accessibilityLabel("Background")`.
- Uppercase + mono + 11pt is the legibility floor. Don't go smaller, and don't use a light weight.
- HIG: maintain hierarchy at all sizes, and use weight, size and color (not just case) for emphasis [1].

### 2.3 Fonts

- **System fonts.** SF Pro is the iOS system font. SF Mono is part of the SF family [1]. Access them with `Font.system(.caption2, design: .monospaced)`, and the system picks SF Mono. HIG developer note: "use the constants defined in Font.Design… don't embed system fonts in your app" [1].
- **Tabular figures.** `.monospacedDigit()` (iOS 15+) makes digits fixed-width and leaves other characters proportional ("tabular figures") [12]. Use it on contrast ratios, hex/RGB readouts and slider values so numbers don't jitter while dragging. Note that `Font.monospacedDigit()` also exists as a `Font` modifier **[unverified on this pass]**.
- **The web's fonts.** The web loads **Manrope** (variable, `wght` axis) and **DM Mono** from Google Fonts. In the Google Fonts repo both are `license: "OFL"` (SIL Open Font License) [14]. OFL permits bundling in apps. Include the OFL text in your acknowledgements, and don't sell the font by itself **[OFL terms summarised from general knowledge; read the bundled OFL.txt]**.
- **Registering custom fonts** [13]:
  1. Add the `.ttf`/`.otf` to the app target (Target Membership checked).
  2. In Info.plist add **"Fonts provided by application"** (raw key `UIAppFonts`), an array of the font file names.
  3. Find the real font name with `UIFont.familyNames` / `UIFont.fontNames(forFamilyName:)`. It rarely matches the file name.
- **Custom fonts and accessibility.** HIG: system fonts automatically support Dynamic Type and Bold Text. If you use a custom font, "make sure it implements the same behaviors" [1]. So use `relativeTo:` for Dynamic Type, and read `legibilityWeight` for Bold Text (§4).
- **Decision for owner:** either use Manrope + DM Mono for brand parity (bundle about 4 files), or use SF Pro + SF Mono (zero bundle, free Bold Text and optical sizing). A hybrid also works: Manrope for the specimen (it is literally a type specimen) and SF for the UI chrome.

---

## 3. VoiceOver for this UI

### 3.1 Element plan

| UI piece | Treatment |
|---|---|
| Photo | `.accessibilityLabel(photo.altText)` with a human-written description, plus `.accessibilityAddTraits(.isImage)`. Add `accessibilityAction(named: "Next photo")` / `"Previous photo"` [17]. Also `.accessibilityIgnoresInvertColors()` [28]. |
| "Aa" specimen | One element (`accessibilityElement(children: .ignore)` [18]). Label it with font + foreground/background color names + contrast, e.g. "Specimen: off-white text on charcoal, contrast 12.4 to 1, passes AA". |
| Drawer handle | Button with label "Controls", value "Expanded"/"Collapsed", and hint "Double-tap to collapse". |
| Small label + value pair (e.g. "CONTRAST 5.09:1") | `.accessibilityElement(children: .combine)` so it is read as one element [18]. |
| Theme chips | Each chip is a Button with `.accessibilityAddTraits(.isSelected)` on the active one. Wrap the row in `.accessibilityElement(children: .contain)` plus `.accessibilityLabel("Themes")`. |
| Sliders | Prefer the system `Slider` (it is already adjustable). For a custom slider, use `accessibilityRepresentation { Slider(...) }` [20] or `.accessibilityValue` + `accessibilityAdjustableAction` [16]. |
| Copy buttons | Label "Copy hex", value "#83858C". On success, post an announcement "Copied #83858C". |
| Shimmer overlay, gradients | `.accessibilityHidden(true)` [22]. |

### 3.2 Snippets

Adjustable custom slider [16]:

```swift
HueTrack(value: $hue)
    .accessibilityElement()
    .accessibilityLabel("Hue")
    .accessibilityValue("\(Int(hue)) degrees, \(colorName(for: hue))")
    .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: hue = min(hue + 5, 360)
        case .decrement: hue = max(hue - 5, 0)
        @unknown default: break
        }
    }
```

Or reuse the system semantics [20]:

```swift
HueTrack(value: $hue)
    .accessibilityRepresentation {
        Slider(value: $hue, in: 0...360, step: 5) { Text("Hue") }
    }
```

Named actions on the photo [17]. `accessibilityAction(named:)` with `LocalizedStringResource` is iOS 16+:

```swift
PhotoView(photo)
    .accessibilityAction(named: "Next photo") { model.next() }
    .accessibilityAction(named: "Previous photo") { model.previous() }
```

Announcing a change (iOS 17+) [15]:

```swift
import Accessibility   // AccessibilityNotification lives in the Accessibility framework; also visible via SwiftUI

func announce(_ text: String, high: Bool = false) {
    var s = AttributedString(text)
    if high { s.accessibilitySpeechAnnouncementPriority = .high }
    AccessibilityNotification.Announcement(s).post()
}

// after theme change:
announce("Theme Dusk. Text off-white on plum. Contrast 7.2 to 1, passes triple A.")
```

Apple's example sets `accessibilitySpeechAnnouncementPriority = .high`, which "interrupts other speech and isn't interruptible" [15]. Use the default priority for routine changes, and don't announce on every slider tick. A readout that changes continuously can carry `.accessibilityAddTraits(.updatesFrequently)` [41] instead.

Optional custom rotor (iOS 16+) [19]. This is probably overkill for one screen. A rotor of "Readouts" or "Copyable values" lets VoiceOver users jump between the contrast/hex values:

```swift
DrawerView()
    .accessibilityElement(children: .contain)
    .accessibilityRotor("Copyable values") {
        ForEach(readouts) { r in AccessibilityRotorEntry(r.title, id: r.id) }
    }
```

Voice Control: give icon-only buttons spoken names with `.accessibilityInputLabels(["Copy", "Copy hex"])` [21].

`UIAccessibility.isVoiceOverRunning` exists if you need to, for example, stop the drawer auto-collapsing on a timer for VoiceOver users [42]. HIG also says to minimise time-boxed UI in general [2].

### 3.3 Describing colors in words

There is **no Apple API that converts an arbitrary color to a human-readable name** **[none found; unverified absence]**. Write a small mapper:
- Hue bucket (red, orange, yellow, green, teal, blue, purple, pink) from HSL hue.
- Lightness modifier (very dark / dark / medium / light / very light), plus a saturation modifier (greyish / muted / vivid). Near-zero saturation → black/charcoal/grey/off-white/white.
- Combine: "muted dark blue", "off-white", "charcoal".
- Always include the contrast ratio and pass/fail in words: "5.1 to 1, passes AA for small text". Say "to" rather than ":".
- Curated themes should use their human names ("Dusk") plus the generated description.

---

## 4. System accessibility settings

All environment values below are iOS 13+ except where noted.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion             // [23]
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency // [24]
@Environment(\.colorSchemeContrast) private var contrast                       // .standard / .increased [25]
@Environment(\.accessibilityDifferentiateWithoutColor) private var diffNoColor // [26]
@Environment(\.legibilityWeight) private var legibilityWeight                  // .bold when Bold Text is on [27]
```

| Setting | API | What Color Shift should do |
|---|---|---|
| **Reduce Motion** | `accessibilityReduceMotion` [23] | **Drawer:** keep it gesture-tracked, but use a tight, non-bouncy spring (`.snappy`/`.smooth` or `.spring(response:…, dampingFraction: 1)`). HIG: "tightening animation springs to reduce bounce" [2]. **Photo reveal:** drop the scale and blur, keep a short opacity crossfade. HIG: avoid zooming/scaling, avoid "animating into and out of blurs", replace motion with fades [2]. The Reduced Motion criteria name "animated blur" and depth effects [35]. **Chip wave shimmer:** decorative and repeating, so turn it off entirely [35]. |
| **Reduce Transparency** | `accessibilityReduceTransparency` [24] | Replace `.ultraThinMaterial` drawer and scrims with an opaque fill (e.g. `#111214`). The doc says backgrounds "should not be semi-transparent; they should be opaque" [24]. |
| **Increase Contrast** | `colorSchemeContrast == .increased` [25] | Muted label `#83858C` (5.09:1) → about `#A9ABB1` (8.16:1 on `#111214`; computed locally with the WCAG formula). Thicken chip borders and selection rings, and remove low-alpha dividers. Apple suggests asset-catalog "High Contrast" variants when only colors change [25]. HIG: if default contrast is short, at least provide a higher-contrast scheme when Increase Contrast is on [2]. |
| **Differentiate Without Color** | `accessibilityDifferentiateWithoutColor` [26] | Contrast pass/fail must not be color-only. Always show a glyph + text ("AA ✓" / "Fails"). Mark the selected chip with a ring or checkmark, not just a tint. The Nutrition Label criteria want this *by default*, with the setting as a last resort [36], so show glyphs always. |
| **Bold Text** | `legibilityWeight == .bold` [27] | System fonts handle it automatically. For Manrope/DM Mono, bump the weight yourself (`.weight(legibilityWeight == .bold ? .bold : .medium)`), since HIG says custom fonts must match the system behaviour [1]. Whether SwiftUI auto-bolds `Font.custom` is **[unverified]**. |
| **Smart Invert** | `accessibilityIgnoresInvertColors(_:)` (iOS 14+) [28] | Apply it to the photo and to *every color swatch, chip and the specimen*. Inverting a color tool's colors would make it lie. |
| **Dark Interface** | `colorScheme` | The app is dark-only (`#111214`). It qualifies for the "Dark Interface" label [31]. Consider locking `.preferredColorScheme(.dark)` and checking contrast. |

Reduce-motion animation helper:

```swift
extension View {
    func motionAware<V: Equatable>(_ full: Animation, reduced: Animation? = .easeInOut(duration: 0.2), value: V) -> some View {
        modifier(MotionAware(full: full, reduced: reduced, value: value))
    }
}
struct MotionAware<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduce
    let full: Animation; let reduced: Animation?; let value: V
    func body(content: Content) -> some View { content.animation(reduce ? reduced : full, value: value) }
}

// Photo reveal transition
var revealTransition: AnyTransition {
    reduceMotion ? .opacity
                 : .opacity.combined(with: .scale(scale: 0.96)) // + blur via custom modifier
}
```

---

## 5. Haptics

### 5.1 `SensoryFeedback` (SwiftUI, iOS 17+)

Every member listed in Apple's `SensoryFeedback` doc, with the doc's own "only plays on…" note [29]:

| Member | Meaning (Apple) | Plays on **iOS**? |
|---|---|---|
| `.selection` | "a UI element's values are changing" | **Yes** (iOS, watchOS) |
| `.impact` | physical collision metaphor | **Yes** (iOS, watchOS) |
| `.impact(weight:intensity:)`, where `Weight` = `.light`/`.medium`/`.heavy`, `intensity` defaults to 1.0 | same | **Yes** (iOS, watchOS); "not all platforms play different feedback for different weights" |
| `.impact(flexibility:intensity:)`, where `Flexibility` = `.rigid`/`.solid`/`.soft` | same | **Yes** (iOS, watchOS) |
| `.success` | task/action completed | **Yes** |
| `.warning` | task produced a warning | **Yes** |
| `.error` | an error occurred | **Yes** |
| `.alignment` | dragged item aligned / reached min–max | **Yes** (iOS, macOS) |
| `.pathComplete` (iOS **17.5**+) | drawn path completed/recognized | **Yes** (iOS only) |
| `.increase` / `.decrease` | important value crossed a threshold | **No**: watchOS & visionOS only |
| `.start` / `.stop` | activity started/stopped | **No**: watchOS only |
| `.levelChange` | discrete pressure levels | **No**: macOS only |
| `.press(_:)`, `.release(_:)`, `.selection(_:)` with `PressFeedback` `.button`/`.buttonIconOnly`/`.slider`/`.tab`/`.toggle` | control-specific press/release feedback | **iOS 26+ only**. Not usable at an iOS 17 floor without `if #available` |

Modifier variants (all iOS 17+) [30]:

```swift
// 1. Plain: plays when trigger changes
.sensoryFeedback(.selection, trigger: selectedTheme)

// 2. Conditional: plays only if closure returns true
.sensoryFeedback(.success, trigger: copyCount) { old, new in new > old }

// 3. Dynamic: choose feedback (or nil) at change time
.sensoryFeedback(trigger: passesAA) { passesAA ? .impact(flexibility: .rigid, intensity: 0.7) : nil }
```

There is also an overload of form 3 whose closure receives `(oldValue, newValue)` **[unverified on this pass; the doc topic list showed only the zero-arg form]**.

### 5.2 UIKit fallback / finer control

HIG iOS names three generator families: **notification** (outcome: success/warning/error), **impact** (physical metaphor, e.g. snap into place) and **selection** (values changing) [3]. Their UIKit counterparts are `UINotificationFeedbackGenerator`, `UIImpactFeedbackGenerator` (`.light/.medium/.heavy/.soft/.rigid`, `impactOccurred(intensity:)`) and `UISelectionFeedbackGenerator` (`selectionChanged()`). Call `prepare()` before latency-sensitive events. **[UIKit signatures from general knowledge; not re-fetched on this pass.]** Use them for slider detents during a drag, where you want to `prepare()` on drag start and fire imperatively. A SwiftUI trigger on a rapidly changing value also works.

### 5.3 HIG rules [3]

- Use system patterns **according to their documented meanings**. If a meaning doesn't fit, use a generic pattern instead of borrowing one.
- Be **consistent**: build a clear cause→effect association.
- **Complement** visual and audio feedback, and match haptic sharpness and intensity to the animation.
- **Avoid overusing.** "Often, the best haptic experience is one that people may not be conscious of, but miss when it's turned off."
- Prefer **short haptics for discrete events**.
- **Make haptics optional**: let people turn them off. This means an in-app "Haptics" toggle in addition to the system setting.
- System controls (toggles, sliders, pickers) already play haptics on supported iPhones [3]. Don't double up on a system `Slider`'s built-in feedback **[whether SwiftUI `Slider` with `step:` emits per-step haptics on iOS 17 is unverified; test on device]**.
- Whether UIKit/SwiftUI feedback is automatically muted when Settings › Sounds & Haptics › System Haptics is off is **[unverified in fetched docs]**. Ship the in-app toggle regardless.

### 5.4 Proposed mapping for Color Shift

| Event | Feedback | Why | Notes |
|---|---|---|---|
| Next / previous photo | `.selection` | Discrete value change ("values are changing") | Trigger on `photoIndex`. No haptic on VoiceOver-invoked actions is fine either way. |
| Drawer open / close | `.impact(flexibility: .soft, intensity: 0.5)` on **settle** at a detent | Impact = "a view snaps into place" [3] | Fire on detent change, not on drag start. Skip it if using a system `.sheet` with `presentationDetents`, whose own behaviour **[unverified]** should be checked first. |
| Theme chip select | `.selection` | Picking among discrete options | Same as segmented controls. Keep it consistent with photo nav. |
| Slider detents (snap points / ends) | `.alignment` at named detents and at min/max; otherwise none | Apple: alignment fits "reaching the beginning/end or minimum/maximum" [3][29] | Don't fire per pixel. If steps are coarse (≤ ~20 stops), `.selection` per step is acceptable. |
| Copy succeeded | `.success` | Outcome of a task [3] | Pair with a visual "Copied" state and a VoiceOver announcement. |
| Copy failed (rare) | `.error` | Outcome | — |
| Contrast crosses AA (4.5:1) upward | `.impact(flexibility: .rigid, intensity: 0.7)` | `.increase` is silent on iOS [29]. Rigid tap = "clicked into place" | Use the conditional variant so it only fires on an actual crossing, not on every change. |
| Contrast drops below AA | `.impact(flexibility: .soft, intensity: 0.4)` or `.warning` | `.warning` is semantically closer but heavier; it can feel naggy mid-drag | Owner decision. Throttle to at most once per drag gesture. |
| Any haptic while the Haptics toggle is off | none | HIG "make haptics optional" | Gate every `.sensoryFeedback` through a model flag. |

Gating pattern:

```swift
.sensoryFeedback(trigger: model.aaPassing) {
    guard settings.hapticsEnabled else { return nil }
    return model.aaPassing ? .impact(flexibility: .rigid, intensity: 0.7)
                           : .impact(flexibility: .soft, intensity: 0.4)
}
```

---

## 6. Accessibility Nutrition Labels (App Store)

**What they are.** Labels on the App Store product page that show which accessibility features an app supports, per device type. Shown to users on **iOS/iPadOS/macOS/tvOS/visionOS/watchOS 26 or later** [31]. Announced at WWDC25 (session "Evaluate your app for Accessibility Nutrition Labels", 224 [37]). Declaring is **voluntary now, but Apple says it will become required** for new apps and updates over time [31].

**The nine features** [31]: VoiceOver · Voice Control · Larger Text · Dark Interface · Differentiate Without Color Alone · Sufficient Contrast · Reduced Motion · Captions · Audio Descriptions.

**Rule for claiming.** Users must be able to complete **all common tasks** with the feature on that device. Common tasks are primary functionality, first launch, login, purchase and settings. Use native APIs, and don't build your own VoiceOver/Voice Control substitutes [31]. Re-evaluate on every update [33][34][35][36].

**What Color Shift could claim (iPhone):**

| Label | Claimable? | What it takes |
|---|---|---|
| VoiceOver | Yes, after §3 | Every control labelled; specimen/photo described; actions for next/prev. |
| Voice Control | Yes, likely | Visible text or `accessibilityInputLabels` on icon buttons [21]. Test "Tap Copy". |
| Larger Text | Yes, after §1 | ≥200% (AX3 is enough). No overlap or ambiguous truncation. Zoom/Hover Text don't count [33]. |
| Dark Interface | Yes | App is dark by default [31]. |
| Differentiate Without Color Alone | Yes, if pass/fail and selection carry glyphs by default | Criteria: color must not be the only cue, and the setting should be a last resort [36]. A color-picking app's *content* is color by nature. Common tasks (picking, reading contrast, copying) must still be doable via text values. |
| Sufficient Contrast | Yes, if all UI text ≥4.5:1 and controls ≥3:1 **by default** | Muted label at 5.09:1 passes. Audit every chip and border. Also test with Increase Contrast and Reduce Transparency on [34]. Theme colors that the *user* picks are content. Whether low-contrast user themes affect the claim is **[uncertain]**; the app's own chrome must pass. |
| Reduced Motion | Yes, after §4 | Remove animated blur and scale, stop the shimmer, fade instead [35]. |
| Captions / Audio Descriptions | N/A | No video or audio. Leave unchecked. |

**How to declare** [32]. Required role: Account Holder, Admin, Finance, App Manager or Marketing.
1. App Store Connect › Apps › your app › sidebar **App Accessibility** › **Get Started**.
2. Confirm devices (iPhone) → **Add iPhone Support** → Yes → tick the features → Next.
3. Responses save as a **draft**. Click **Publish**. You can only publish for devices that have a live version. Visibility can take up to 24h.
4. Optional: add an **Accessibility URL** (shown on all devices except Apple TV) [32].

The criteria page also mentions the App Store Connect API for declarations [32] (API not inspected).

---

## 7. Testing

**Xcode Previews.**
- Canvas › **Variants › Dynamic Type Variants** renders every text size at once. The canvas settings button picks a single size [4].
- In code (SwiftUI environment overrides):

```swift
#Preview("AX5") {
    ContentView().environment(\.dynamicTypeSize, .accessibility5)
}
#Preview("xSmall") {
    ContentView().environment(\.dynamicTypeSize, .xSmall)
}
#Preview("Increase contrast") {
    ContentView().environment(\.colorSchemeContrast, .increased)   // settable? [unverified — it is documented get-only]
}
```

`colorSchemeContrast`, `accessibilityReduceMotion` etc. are documented as **`{ get }`** [23][25], so `.environment(\.…, …)` overrides may not compile. Use the Canvas device settings or the simulator instead. A dedicated `PreviewTrait` for Dynamic Type was **not found** (the `PreviewTrait` doc page did not resolve on this pass) **[unverified]**.

**Accessibility Inspector** (Xcode › Open Developer Tool). Inspect labels and traits, run an **Audit** on the simulator/device screen (contrast, clipped text, missing descriptions, hit regions), and use its Settings pane to toggle Dynamic Type, Reduce Motion, Increase Contrast and more live [38][4]. The debug bar's Environment Overrides button in Xcode does the same while running [4].

**Automated audit in XCUITest** (iOS 17+) [38][39][40]:

```swift
final class AccessibilityAuditTests: XCTestCase {
    func testMainScreenAudit() throws {
        let app = XCUIApplication()
        app.launch()
        try app.performAccessibilityAudit()                     // fails the test on any issue
    }

    func testDrawerOpenAudit() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] // [unverified launch arg]
        app.launch()
        app.buttons["Controls"].tap()
        try app.performAccessibilityAudit(for: [.dynamicType, .contrast, .hitRegion, .textClipped]) { issue in
            // Return true to ignore a known false positive, e.g. user-chosen theme colors on the specimen
            issue.auditType == .contrast && issue.element?.identifier == "specimen"
        }
    }
}
```

- Signature: `performAccessibilityAudit(for auditTypes: XCUIAccessibilityAuditType = .all, _ issueHandler: ((XCUIAccessibilityAuditIssue) throws -> Bool)? = nil) throws`. Return `true` to ignore [38][39].
- `XCUIAccessibilityAuditType` members: `.action`, `.all`, `.contrast`, `.dynamicType`, `.elementDetection`, `.hitRegion`, `.parentChild`, `.sufficientElementDescription`, `.textClipped`, `.trait` [40]. (The current doc lives under `XCUIAutomation`. The older `XCTest` URL didn't resolve.)
- Audits only cover what is on screen, so run one per state (drawer collapsed/expanded, each theme). They don't replace manual VoiceOver and Dynamic Type passes [38].

**Manual matrix (recommended by Apple for labels [31]).** Rows are the common tasks: launch, next photo, pick theme, adjust slider, read contrast, copy. Columns are VoiceOver, Voice Control, AX5 text, Reduce Motion, Increase Contrast + Reduce Transparency, Grayscale filter (for Differentiate Without Color [36]), Smart Invert, Bold Text.

---

## Open questions / uncertain

1. **Font choice.** Bundle Manrope + DM Mono (OFL, brand parity) or use SF Pro + SF Mono (free Bold Text and optical sizing)? A hybrid (Manrope only for the specimen) may be the best trade-off.
2. **Does SwiftUI auto-apply Bold Text to `Font.custom`?** Unverified. Plan to handle `legibilityWeight` manually.
3. **`.textCase(.uppercase)` and VoiceOver.** Unverified whether VoiceOver reads the transformed text. Verify on device, or set explicit labels.
4. **System `Slider` haptics on iOS 17/18/26.** Do stepped sliders emit their own detent haptics? Test before adding `.selection` on top.
5. **System sheet vs custom drawer.** A `.sheet` + `presentationDetents` gets free accessibility (an escape gesture, a grabber that is accessible as an adjustable element **[unverified]**). A custom spring drawer needs manual VoiceOver work. Decide in the UI research thread.
6. **Contrast-crossing haptic.** `.increase`/`.decrease` are documented as silent on iOS [29], so the mapping uses impacts. Owner to choose between impact and `.warning` for the downward crossing.
7. **`sensoryFeedback(trigger:_:)` with `(old,new)` closure.** Believed to exist, but not confirmed in the doc topic list fetched.
8. **`Flexibility.solid`.** Resolved: the docs list `.rigid`, `.solid` and `.soft`.
9. **iOS 26 `press(_:)`/`release(_:)`/`selection(_:)` feedback.** These are available only at iOS 26+. Optional `if #available(iOS 26, *)` polish.
10. **Sufficient Contrast with user-chosen themes.** Unclear how App Review treats an app whose *content* can be low-contrast by design. Keep the app chrome compliant, and consider an "AA-safe themes only" default.
11. **Preview environment overrides** for get-only accessibility values may not compile. Use Canvas/simulator settings.
12. **XCUITest launch argument for content size.** `-UIPreferredContentSizeCategoryName` is a long-standing convention, not verified in Apple docs on this pass.

---

## Sources

All accessed 2026-11-24. Apple doc pages were read via their DocC JSON (`developer.apple.com/tutorials/data/…json`), which backs the URLs below.

1. HIG — Typography: https://developer.apple.com/design/human-interface-guidelines/typography
2. HIG — Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
3. HIG — Playing haptics: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
4. WWDC24 — Get started with Dynamic Type (10074): https://developer.apple.com/videos/play/wwdc2024/10074/
5. SwiftUI `dynamicTypeSize(_:)` (range): https://developer.apple.com/documentation/swiftui/view/dynamictypesize(_:)-26aj0
6. SwiftUI `DynamicTypeSize`: https://developer.apple.com/documentation/swiftui/dynamictypesize (and `isAccessibilitySize`: https://developer.apple.com/documentation/swiftui/dynamictypesize/isaccessibilitysize)
7. SwiftUI `ScaledMetric`: https://developer.apple.com/documentation/swiftui/scaledmetric ; `init(wrappedValue:relativeTo:)`: https://developer.apple.com/documentation/swiftui/scaledmetric/init(wrappedvalue:relativeto:)
8. SwiftUI `Font.custom(_:size:relativeTo:)`: https://developer.apple.com/documentation/swiftui/font/custom(_:size:relativeto:)
9. SwiftUI `AnyLayout`: https://developer.apple.com/documentation/swiftui/anylayout
10. SwiftUI `ViewThatFits`: https://developer.apple.com/documentation/swiftui/viewthatfits
11. SwiftUI `accessibilityShowsLargeContentViewer()`: https://developer.apple.com/documentation/swiftui/view/accessibilityshowslargecontentviewer()
12. SwiftUI `monospacedDigit()`: https://developer.apple.com/documentation/swiftui/view/monospaceddigit()
13. UIKit — Adding a custom font to your app: https://developer.apple.com/documentation/uikit/adding-a-custom-font-to-your-app
14. Google Fonts repo metadata — DM Mono: https://raw.githubusercontent.com/google/fonts/main/ofl/dmmono/METADATA.pb ; Manrope: https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/METADATA.pb
15. `AccessibilityNotification.Announcement`: https://developer.apple.com/documentation/accessibility/accessibilitynotification/announcement ; `post()`: https://developer.apple.com/documentation/accessibility/accessibilitynotification/announcement/post()
16. SwiftUI `accessibilityAdjustableAction(_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityadjustableaction(_:)
17. SwiftUI `accessibilityAction(named:_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityaction(named:_:) ; `accessibilityAction(_:_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityaction(_:_:)
18. SwiftUI `accessibilityElement(children:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityelement(children:) ; `AccessibilityChildBehavior`: https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior
19. SwiftUI `accessibilityRotor(_:entries:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityrotor(_:entries:)
20. SwiftUI `accessibilityRepresentation(representation:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityrepresentation(representation:)
21. SwiftUI `accessibilityInputLabels(_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityinputlabels(_:)
22. SwiftUI `accessibilityHidden(_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityhidden(_:)
23. SwiftUI `accessibilityReduceMotion`: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion
24. SwiftUI `accessibilityReduceTransparency`: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency
25. SwiftUI `colorSchemeContrast`: https://developer.apple.com/documentation/swiftui/environmentvalues/colorschemecontrast
26. SwiftUI `accessibilityDifferentiateWithoutColor`: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilitydifferentiatewithoutcolor
27. SwiftUI `legibilityWeight`: https://developer.apple.com/documentation/swiftui/environmentvalues/legibilityweight
28. SwiftUI `accessibilityIgnoresInvertColors(_:)`: https://developer.apple.com/documentation/swiftui/view/accessibilityignoresinvertcolors(_:)
29. SwiftUI `SensoryFeedback` (+ member pages `alignment`, `levelChange`, `pathComplete`, `start`, `stop`, `increase`, `decrease`, `selection`, `success`, `warning`, `error`, `impact`, `impact(weight:intensity:)`, `impact(flexibility:intensity:)`, `Weight`, `Flexibility`, `PressFeedback`, `press(_:)`, `selection(_:)`): https://developer.apple.com/documentation/swiftui/sensoryfeedback
30. SwiftUI `sensoryFeedback(_:trigger:)`: https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:) ; `sensoryFeedback(_:trigger:condition:)`: https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:condition:) ; `sensoryFeedback(trigger:_:)`: https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(trigger:_:)
31. App Store Connect Help — Overview of Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
32. App Store Connect Help — Manage Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels
33. App Store Connect Help — Larger Text evaluation criteria: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria
34. App Store Connect Help — Sufficient Contrast evaluation criteria: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria
35. App Store Connect Help — Reduced Motion evaluation criteria: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria
36. App Store Connect Help — Differentiate Without Color Alone evaluation criteria: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/differentiate-without-color-alone-evaluation-criteria
37. WWDC25 — Evaluate your app for Accessibility Nutrition Labels (224) — seen in search results only, not read: https://developer.apple.com/videos/play/wwdc2025/224/
38. WWDC23 — Perform accessibility audits for your app (10035): https://developer.apple.com/videos/play/wwdc2023/10035/
39. XCUIAutomation `performAccessibilityAudit(for:_:)`: https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)
40. XCUIAutomation `XCUIAccessibilityAuditType`: https://developer.apple.com/documentation/xcuiautomation/xcuiaccessibilityaudittype
41. SwiftUI `AccessibilityTraits.updatesFrequently`: https://developer.apple.com/documentation/swiftui/accessibilitytraits/updatesfrequently
42. UIKit `UIAccessibility.isVoiceOverRunning`: https://developer.apple.com/documentation/uikit/uiaccessibility/isvoiceoverrunning
