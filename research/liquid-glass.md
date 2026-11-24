# Liquid Glass for the Color Shift iOS port

Last checked: 2026-11-24

Scope: Liquid Glass as introduced in iOS 26 (WWDC25), what changed in iOS 26.x and in iOS 27 (WWDC26, shipped September 2026), and how a single-screen SwiftUI app with a deployment target of iOS 17 should adopt it.

---

## TL;DR

- **What it is.** Liquid Glass is a dynamic material for the *functional layer*: controls and navigation that float above content. It blurs what's behind it, reflects color and light from the content around it, and reacts to touch [1][2]. Apple says not to use it in the content layer [2].
- **What you get for free.** When you build with the iOS 26+ SDK, standard bars, sheets, popovers, menus, toolbars and controls adopt it with no code changes. Slider and toggle knobs turn into glass while you drag them. Partial-height sheets get an inset glass background [3][5].
- **Opt-out is gone.** `UIDesignRequiresCompatibility` is ignored when you link against the iOS 27 SDK (Xcode 27). Apple DTS confirmed this is about the SDK you link, not the deployment target [4][6]. Since 2026-04-28 the App Store has required Xcode 26 / the iOS 26 SDK [22]. For a new app, plan on Liquid Glass and don't use the opt-out at all.
- **Core SwiftUI API (iOS 26.0+).**
  - `glassEffect(_:in:)` with `Glass.regular`, `.clear` or `.identity`, plus `.tint(_:)` and `.interactive(_:)`.
  - `GlassEffectContainer(spacing:)`, `glassEffectID(_:in:)`, `glassEffectUnion(id:namespace:)` and `glassEffectTransition(_:)`.
  - `.buttonStyle(.glass)`, `.glass(_:)` and `.glassProminent`.
  - `backgroundExtensionEffect()`, `ToolbarSpacer` and `scrollEdgeEffectStyle(_:for:)` [1][7]–[16].
  - **There is no `glassEffect(_:in:isEnabled:)` in the current docs.** The documented signature is `glassEffect(_:in:)`. To switch glass off conditionally, pass `Glass.identity` [8][9].
- **iOS 27 (WWDC26) added no new glass APIs** to SwiftUI or UIKit, judging by Apple's "What's new" update pages [17][18]. The changes were to the system look:
  - a darker edge around glass and stronger highlights;
  - a user-facing **Liquid Glass slider** (Settings > Appearance) that runs from more clear to more tinted;
  - a more uniform top scroll-edge treatment.

  Existing glass code picks these up automatically [19][20][21].
- **For Color Shift:**
  - The **mixer toggle** and **prev/next** controls should be glass. Use `.regular` (not `.clear`) and an interactive circle, grouped in a `GlassEffectContainer`.
  - The **bottom drawer** may be one glass surface. Use `.regular` in a rounded rect, or a standard sheet if overlaying is acceptable.
  - **Theme chips, sliders' surrounding UI, contrast readouts and copy buttons inside the drawer should *not* be glass.** That would be glass on glass. Use fills and vibrancy instead [2][5].
  - **Never tint the glass with the photo-derived colors.**
- **Deployment target.** Default recommendation: **raise to iOS 26**. As of June 2026, 86% of iPhones from the last four years ran iOS 26 [23], and iOS 27 is now shipping. If iOS 17–25 reach matters, keep 17 and use the `#available` wrapper in §5. It costs about 40 lines of code plus a second visual QA pass.

---

## 1. What Liquid Glass is, automatic adoption, and the compatibility opt-out

### 1.1 Definition

Apple describes it as follows [1]:

> "Liquid Glass is a material that blurs content behind it, reflects color and light of surrounding content, and reacts to touch and pointer interactions in real time. Standard components in SwiftUI use Liquid Glass."

The HIG frames it as a separate layer [2]:

> "Liquid Glass forms a distinct functional layer for controls and navigation elements — like tab bars and sidebars — that floats above the content layer."

Glass adapts to what's behind it [5]:

- **Small elements** such as nav bars and tab bars "flip from light to dark based on the background". Symbols on top of the glass flip with them.
- **Large elements** such as menus and sidebars adapt but don't flip, and appear more opaque.

The HIG color page adds: "Liquid Glass appears more opaque in larger elements like sidebars to preserve legibility" [24].

### 1.2 What adopts it automatically (iOS 26 SDK)

From Apple's "Adopting Liquid Glass" overview [3] and WWDC25 session 323 [25]:

- **Bars, sheets, popovers and controls:** "standard components like bars, sheets, popovers, and controls automatically adopt this material" [3].
- **Toolbars:** items sit on a floating glass surface and are grouped automatically. Use `ToolbarSpacer` to split groups [25].
- **Tab bars and sidebars** float in the glass layer. Tab bars can minimize on scroll with `tabBarMinimizeBehavior(_:)` [3][17].
- **Sheets:** "partial height sheets are inset by default with a Liquid Glass background… When transitioning to a full height sheet, the glass background gradually transitions, becoming opaque" [25]. Apple recommends removing custom `presentationBackground` so the new material shows [25].
- **Menus, action sheets and alerts** adopt glass. Action sheets now originate from their source control [3].
- **Sliders and toggles:** "the knob transforms into Liquid Glass during interaction" [3]. The HIG calls this the one exception to "no glass in the content layer" [2].
- **Buttons:** bordered buttons default to a capsule shape, and there is a new extra-large size [25].
- **Sliders also gained tick marks.** They appear automatically when you pass `step:` [17][25].
- **Scroll edge effect:** an automatic blur/fade under system toolbars [25].

### 1.3 `UIDesignRequiresCompatibility` (Info.plist)

The doc page [4] says:

- Type: Boolean. Introduced in iOS 26.0, iPadOS 26.0, macOS 26.0 and tvOS 26.0.
- "If `YES`, the system runs the app using a compatibility mode for UI elements… displays the app as it looks when built against previous versions of the SDKs."
- Warning text: "Temporarily use this key while reviewing and refining your app's UI for the design in the latest SDKs."
- **"The system ignores this key when you build for iOS 27 or later, iPadOS 27 or later, Mac Catalyst 27 or later, macOS 27 or later, or tvOS 27 or later."**

Apple DTS clarified on the forums in June 2026 [6]:

> "'Build for iOS 27 or later' in this context refers to linking the application against the 27 SDK… It does not refer to setting the deployment target to iOS 27 or running the application on an iOS 27 device."

> "An application linked against the iOS 26 SDK will have `UIDesignRequiresCompatibility` honored by the system even when running on an iOS 27 device."

DTS also said Apple "has not officially announced the iOS 27 SDK requirement date yet" [6]. The pattern has been late April each year. The iOS 26 SDK requirement took effect on 2026-04-28 [22], so an iOS 27 SDK requirement around April 2027 is likely. That date is **unverified**.

**Implication for Color Shift.** The opt-out is a dead end:

- With Xcode 27 it does nothing.
- With Xcode 26 it would only last until the next SDK requirement.

Design for Liquid Glass from day one.

---

## 2. SwiftUI APIs (exact signatures from developer.apple.com)

Everything below is iOS/iPadOS/Mac Catalyst/macOS/tvOS/watchOS **26.0+** unless noted.

### 2.1 `glassEffect(_:in:)`

```swift
nonisolated func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape()
) -> some View
```

The docs [8] say:

- The default shape is a capsule. The material "fills the entirety of the `Text` frame, which includes the padding."
- Apply this modifier **after** other modifiers that affect appearance. It "captures the content to send to the container to render" [1].
- The system renders the glass shape behind the view and also applies glass *foreground* effects over it. SwiftUI uses "a vibrant text color that adapts to maintain legibility against colorful backgrounds" [25].

```swift
Text("Hello").padding().glassEffect()                              // capsule, .regular
Text("Hello").padding().glassEffect(in: .rect(cornerRadius: 16))   // custom shape
Text("Hello").padding().glassEffect(.regular.tint(.orange).interactive())
```

> **Not found:** `glassEffect(_:in:isEnabled:)`. The URL for that overload returns no page, and the What's New pages list only `glassEffect(_:in:)` [8][17]. Earlier betas or blogs may mention it, so treat it as **unverified / not current**. Use `.identity` to disable instead.

### 2.2 `Glass` (struct)

| Member | Signature | Notes |
|---|---|---|
| `regular` | `static var regular: Glass` | Default. Adaptive, legible over anything [9][5]. |
| `clear` | `static var clear: Glass { get }` | Highly translucent, with no adaptive behavior. Docs: "ensure content remains legible by adding a dimming layer" [10]. |
| `identity` | `static var identity: Glass` | "content remains unaffected as if no glass effect was applied" [9]. |
| `tint(_:)` | `func tint(Color?) -> Glass` | Returns a tinted copy [9]. |
| `interactive(_:)` | `func interactive(_ isEnabled: Bool = true) -> Glass` | Scale/bounce/shimmer on touch (iOS) [11][25]. |

Apple's example of `.clear` with a dimming layer [10]:

```swift
Label("Flag", systemImage: "flag.fill")
    .padding()
    .glassEffect(.clear)
    .background(.black.opacity(0.3))
```

### 2.3 `GlassEffectContainer`

```swift
@MainActor @preconcurrency
struct GlassEffectContainer<Content> where Content : View

@MainActor @preconcurrency
init(spacing: CGFloat? = nil, @ContentBuilder content: () -> Content)
```

Notes:

- The init signature shows `@ContentBuilder`, which is the Xcode 27 unified builder that replaces `@ViewBuilder` in signatures. It is source-compatible [12][17].
- The container renders its children's glass together. This is better for performance and lets the shapes blend and morph [12].
- "glass can not sample other glass, so having nearby glass elements in different containers will result in inconsistent behavior" [25].
- **Spacing semantics** [1]: a larger spacing means shapes blend sooner. If the container's spacing is larger than the inner `HStack` spacing, the shapes **merge at rest**.

```swift
GlassEffectContainer(spacing: 20) {
    HStack(spacing: 20) { /* glass buttons */ }
}
```

### 2.4 Morphing: `glassEffectID`, `glassEffectUnion`, `glassEffectTransition`

```swift
nonisolated func glassEffectID(_ id: (some Hashable & Sendable)?, in namespace: Namespace.ID) -> some View
@MainActor @preconcurrency func glassEffectUnion(id: (some Hashable & Sendable)?, namespace: Namespace.ID) -> some View
@MainActor @preconcurrency func glassEffectTransition(_ transition: GlassEffectTransition) -> some View
```

`GlassEffectTransition` has three static members: `.identity`, `.matchedGeometry` (the default when within the container's spacing) and `.materialize` (use for effects farther apart than the spacing) [13][14][1].

```swift
@State private var isExpanded = false
@Namespace private var ns

GlassEffectContainer(spacing: 40) {
    HStack(spacing: 40) {
        Image(systemName: "slider.horizontal.3")
            .frame(width: 48, height: 48)
            .glassEffect(.regular.interactive(), in: .circle)
            .glassEffectID("mixer", in: ns)
        if isExpanded {
            Image(systemName: "doc.on.doc")
                .frame(width: 48, height: 48)
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID("copy", in: ns)
                .glassEffectTransition(.materialize)
        }
    }
}
// toggle with: withAnimation { isExpanded.toggle() }
```

`glassEffectUnion` merges separate views with the same shape and variant into one glass shape at rest [15]. It is useful for a prev/next pair that should read as a single pill.

### 2.5 Button styles

```swift
nonisolated static var glass: GlassButtonStyle { get }                                  // PrimitiveButtonStyle
nonisolated static func glass(_ glass: Glass) -> Self                                   // e.g. .glass(.clear)
@MainActor @preconcurrency static var glassProminent: GlassProminentButtonStyle { get }
nonisolated init(_ glass: Glass)                                                        // GlassButtonStyle, listed as iOS 26.1+
```

Notes:

- `.glassProminent` is "similar to the borderedProminent style". It applies the accent/tint color to the glass background [7][24].
- **Availability conflict.** `PrimitiveButtonStyle.glass(_:)` is listed as iOS 26.0, but `GlassButtonStyle.init(_:)` is listed as iOS **26.1** [7][16]. Guard `.glass(.clear)` with `#available(iOS 26.1, *)` to be safe. This is **unverified**: test on a 26.0 device or simulator.

```swift
Button { toggleMixer() } label: { Image(systemName: "slider.horizontal.3") }
    .buttonStyle(.glass)
    .buttonBorderShape(.circle)
    .controlSize(.large)
```

### 2.6 Other new-design APIs

| API | Signature | Use |
|---|---|---|
| `backgroundExtensionEffect()` | `@MainActor @preconcurrency func backgroundExtensionEffect() -> some View` | Mirrors and blurs a view into the surrounding safe area. Clips the view. Use one instance, "with discretion" [26]. |
| `ToolbarSpacer` | `nonisolated init(_ sizing: SpacerSizing = .flexible, placement: ToolbarItemPlacement = .automatic)` | Splits toolbar glass groups (`.fixed` or `.flexible`) [27]. |
| `scrollEdgeEffectStyle(_:for:)` | `nonisolated func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View` | `.automatic`, `.hard` or `.soft` [28][29]. |
| `scrollEdgeEffectHidden(_:for:)` | `nonisolated func scrollEdgeEffectHidden(_ hidden: Bool = true, for edges: Edge.Set = .all) -> some View` | Removes the edge effect [30]. |
| `safeAreaBar(edge:…)` | `nonisolated func safeAreaBar(edge: HorizontalEdge, alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ContentBuilder content: () -> some View) -> some View` | Like `safeAreaInset` but also extends scroll edge effects. The doc page fetched shows the horizontal-edge variant. A vertical-edge variant is presumed (**unverified**) [31]. |
| `sharedBackgroundVisibility(_:)` | Toolbar item modifier, e.g. `.sharedBackgroundVisibility(.hidden)` | Gives a toolbar item its own unbacked group [25]. Full signature not checked. |
| `buttonSizing(_:)` | `nonisolated func buttonSizing(_ sizing: ButtonSizing) -> some View` | `.flexible` or `.fitted` [32]. |

### 2.7 Sheets with glass

- On iOS 26+, a standard `.sheet` with `presentationDetents` gets inset glass at partial heights automatically [25].
- `presentationBackground(_:)` (iOS 16.4+) still exists. Apple's advice is to **remove** it so the glass shows [25][33].
- On iOS 17–25 the same sheet uses the old opaque or material look. `presentationBackground(.thinMaterial)` is a reasonable fallback there.

```swift
.sheet(isPresented: $showControls) {
    ControlsDrawer()
        .presentationDetents([.height(220), .medium])
        .presentationBackgroundInteraction(.enabled(upThrough: .height(220)))
}
```

Caveat for this app: a sheet *overlays* the canvas. The web drawer *pushes the canvas up*. See §6.

---

## 3. UIKit equivalents (only if needed)

| UIKit | Declaration | Notes |
|---|---|---|
| `UIGlassEffect` | `@MainActor class UIGlassEffect` with `init(style: UIGlassEffect.Style)` | Has `isInteractive` and `tintColor`. `Style` is `.regular` or `.clear` [34][35]. |
| `UIGlassContainerEffect` | `@MainActor class UIGlassContainerEffect` | Has a `spacing` property. Nest `UIVisualEffectView`s that use `UIGlassEffect` in its `contentView` [36]. |
| `UIButton.Configuration.glass()` / `.prominentGlass()` | `static func glass() -> UIButton.Configuration` | iOS 26.0+ [37][38]. |
| `UIBarButtonItem.hidesSharedBackground` | Property | Mentioned in the iOS 27 release notes as a fixed bug [39]. |

```swift
let effect = UIGlassEffect(style: .regular)
effect.isInteractive = true
let glassView = UIVisualEffectView(effect: effect)
glassView.layer.cornerRadius = 24   // UIView.cornerConfiguration also exists (iOS 26) [40]; doc page not fetched
```

A community workaround [40] for glass that distorts under `rotationEffect` is to wrap the UIKit `UIVisualEffectView(effect: UIGlassEffect)` in a `UIViewRepresentable`. Color Shift doesn't rotate glass, so it shouldn't need this.

---

## 4. HIG guidance

### 4.1 When to use glass, and when not to

- **"Don't use Liquid Glass in the content layer."** Use standard materials for content-layer elements. The exception is "controls in the content layer with a transient interactive element like sliders and toggles" [2].
- **"Use Liquid Glass effects sparingly… Limit these effects to the most important functional elements in your app."** [2][3]
- **"Always avoid glass on glass.** Stacking Liquid Glass elements on top of each other can quickly make the interface feel cluttered." For elements placed on glass, "use fills, transparency, and vibrancy for the top elements to make them feel like a thin overlay that is part of the material." [5]
- **"In steady states, such as when an app first launches, avoid intersections between content and Liquid Glass.** Reposition or scale the content to maintain separation." [5]
- Check for crowding or overlap: "avoid overcrowding or layering Liquid Glass elements on top of each other" [3].
- Prefer the system button styles over custom glass: "Instead of creating buttons with custom Liquid Glass effects… use one of the following button style APIs" [3].

### 4.2 Regular vs clear, and legibility over colorful or changing backgrounds

- **Regular** "blurs and adjusts the luminosity of background content to maintain legibility". Use it "when background content might create legibility issues, or when components have a significant amount of text" [2].
- **Clear** "should only be used when these 3 conditions are met" [5]:
  1. the element is over media-rich content;
  2. the content layer won't be harmed by a dimming layer;
  3. the content on top of the glass is bold and bright.
- The HIG's dimming advice: "If the underlying content is bright, consider adding a dark dimming layer of 35% opacity" [2]. "Regular and Clear… should never be mixed" [5].
- **Color** [24]:
  - "Avoid using similar colors in control labels if your app has a colorful background… prefer a monochromatic appearance for toolbars and tab bars."
  - "Be aware of the placement of color in the content layer… make sure its default or resting state… maintains clear legibility."
  - Buttons HIG: "Avoid applying a similar color to button labels and content layer backgrounds" [41].

**For Color Shift:** the background is an arbitrary photo plus an arbitrary fg/bg color pair, so use `.regular`. `.clear` would need a 30–35% black dimming layer, which fails on dark photos and is extra work. Keep glyphs monochrome and system-adaptive. Don't set `.foregroundStyle(themeColor)` on glass controls.

### 4.3 Tinting

- "Tinting should only be used to bring emphasis to primary elements and actions… Avoid tinting all your elements… If you want to imbue color into your app, do it in the content layer instead." [5]
- "Apply color sparingly… To emphasize primary actions, apply color to the background rather than to symbols or text… Refrain from adding color to the background of multiple controls." [24]
- Tint generates "a range of tones that are mapped to content brightness underneath" [5]. Tint is therefore still adaptive, but a tint taken from the photo will blend into the photo.
- If you apply color to controls, use system colors or custom colors that have light and dark variants and an increased-contrast option [3].

### 4.4 Accessibility settings

From WWDC25 "Meet Liquid Glass" [5]:

> "Reduced Transparency makes Liquid Glass frostier and obscures more of the content behind it. Increased contrast makes elements predominantly black or white and highlights them with a contrasting border, and Reduced Motion decreases the intensity of some effects and disables any elastic properties for the material. These are available automatically whenever you use the new material."

Additional settings by release:

- **iOS 26.1** added Settings > Display & Brightness > Liquid Glass with **Clear / Tinted** options. Tinted increases opacity and contrast [42][43].
- **iOS 27** replaced that with a continuous **Liquid Glass slider** under Settings > Appearance. It runs from more clear to more tinted, with the default in the middle [19][20][21]. Reports disagree on which direction is which; a hands-on check is needed (**unverified**). Apple's WWDC26 session says the glass "responds automatically" to the slider [17][44].

What the app must still do:

- **Test custom elements** under each setting: Reduce Transparency, Increase Contrast, Reduce Motion, and the Clear/Tinted or slider settings [3].
- **Any non-glass translucency you add** (e.g. an iOS 17–25 `.ultraThinMaterial` fallback, or a dimming layer) should read `@Environment(\.accessibilityReduceTransparency)`. Apple's doc for that value says backgrounds "should not be semi-transparent; they should be opaque" [45].
- **Custom morph animations** you drive with `withAnimation` should respect `accessibilityReduceMotion`. The glass's own elasticity is reduced automatically [5].

---

## 5. Back-deployment: glass on 26+, materials on 17–25

There is no Apple backport [46]. Gate each glass API with `#available` and provide a material fallback.

### 5.1 A wrapper modifier

```swift
import SwiftUI

/// Liquid Glass on iOS 26+, a material on iOS 17–25.
struct AdaptiveGlass<S: Shape>: ViewModifier {
    var shape: S
    var interactive: Bool = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // System glass already handles Reduce Transparency / Increase Contrast.
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            content
                .background(reduceTransparency ? AnyShapeStyle(Color(.systemBackground))
                                               : AnyShapeStyle(.ultraThinMaterial),
                            in: shape)
                .overlay(shape.stroke(.white.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        }
    }
}

extension View {
    func adaptiveGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(AdaptiveGlass(shape: shape, interactive: interactive))
    }

    @ViewBuilder
    func adaptiveGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
    }
}

/// Container that is a GlassEffectContainer on 26+ and a no-op otherwise.
struct AdaptiveGlassContainer<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            content()
        }
    }
}
```

Notes and caveats:

- **No morphing on 17–25.** `glassEffectID`, `glassEffectUnion` and `glassEffectTransition` can only be called inside an `if #available(iOS 26.0, *)` branch. On older OSes, use `matchedGeometryEffect` or a plain transition if anything.
- **Placing `#available` checks.** Putting them inside a `ViewModifier`/`View` body, as above, is the standard pattern. SwiftUI result builders support `if #available` through `buildLimitedAvailability` [47].
- **Backport libraries.** Community libraries such as Superwall's SwiftUI-Backports (`.backport.glassEffect`) and UniversalGlass do this for you [46]. They aren't needed for a handful of call sites.
- **Building.** You must build with Xcode 26+ for these symbols to compile. The App Store has required that since 2026-04-28 [22], and Xcode 27 is current [48]. Building with Xcode 27 also means `UIDesignRequiresCompatibility` is ignored (§1.3).
- **Fallback look.** The iOS 17–25 version will look like a 2023-era frosted panel. That's acceptable, but it needs its own visual QA over light and dark photos.

### 5.2 Should Color Shift raise the deployment target to iOS 26?

Adoption data:

- Apple's last published iOS 26 numbers, measured on 2026-06-07 from App Store transactions, show 86% of iPhones introduced in the last four years on iOS 26. February's figure was 74% of those iPhones and 66% of all active iPhones [23][49].
- iOS 27 shipped in September 2026. Apple hasn't published iOS 27 adoption numbers in anything found.
- StatCounter's much lower early-2026 figures measure web traffic and were disputed [49].

| Option | Pros | Cons |
|---|---|---|
| **Raise to iOS 26** (recommended default) | One visual design and one QA matrix. Use every glass API directly with no `#available` noise. Morphing works everywhere. Matches the app's photo-first, floating-control design. | Drops users on iOS 17–25. That's roughly ≤14% of recent iPhones as of June 2026, likely less by now. It also drops devices that can't run iOS 26: iPhone XS/XS Max/XR (**unverified**, from memory). |
| **Keep iOS 17 + fallbacks** | Maximum reach. The wrapper is small (§5.1). | Two looks to design and test. No morphing on old OSes. Small, ongoing `#available` maintenance. iOS 17-only API differences (e.g. `@Entry`, iOS 18) may also creep in. |

Recommendation: **Raise to iOS 26** unless there is a concrete reason to serve iOS 17–25 users. Color Shift is a small, new, single-screen app, so the cost of a second visual path is large relative to the app. If you keep 17, use the `AdaptiveGlass` wrapper only, so that removing it later is a one-file change.

---

## 6. Concrete recommendations for Color Shift

Layering model:

- **Content layer:** the photo plus the type specimen. Never glass.
- **Functional layer:**
  - the mixer toggle;
  - the prev/next controls;
  - the drawer *surface*.

  These float above the content, which is the HIG's intended use [2].

| Element | Glass? | Recommendation |
|---|---|---|
| **Mixer toggle** (circular, 3rem ≈ 48pt) | **Yes** | `Button` + `.buttonStyle(.glass)` + `.buttonBorderShape(.circle)`, or `.glassEffect(.regular.interactive(), in: .circle)` on a 48×48 frame (44pt minimum hit target). Use `.regular`, not `.clear`, because the background is arbitrary. Show the "on" state with a symbol change (e.g. `slider.horizontal.3` to `xmark`) or `.glassProminent`. **Don't** tint it with the photo-derived fg/bg color. Add `.contentShape(.circle)` so the whole glass area is tappable (see the hit-testing pitfall in §7). Add an accessibility label. |
| **Prev / next** | **Yes** | Two circular glass buttons, or one pill using `glassEffectUnion`, in the same `GlassEffectContainer` as the mixer if they sit near it. Monochrome SF Symbols (`chevron.left` / `chevron.right`). If they sit at the screen edges far from each other, separate effects are fine. Keep them in one container if they're within the container spacing [25]. |
| **Bottom drawer background** | **Yes, as one surface** (or a system sheet) | **Option A** (matches the web "pushes canvas up"): a custom panel placed with `safeAreaInset(edge: .bottom)`, or `safeAreaBar` on 26, with `.glassEffect(.regular, in: .rect(cornerRadius: 28))` (or `ConcentricRectangle`, **unverified** name). Large glass reads more opaque, which helps the readouts [24]. **Option B:** a standard `.sheet` with detents. You get inset glass, the opaque full-height transition and accessibility for free, but it overlays the canvas instead of pushing it. Either way, use **one** glass surface for the drawer. |
| **Theme chips** (inside drawer) | **No** | Glass on glass is discouraged [5]. Use capsule fills such as `Color.primary.opacity(0.08)`, or the chip's own swatch colors. Show selection with a stroke or checkmark. The swatches are content (they show colors), so they belong in the content-style rendering. |
| **Sliders** (inside drawer) | **Automatic only** | A system `Slider` turns its knob into glass during drag. That's system behavior and fine [2][3]. Don't add glass to the track. |
| **Contrast readouts** | **No** | Plain text in `.primary` / `.secondary`, which are vibrant on glass. Use `monospacedDigit()`. |
| **Copy buttons** (inside drawer) | **No glass style** | Use `.buttonStyle(.bordered)` or `.borderless` with an SF Symbol. Don't use `.glass` inside a glass drawer. Use `.glassProminent` at most once, if there is a single primary action. Give feedback with `sensoryFeedback` or a symbol swap. |
| **Type specimen / photo** | **No** | Content layer. Optionally use `backgroundExtensionEffect()` on the photo if you want it to bleed under the drawer or safe areas (iOS 26) [26]. Use it on one instance only, and note that it clips. |

Extra guidance:

- Group the floating buttons in one `GlassEffectContainer`, both for performance and for consistent sampling [1][25].
- Optional: give the mixer button and the drawer the same `glassEffectID` namespace so the button morphs into the drawer. This works only if both are in the same container. Test it, because morphs with `Menu` and some shapes have had bugs (§7).
- At launch, keep the specimen text from sitting underneath glass controls [5].
- Test over very bright (white) and very dark photos with Reduce Transparency, Increase Contrast, and the iOS 27 slider at both ends.

Sketch:

```swift
@Namespace private var glassNS

ZStack(alignment: .bottom) {
    CanvasView(photo: photo, pair: pair)            // content layer, no glass
        .ignoresSafeArea()
}
.overlay(alignment: .topTrailing) {
    GlassEffectContainer(spacing: 12) {
        HStack(spacing: 12) {
            Button("Previous", systemImage: "chevron.left", action: prev)
            Button("Next", systemImage: "chevron.right", action: next)
            Button(isOpen ? "Close controls" : "Open controls",
                   systemImage: isOpen ? "xmark" : "slider.horizontal.3") {
                withAnimation(.smooth) { isOpen.toggle() }
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }
    .padding()
}
.safeAreaInset(edge: .bottom) {
    if isOpen {
        ControlsDrawer()                                // chips/sliders/readouts: NOT glass
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

---

## 7. Known pitfalls and bugs

Most reports are from iOS 26.0–26.1. Apple doesn't publish a single known-issues list for glass.

1. **Performance.** "Creating too many Liquid Glass effect containers and applying too many effects to views outside of containers can degrade performance. Limit the use of Liquid Glass effects onscreen at the same time." [1] Use `GlassEffectContainer` to combine effects [3]. A container merges glass into one backdrop layer, which reduces offscreen passes [40]. Use `backgroundExtensionEffect` on at most one view [26].
2. **Glass on glass and nesting.** Glass can't sample other glass, so nearby glass in *different* containers looks inconsistent [25]. Avoid stacking glass layers [5]. No official guidance on nesting containers was found, so **treat nested `GlassEffectContainer`s as unsupported or untested**.
3. **Modifier order.** Apply `glassEffect` after padding, frame and other appearance modifiers [1].
4. **Hit testing.** On glass buttons, sometimes only the symbol is tappable even though the glass highlights. Fix with `.contentShape(...)` [40]. Separately, a community report says close-together interactive glass with no explicit shape can merge and "swallow" taps. The fix is an explicit shape and spacing. The original post 404'd when fetched, so this is **unverified** [50].
5. **`Menu` with glass.**
   - iOS 26.0–26.0.1: the morph started as a rectangle. Workaround: put the glass on the `Menu`, not its label.
   - iOS 26.1: a `Menu` inside a `GlassEffectContainer` loses its morph. Workaround: a custom `ButtonStyle` applying the glass, and keep `Menu` out of containers [40].
   - A Menu label also briefly flashes black after dismissal [51].

   Color Shift currently has no menus. Avoid adding them to the glass cluster.
6. **`rotationEffect`** distorts the glass shape during animation. This was present through the iOS 26 RC [40][52].
7. **Device vs simulator.** There are reports of `.glassEffect()` rendering dark or muddy on device while it looked right in the simulator [53]. **Always check on a real device.**
8. **Popovers** presented from a glass container may not get glass [54].
9. **Reduce Transparency + hidden tab bar** left an opaque band and its safe-area space behind (iOS 26) [55]. This doesn't apply to Color Shift (no tab bar).
10. **Toolbar shared background.** iOS 27 fixed a bug where a bottom toolbar lost its background when using `UIBarButtonItem.hidesSharedBackground` (174773785) [39].
11. **Xcode 27 `@State` macro.** A `@State` property that has a default value *and* is assigned in `init` is now a compile error [17][56]. This isn't glass-specific, but it will hit a port.
12. **iOS 27 visual change without recompiling.** Glass gained darker edges and brighter highlights, and the user can move the transparency slider [19][20]. Re-check legibility on iOS 27, since screenshots from 26 aren't representative.

---

## API availability table

| API | iOS | Notes / source |
|---|---|---|
| `View.glassEffect(_:in:)` | 26.0 | [8] |
| `Glass.regular` / `.clear` / `.identity` | 26.0 | [9][10] |
| `Glass.tint(_:)`, `Glass.interactive(_:)` | 26.0 | [9][11] |
| `GlassEffectContainer.init(spacing:content:)` | 26.0 | [12] |
| `glassEffectID(_:in:)` | 26.0 | [13] |
| `glassEffectUnion(id:namespace:)` | 26.0 | [15] |
| `glassEffectTransition(_:)`, `GlassEffectTransition` (`.identity`, `.matchedGeometry`, `.materialize`) | 26.0 | [14] |
| `PrimitiveButtonStyle.glass`, `.glassProminent` | 26.0 | [7] |
| `PrimitiveButtonStyle.glass(_:)` | 26.0 per its page; `GlassButtonStyle.init(_:)` is 26.1 | [16]. The conflict is unresolved, so guard with 26.1. |
| `backgroundExtensionEffect()` | 26.0 | [26] |
| `ToolbarSpacer` | 26.0 (iOS/iPadOS/Catalyst/macOS) | [27] |
| `scrollEdgeEffectStyle(_:for:)`, `scrollEdgeEffectHidden(_:for:)`, `ScrollEdgeEffectStyle` | 26.0 | [28][29][30] |
| `safeAreaBar(edge:alignment:spacing:content:)` | 26.0 | [31] |
| `buttonSizing(_:)` | 26.0 | [32] |
| `tabBarMinimizeBehavior(_:)` | 26.0 | [17] |
| `presentationBackground(_:)` | 16.4 | [33] |
| `Material` (`.ultraThinMaterial`, etc.) | 15.0 | Fallback. The 15.0 version comes from general knowledge and wasn't re-checked. |
| `UIGlassEffect`, `UIGlassContainerEffect` | 26.0 | [34][36] |
| `UIButton.Configuration.glass()` / `.prominentGlass()` | 26.0 | [37][38] |
| `UIDesignRequiresCompatibility` | 26.0. Ignored when linked against the 27 SDK | [4][6] |
| `glassEffect(_:in:isEnabled:)` | **Not found** | Don't use. |
| WWDC26/iOS 27 glass-specific APIs | **None found** | The 27 additions are toolbar APIs: `visibilityPriority`, `ToolbarOverflowMenu`, `.topBarPinnedTrailing`, `toolbarMinimizationBehavior(_:for:)`. The SwiftUI session said visibility priority is back-ported to iOS 17 [17][44]. |

---

## Open questions / uncertain

- **iOS 27 SDK App Store deadline.** Not announced as of the June 2026 DTS reply [6]. Probably around April 2027 (**unverified**).
- **`PrimitiveButtonStyle.glass(_:)` availability**: 26.0 or 26.1? The doc pages conflict [16].
- **`ConcentricRectangle` / container-concentric shapes.** These are referenced in the adoption guide's list of APIs for "shapes concentric to their containers" [3], but their signatures weren't fetched. **Unverified.**
- **Direction of the iOS 27 Liquid Glass slider.** Press coverage disagrees [19][20][21]. Is there any developer API to read the slider's value? None was found, and the system appears to handle it.
- **Does `glassEffect(.identity)` behave exactly like no modifier** for layout and hit-testing? The docs say "content remains unaffected" [9]. Not tested.
- **Nested `GlassEffectContainer`.** No Apple guidance found.
- **Morph between the mixer button and the drawer.** Is it smooth when the drawer is a large rounded rect and the button is a circle? The docs suggest yes when they're in the same container. Needs a prototype.
- **iOS 26 device support** (XS/XR dropped). From memory, not verified this session.
- **Current iOS 26 + 27 combined share** for November 2026. No Apple data after June 2026 was found.
- **Whether `toolbarMinimizationBehavior(_:for:)` (June 2026 docs) and `toolbarMinimizeBehavior` (the WWDC26 video) are the same API.** The docs list the former, so prefer the docs spelling [17][44].

---

## Sources

1. Applying Liquid Glass to custom views — https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
2. HIG: Materials — https://developer.apple.com/design/human-interface-guidelines/materials
3. Adopting Liquid Glass (technology overview) — https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
4. UIDesignRequiresCompatibility — https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility
5. WWDC25 "Meet Liquid Glass" (session 219) — https://developer.apple.com/videos/play/wwdc2025/219/
6. Apple Developer Forums: Clarification on the planned removal of UIDesignRequiresCompatibility — https://developer.apple.com/forums/thread/832543
7. PrimitiveButtonStyle.glass / .glassProminent — https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass and https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent
8. View.glassEffect(_:in:) — https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
9. Glass — https://developer.apple.com/documentation/swiftui/glass
10. Glass.clear — https://developer.apple.com/documentation/swiftui/glass/clear
11. Glass.interactive(_:) — https://developer.apple.com/documentation/swiftui/glass/interactive(_:)
12. GlassEffectContainer and init(spacing:content:) — https://developer.apple.com/documentation/swiftui/glasseffectcontainer
13. glassEffectID(_:in:) — https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:)
14. glassEffectTransition(_:) and GlassEffectTransition — https://developer.apple.com/documentation/swiftui/view/glasseffecttransition(_:) and https://developer.apple.com/documentation/swiftui/glasseffecttransition
15. glassEffectUnion(id:namespace:) — https://developer.apple.com/documentation/swiftui/view/glasseffectunion(id:namespace:)
16. PrimitiveButtonStyle.glass(_:) and GlassButtonStyle.init(_:) — https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass(_:) and https://developer.apple.com/documentation/swiftui/glassbuttonstyle
17. SwiftUI updates (June 2025, June 2026, September 2026) — https://developer.apple.com/documentation/updates/swiftui
18. UIKit updates — https://developer.apple.com/documentation/updates/uikit
19. MacRumors: Here's How Liquid Glass Is Changing in iOS 27 — https://www.macrumors.com/2026/06/10/how-liquid-glass-is-changing-in-ios-27
20. 9to5Mac: iOS 27 adds new Liquid Glass slider — https://9to5mac.com/2026/06/15/ios-27-adds-new-liquid-glass-slider-on-iphone-heres-what-it-lets-you-do/
21. MacStories: iOS and iPadOS 27 review — https://www.macstories.net/stories/ios-and-ipados-27-review/2/
22. Apple: Upcoming requirements / SDK minimum requirements — https://developer.apple.com/news/upcoming-requirements/
23. MacRumors: Apple Reveals How Many iPhones Were Running iOS 26 Before WWDC — https://www.macrumors.com/2026/06/09/ios-26-adoption-stats-wwdc/
24. HIG: Color (Liquid Glass color) — https://developer.apple.com/design/human-interface-guidelines/color
25. WWDC25 "Build a SwiftUI app with the new design" (session 323) — https://developer.apple.com/videos/play/wwdc2025/323/
26. backgroundExtensionEffect() — https://developer.apple.com/documentation/swiftui/view/backgroundextensioneffect()
27. ToolbarSpacer and init(_:placement:) — https://developer.apple.com/documentation/swiftui/toolbarspacer
28. scrollEdgeEffectStyle(_:for:) — https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)
29. ScrollEdgeEffectStyle — https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle
30. scrollEdgeEffectHidden(_:for:) — https://developer.apple.com/documentation/swiftui/view/scrolledgeeffecthidden(_:for:)
31. safeAreaBar(edge:alignment:spacing:content:) — https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)
32. buttonSizing(_:) — https://developer.apple.com/documentation/swiftui/view/buttonsizing(_:)
33. presentationBackground(_:) — https://developer.apple.com/documentation/swiftui/view/presentationbackground(_:)
34. UIGlassEffect — https://developer.apple.com/documentation/uikit/uiglasseffect
35. UIGlassEffect.Style / init(style:) — https://developer.apple.com/documentation/uikit/uiglasseffect/style
36. UIGlassContainerEffect — https://developer.apple.com/documentation/uikit/uiglasscontainereffect
37. UIButton.Configuration.glass() — https://developer.apple.com/documentation/uikit/uibutton/configuration-swift.struct/glass()
38. UIButton.Configuration.prominentGlass() — https://developer.apple.com/documentation/uikit/uibutton/configuration-swift.struct/prominentglass()
39. iOS & iPadOS 27 release notes — https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
40. JuniperPhoton: Adopting Liquid Glass: Experiences and Pitfalls — https://juniperphoton.substack.com/p/adopting-liquid-glass-experiences
41. HIG: Buttons — https://developer.apple.com/design/human-interface-guidelines/buttons
42. MacRumors: iOS 26.1 Beta 4 Lets Users Control Liquid Glass Transparency — https://www.macrumors.com/2025/10/20/ios-26-1-liquid-glass-toggle/
43. TechCrunch: iOS 26.1 lets you turn down Liquid Glass transparency — https://techcrunch.com/2025/11/04/ios-26-1-lets-you-turn-down-liquid-glass-transparency/
44. WWDC26 "What's new in SwiftUI" (session 269) — https://developer.apple.com/videos/play/wwdc2026/269
45. EnvironmentValues.accessibilityReduceTransparency — https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency
46. Apple Developer Forums thread on glassEffect back-deployment — https://developer.apple.com/forums/thread/806630 (as summarized in search results; not opened directly)
47. Swift Forums: Availability for modifiers — https://forums.swift.org/t/availability-for-modifiers/58913 (search-result summary)
48. Xcode release notes index (Xcode 27.x present) — https://developer.apple.com/documentation/xcode-release-notes
49. 9to5Mac: Apple announces iOS 26 usage numbers — https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/
50. DEV Community: iOS 26 Liquid Glass gotcha: adjacent buttons swallowing taps — https://dev.to/daksh-gargas/ios-26-liquid-glass-gotcha-adjacent-buttons-silently-swallowing-taps-3124 (returned 404 when fetched; search-snippet only)
51. Apple Developer Forums: Liquid Glass Menu briefly turns black — https://developer.apple.com/forums/thread/826863 (search-result summary)
52. Apple Developer Forums: glassEffect geometry bug when using rotationEffect — https://developer.apple.com/forums/thread/800225 (search-result summary)
53. Apple Developer Forums: .glassEffect() renders dark on device — https://developer.apple.com/forums/thread/814005 (search-result summary)
54. Apple Developer Forums: popover from glass container lacks glass — https://developer.apple.com/forums/thread/804141 (search-result summary)
55. Apple Developer Forums: Reduce Transparency / tab bar issue — https://developer.apple.com/forums/thread/828566 (search-result summary)
56. DEV Community: WWDC26 What's New in SwiftUI breakdown — https://dev.to/arshtechpro/wwdc26-whats-new-in-swiftui-a-developers-breakdown-1333
