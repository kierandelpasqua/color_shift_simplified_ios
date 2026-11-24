# SwiftUI Architecture & Layout Patterns for Color Shift (iOS)

Last checked: 2026-11-24

Scope: architecture, layout, animation, image, gesture, persistence and project-structure patterns for the native SwiftUI port of "Color Shift". The target is iOS 17+, portrait-first, single screen. Current toolchain on the dev machine is **Xcode 27.2 / Swift 6.4.2**. Xcode 27 ships the iOS 27 SDK and "supports on-device debugging in iOS 17 and later" [9], so iOS 17 is also the lowest OS you can debug on with current Xcode. "iOS 26+" in this document means "first available in the iOS 26 SDK".

Citation style: `[n]` points to the Sources list at the end. **unverified** means I could not confirm the claim from a fetched source; it is my reasoning or general knowledge and should be checked on device.

---

## TL;DR (recommendations for this app)

1. **State:** one `@Observable final class AppModel`, owned with `@State` in the `App` struct and injected with `.environment(model)`. Views read it with `@Environment(AppModel.self)` and use `@Bindable` only where they need `$` bindings (sliders) [1][2][4]. Don't use `ObservableObject`. Everything is available on iOS 17.
2. **Concurrency:** keep Xcode's **Default Actor Isolation = MainActor** and turn on **Approachable Concurrency** [5][6][7]. Mark the pure color math (`ContrastMath`, `ColorPair`, the APCA/WCAG functions) `nonisolated` so tests and any background work can call it synchronously [8].
3. **Drawer that pushes:** use a root `VStack(spacing: 0) { Canvas; if open { Drawer } }` and animate `isDrawerOpen` with the spring below. Don't use `.sheet` / `presentationDetents`, which present modally *over* content [18][19]. Use `onGeometryChange` (back-deploys to iOS 16) if you need the drawer's measured height [14].
4. **2-pane split:** use a tiny custom `Layout` (iOS 16) that takes a `fraction`, or two equally flexible frames for a 50/50 split. Avoid `containerRelativeFrame` here: its "container" is the screen/scroll view, not the parent VStack, so it won't react to the drawer pushing the canvas [13].
5. **Spring:** use `.spring(Spring(mass: 1.7, stiffness: 340, damping: 36))` (iOS 17) or the equivalent `.spring(response: 0.444, dampingFraction: 0.749)` (iOS 13). I confirmed the mapping numerically with SwiftUI's own `Spring` type: response 0.4443 s, dampingRatio 0.7487, peak overshoot 2.88%. Apple's `settlingDuration` is 0.88 s, not 0.65 s; see §4 [21][22].
6. **Photo reveal:** a custom `Transition` (iOS 17) doing opacity 0→1, scale 1.04→1 and blur 8→0. Apply it to the photo view keyed with `.id(photoIndex)` and animate with `.easeOut(duration: 0.6)` [31]. Fall back to opacity only when Reduce Motion is on [37].
7. **Chip wave:** `keyframeAnimator(initialValue:trigger:)` with a per-letter delay, triggered by selection (iOS 17) [28][30].
8. **Images:** ship the 12 JPEGs as plain bundle resources rather than in the asset catalog, so you can downsample with ImageIO (`CGImageSourceCreateThumbnailAtIndex` with `ThumbnailMaxPixelSize` ≈ screen pixels) [43]–[47]. Display with `.resizable().scaledToFill()` inside a fixed frame, plus `.clipped()` **and** `.contentShape(Rectangle())` [41].
9. **Tap to advance:** use exactly one handler, either a `Button` with `.buttonStyle(.plain)` (preferred for accessibility) or one `onTapGesture`, on the photo pane. No `simultaneousGesture`, no nested handlers. Optionally ignore taps while a reveal is in flight using `withAnimation(...) completion:` [27][52].
10. **Persistence/clipboard:** use `UIPasteboard.general.string = …` [54][55]. Persist `photoIndex`, `hueShift` and so on via `UserDefaults` inside `AppModel`, written on `scenePhase == .background` [56]. `@AppStorage` is fine in views but doesn't mix with `@Observable` properties (see §7) [57].
11. **Structure:** ~8 Swift files in `App/`, `Model/`, `Views/` and `Color/` folders, `#Preview` with `@Previewable @State` [59], and a Swift Testing target for the color math (`@Test`, `#expect`, parameterized cases) [60]–[62].

---

## 1. State management

### 1.1 `@Observable` vs `ObservableObject`

- Observation (`@Observable`) is iOS 17+ [1][3]. Compared with `ObservableObject`, it adds tracking of optionals and collections, lets you use plain `@State` / `@Environment` instead of `@StateObject` / `@EnvironmentObject`, and updates only the views whose `body` reads the property that changed [1].
- "SwiftUI updates a view only when an observable property changes and the view's body reads the property directly" [1]. A view that only passes the model through doesn't re-render [2].
- Don't conform to `Observable` by hand; "always use the `Observable` macro" [2].
- Use `@ObservationIgnored` for stored properties that views shouldn't track, such as a cached decoded `UIImage` or a `UserDefaults` handle [1].

Wrapper mapping [1]:

| ObservableObject era | Observation era (iOS 17) |
|---|---|
| `@StateObject var m = M()` | `@State private var m = M()` |
| `@ObservedObject var m: M` | `var m: M` (plain property) or `@Bindable var m: M` if you need `$m.x` |
| `.environmentObject(m)` + `@EnvironmentObject` | `.environment(m)` + `@Environment(M.self)` |
| `@Published var x` | `var x` |

### 1.2 Where to keep `AppModel`

The state is tiny (index, fg/bg, drawer open, tuning values), so use one model owned at the app root:

```swift
// App/ColorShiftApp.swift
@main
struct ColorShiftApp: App {
    @State private var model = AppModel()          // owner
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)                // inject
        }
        .onChange(of: scenePhase) {                // iOS 17 two-arg-less form [58]
            if scenePhase == .background { model.persist() }
        }
    }
}

// Model/AppModel.swift
@Observable
final class AppModel {                             // MainActor by default (see 1.4)
    var photoIndex = 0
    var isDrawerOpen = false
    var theme: Theme = .auto
    var hueShift: Double = 0        // degrees
    var lightness: Double = 0       // -1...1
    @ObservationIgnored private let defaults = UserDefaults.standard

    var photo: Photo { Photo.all[photoIndex] }
    var pair: ColorPair { ColorPair.derive(from: photo.palette, theme: theme,
                                           hue: hueShift, lightness: lightness) } // computed, still tracked [2]

    func advance() { photoIndex = (photoIndex + 1) % Photo.all.count }
}
```

Computed properties that read observed stored properties are tracked [2], so `pair` doesn't need caching unless profiling shows the color math is expensive.

Reading and binding in views:

```swift
struct TuningControls: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model               // local @Bindable to get $bindings
        Slider(value: $model.hueShift, in: -180...180)
    }
}
```

`@Bindable` is iOS 17 [4]. The "local `@Bindable var` inside body" idiom is widely used; Apple's article shows `@Bindable` as a stored property [1]. **unverified** that Apple documents the local-variable form explicitly.

### 1.3 Observation outside views (iOS 26+)

`Observations` (an `AsyncSequence` of transactional changes to `@Observable` values) is **iOS 26+** [11]. With an iOS 17 floor you'd need `if #available(iOS 26, *)`. The app doesn't need it: `onChange(of:)` in a view, or `didSet`, is enough.

### 1.4 Swift 6 strict concurrency and default MainActor isolation

- SE-0466 (implemented in Swift 6.2) adds `-default-isolation MainActor|nonisolated`. In SwiftPM the equivalent is `.defaultIsolation(MainActor.self)`. Without the flag, the module default is `nonisolated` [5].
- In Xcode the build setting is **Default Actor Isolation**. New Xcode 26 projects default it to `MainActor`; existing projects stay `nonisolated` [7].
- SE-0461 (Swift 6.2, feature flag `NonisolatedNonsendingByDefault`) makes nonisolated `async` functions run on the caller's actor. `@concurrent` opts back into running on the global executor. The **Approachable Concurrency** setting enables this together with related features [6][7].
- Xcode 27 fixed `#Preview` bodies to "explicitly run on the main actor" [9]. Previews can therefore call MainActor-isolated models without warnings.

Implications for Color Shift:

- With MainActor default, every type in the app target (including `struct ColorPair` and free functions) becomes MainActor-isolated [5][8]. That's fine for UI code but awkward for pure math:
  - Swift Testing tests that aren't `@MainActor` would need `await` to call the functions.
  - Future background image analysis (palette extraction) can't call them synchronously.
- **Fix:** mark the pure color layer `nonisolated`, or move it into a local Swift package target that keeps the `nonisolated` default [8]:

```swift
// Color/ContrastMath.swift
nonisolated enum ContrastMath {
    static func wcagRatio(_ a: RGB, _ b: RGB) -> Double { /* … */ }
    static func apcaLc(text: RGB, background: RGB) -> Double { /* … */ }
}
nonisolated struct RGB: Sendable, Equatable { var r, g, b: Double }
```

- Known friction: `Equatable` / `Sendable` conformances and nested types can produce isolation errors under MainActor default, and macros can't see the default [8]. Expect a few one-word `nonisolated` fixes.
- If image downsampling moves off the main thread, write it as `@concurrent func loadImage(...) async -> CGImage?` (Swift 6.2+) [6][8].

---

## 2. Layout

### 2.1 Canvas + bottom panel that pushes content

There are three options:

**A. VStack with a conditional drawer (recommended).** The canvas has `maxHeight: .infinity`. When the drawer is inserted, the VStack re-lays out and the canvas shrinks, so it gets pushed.

```swift
struct RootView: View {
    @Environment(AppModel.self) private var model
    static let drawerSpring = Animation.spring(Spring(mass: 1.7, stiffness: 340, damping: 36))

    var body: some View {
        VStack(spacing: 0) {
            CanvasView()                                   // photo + specimen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if model.isDrawerOpen {
                ControlsDrawer()
                    .transition(.move(edge: .bottom))      // slides in while canvas shrinks
            }
        }
        .overlay(alignment: .bottomTrailing) { MixerButton() }
        .animation(Self.drawerSpring, value: model.isDrawerOpen)
    }
}
```

- Pros: the canvas really reflows, the drawer's height is whatever its content needs, and safe-area handling stays normal.
- Cons: the canvas is resized on every animation frame, so a `scaledToFill` photo is re-cropped per frame. That's cheap for one image. If you see jank, try `.geometryGroup()` on the canvas so it animates as one unit [35] (**unverified** benefit for this case).
- If the design is "canvas keeps its size and translates up" rather than "canvas shrinks", keep the canvas at a fixed height and apply `.offset(y: isOpen ? -drawerHeight : 0)`. Measure `drawerHeight` with `onGeometryChange` (2.2). Which one the web build does is an open question.

**B. `.safeAreaInset(edge: .bottom) { Drawer }`** (iOS 15) [12]. The modified view "is inset by the [size] of content … with its safe area increased by the same amount" [12]. It works when the canvas respects the safe area. A full-bleed photo that uses `.ignoresSafeArea()` will *not* be pushed, though, because it ignores the inset it was given (**unverified**, inferred from the safe-area semantics in [12]). That pitfall applies directly here, so prefer A.

**C. Custom `Layout`** (iOS 16) [16]. Only worth it if you want one container that places canvas, drawer and button with exact math. It's overkill for this app.

### 2.2 Measuring: `GeometryReader` vs `containerRelativeFrame` vs `onGeometryChange`

| API | Min iOS | Use here |
|---|---|---|
| `GeometryReader` [17] | 13 | Avoid as a layout container. It takes all offered space and lays children out top-leading, which is easy to misuse. OK inside `.background {}` for measuring, but `onGeometryChange` is cleaner. |
| `containerRelativeFrame(_:alignment:)` [13] | 17 | Sizes relative to the nearest *container*: window/screen on iOS, NavigationStack, TabView tab, ScrollView, minus safe-area insets [13]. It does **not** track a parent VStack, so it's wrong for "photo = 55% of the canvas". |
| `onGeometryChange(for:of:action:)` [14] | **16** (back-deployed) | Best way to read a size into state, such as the drawer's height. The `transform` closure produces an `Equatable` value and `action` fires only when it changes [14]. |
| `visualEffect { content, proxy in }` [65] | 17 | Geometry-dependent *visual* effects (parallax, scale) with no state writes. |

```swift
ControlsDrawer()
    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { drawerHeight = $0 }
```

### 2.3 Proportional 2-pane photo/specimen split

For a 50/50 split, two children each with `.frame(maxWidth: .infinity, maxHeight: .infinity)` in a `VStack(spacing: 0)` / `HStack` share the space equally (**unverified** wording; this is standard stack behavior). For arbitrary shares (60/40, or animating the share), use a small `Layout` [16]:

```swift
@Animatable                                  // macro from Xcode 26 SDK; docs list iOS 13+ [36]
struct SplitLayout: Layout {
    var fraction: CGFloat                    // share of first child, 0...1
    @AnimatableIgnored var axis: Axis = .vertical

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        if axis == .vertical {
            let h = (b.height * fraction).rounded()
            subviews[0].place(at: b.origin, proposal: .init(width: b.width, height: h))
            subviews[1].place(at: .init(x: b.minX, y: b.minY + h),
                              proposal: .init(width: b.width, height: b.height - h))
        } else {
            let w = (b.width * fraction).rounded()
            subviews[0].place(at: b.origin, proposal: .init(width: w, height: b.height))
            subviews[1].place(at: .init(x: b.minX + w, y: b.minY),
                              proposal: .init(width: b.width - w, height: b.height))
        }
    }
}

// usage
SplitLayout(fraction: 0.58) { PhotoPane(); SpecimenPane() }
```

`Layout` conforms to `Animatable` [16], so the fraction animates once `animatableData` is wired. `@Animatable` synthesizes that [36]. If the macro causes trouble with an iOS 17 target, write `var animatableData: CGFloat { get { fraction } set { fraction = newValue } }` by hand.

### 2.4 `ViewThatFits` (iOS 16) [15]

Use it to choose the first child that fits the available space. It suits the drawer's button row (`HStack` of "Copy link" + "Copy Markdown", falling back to a `VStack` on small phones or at large Dynamic Type). It's not useful for the main split.

For the big "Aa" specimen, use a large font with `.minimumScaleFactor(0.3)` and `.lineLimit(1)` so it shrinks as the canvas gets pushed (**unverified** that this beats a size computed with `onGeometryChange`; test both).

---

## 3. Why not `.sheet` / `presentationDetents` for the drawer

- `presentationDetents` "sets the available detents for the enclosing **sheet**" (iOS 16) [18]. A sheet is a modal presentation layered over the presenter. It never changes the presenter's layout, so the canvas can't be pushed.
- By default SwiftUI disables interaction with the view behind a sheet. You need `.presentationBackgroundInteraction(.enabled(upThrough:))` (iOS 16.4) to re-enable it [19]. Even then, tapping the photo to advance competes with the sheet's own gestures and the dimming.
- Sheet animation timing is system-controlled, so you can't drive it with the custom spring (mass 1.7 / k 340 / c 36). **unverified**: there's no public API to set a sheet's spring.
- From iOS 26, sheets pick up the system "Liquid Glass" look automatically (**unverified** for this doc set; only names were seen in passing). That's another reason it would diverge from the web design.

If a real sheet is wanted later (for example an "About / credits" panel):

```swift
.sheet(isPresented: $showCredits) {
    CreditsView()
        .presentationDetents([.height(220), .medium])             // iOS 16 [18]
        .presentationBackgroundInteraction(.enabled(upThrough: .height(220))) // iOS 16.4 [19]
        .presentationBackground(.thinMaterial)                    // iOS 16.4 [20]
}
```

---

## 4. Animations

### 4.1 Spring APIs

| API | Min iOS | Notes |
|---|---|---|
| `.spring(response:dampingFraction:blendDuration:)` [23] | 13 | Defaults: response 0.5, dampingFraction 0.825. A "persistent" spring that preserves velocity when replaced by another spring [23]. |
| `.interpolatingSpring(mass:stiffness:damping:initialVelocity:)` [24] | 13 | Produces 0→1 values interpolated across [from, to]. Overlapping animations are *additive* ("adding the effects of each animation") [24]. |
| `Spring` struct + `.spring(_ spring: Spring)` [21][25] | 17 | Converts between representations (`mass/stiffness/damping`, `response/dampingRatio`, `duration/bounce`). Exposes `settlingDuration` and `value(target:time:)` [21][22]. |
| `.interpolatingSpring(_ spring: Spring, initialVelocity:)` | 17 | Interpolating variant that takes a `Spring`. |
| `.smooth`, `.snappy`, `.bouncy`, `.spring(duration:bounce:)` [26] | 17 | WWDC23 presets. Springs are now SwiftUI's default animation [26]. |

**Which to use:** use `.spring(Spring(mass: 1.7, stiffness: 340, damping: 36))`. It's iOS 17, matches the web numbers 1:1, and retargets smoothly if the user taps the mixer mid-animation. `interpolatingSpring` adds overlapping animations, which on rapid open/close toggles can overshoot more than one spring would [24].

### 4.2 Verifying the spring mapping

Apple's `Spring` documentation gives two conversions that pin down the formulas [21]:

- `Spring(duration: 0.5, bounce: 0.3)` → `(mass, stiffness, damping) = (1.0, 157.9, 17.6)`
- `Spring(mass: 1, stiffness: 100, damping: 10)` → `(duration, bounce) = (0.63, 0.5)`

Both are consistent with the standard damped-oscillator relations (my derivation, checked against both examples):

```
ω₀            = √(stiffness / mass)
response      = duration = 2π / ω₀              (0.5 → k = (2π/0.5)² = 157.9 ✓; k=100 → 2π/10 = 0.628 ✓)
dampingRatio  = damping / (2·√(stiffness·mass)) (10/(2·10) = 0.5 → bounce 0.5 ✓)
bounce        = 1 − dampingRatio  (underdamped)   (0.3 → ζ 0.7 → c = 2·0.7·12.566 = 17.6 ✓)
```

WWDC23 "Animate with springs" also gives `mass = 1, stiffness = (2π ÷ duration)²` and says `duration` is a *perceptual* duration, distinct from the settling duration [26]. The damping line in the fetched transcript came through garbled. The `Spring` doc examples above are the authority.

**Our values (mass 1.7, stiffness 340, damping 36):**

- ω₀ = √(340/1.7) = √200 = 14.142 rad/s
- response = 2π/14.142 = **0.4443 s** ✓
- dampingFraction = 36 / (2·√(340·1.7)) = 36 / (2·24.042) = **0.7487** ✓ (bounce ≈ 0.251)

I also checked this numerically by running SwiftUI's own `Spring` on macOS 26 / Swift 6.4.2 (local script, not shipped):

```
Spring(mass: 1.7, stiffness: 340, damping: 36)
  response 0.44429  dampingRatio 0.74870  duration 0.44429  bounce 0.25130
  settlingDuration 0.8838 s
  Spring(response:0.44429, dampingRatio:0.74870) → mass 1, stiffness 200, damping 21.18 (same settling 0.8838)
  peak value 1.02878  (→ 2.88 % overshoot)
  last time |x−1| > 1 %: 0.466 s;  > 0.5 %: 0.507 s;  > 0.1 %: 0.564 s
```

Conclusions:

- **Mapping confirmed:** `.spring(response: 0.444, dampingFraction: 0.749)` ⇔ `Spring(mass: 1.7, stiffness: 340, damping: 36)`. Mass only scales the time axis. With mass normalized to 1 the equivalent is stiffness 200, damping 21.18.
- **Overshoot ≈ 2.9%** ✓ (matches the "~3%" claim).
- **Settle time needs a correction.** Displacement stays within 0.1% after ≈ 0.56 s. Apple's `settlingDuration` (epsilon 0.001, target 1, v₀ = 0 [22]) reports **0.88 s**. Apple's figure is ≥ the displacement-only number, presumably because it also accounts for velocity (**unverified**). Either way, "~650 ms settle" is not what SwiftUI reports. Use perceptual `duration` (0.44 s) for "feels done" logic and don't wait on `settlingDuration` [26].

```swift
extension Animation {
    /// Web parity: mass 1.7, stiffness 340, damping 36 (≈ response 0.444 s, ζ 0.749)
    static let drawer: Animation = .spring(Spring(mass: 1.7, stiffness: 340, damping: 36)) // iOS 17
    // iOS 13 equivalent: .spring(response: 0.444, dampingFraction: 0.749)
}
```

### 4.3 `withAnimation` completion (iOS 17)

`withAnimation(_:completionCriteria:_:completion:)` takes a completion that "will always be fired exactly one time". If no animation is created it fires immediately [27]. The default criterion is `.logicallyComplete`, which for springs is earlier than `.removed` [27][26]. Use it for "re-enable taps after the reveal" or "focus first control after the drawer opens":

```swift
withAnimation(.drawer) { model.isDrawerOpen.toggle() } completion: { drawerSettled = true }
```

### 4.4 Chip "wave": `PhaseAnimator` vs `KeyframeAnimator`

- `phaseAnimator(_:trigger:content:animation:)` (iOS 17) steps through discrete phases when `trigger` changes. Without a trigger it loops while visible [28][29]. Use it for simple states (rest → lift → rest).
- `keyframeAnimator(initialValue:trigger:content:keyframes:)` (iOS 17) runs independent tracks (Linear/Spring/Cubic/MoveKeyframe). Velocity is preserved if the trigger re-fires mid-run [28][30]. `content` runs every frame, so keep it cheap [30].
- Apple's guidance: phases for chained discrete states, keyframes for coordinated timing that you fully control. Keyframes "can't retarget gracefully like springs" [28].

A per-letter wave, played once each time the chip becomes selected:

```swift
struct WaveLabel: View {
    let text: String
    let trigger: Int                      // bump when the chip becomes selected
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, y in
                        content.offset(y: reduceMotion ? 0 : y)
                    } keyframes: { _ in
                        KeyframeTrack {                               // whole-value track, iOS 17
                            LinearKeyframe(0, duration: Double(i) * 0.035)   // stagger
                            SpringKeyframe(-3, duration: 0.14, spring: .snappy)
                            SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                        }
                    }
            }
        }
        .accessibilityElement(children: .combine)   // VoiceOver reads the word, not letters
    }
}
```

`KeyframeTrack(content:)` without a key path animates the whole value (iOS 17) [30]. If the web "wave" is actually a moving gradient or shimmer rather than per-letter motion, use `phaseAnimator` driving a `LinearGradient` offset instead. Which effect the web uses is an open question.

### 4.5 Photo reveal transition (opacity + scale + blur)

The `Transition` protocol (iOS 17) is the modern way to write a custom transition. Use `phase.isIdentity` or the `.willAppear` / `.identity` / `.didDisappear` cases, and don't use identity-changing constructs (`if` / `.id`) *inside* the transition body [31]:

```swift
struct PhotoReveal: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase == .willAppear ? 1.04 : 1)
            .blur(radius: phase.isIdentity ? 0 : 8)
    }
}

struct PhotoPane: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            PhotoImage(photo: model.photo)
                .id(model.photoIndex)                                   // new identity ⇒ insertion
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(PhotoReveal()))
        }
        .clipped()                                                     // keep the 1.04 scale inside the pane
        .animation(.easeOut(duration: 0.6), value: model.photoIndex)
    }
}
```

- The built-in `.blurReplace` (iOS 17) combines blur and scale [32]. It's close, but its exact scale and blur values aren't documented, so use the custom transition for parity.
- During the crossfade both old and new photos exist. Make sure the new one draws on top (`zIndex`), or the removal side may cover it (**unverified**; test).
- Blur on a full-screen image every frame for 0.6 s has a GPU cost. Profile on the oldest supported device (**unverified** cost).

### 4.6 `contentTransition` and `matchedGeometryEffect`

- `contentTransition(_:)` (iOS 16) animates changes *within* one view, and only inside an animation context [33]. Use `.contentTransition(.numericText(value: ratio))` (iOS 17) for the WCAG ratio and APCA Lc readouts. `.numericText(countsDown:)` is iOS 16. Use `.interpolate` for the "Aa" color change [33].
- `matchedGeometryEffect` (iOS 14) links frames between views being inserted/removed. Exactly one source per id, otherwise "results are undefined" [34]. Good for the **selected chip's background pill** sliding between chips:

```swift
@Namespace private var chipNS
// in each chip:
.background { if isSelected { Capsule().fill(.tint).matchedGeometryEffect(id: "sel", in: chipNS) } }
```

### 4.7 Other useful iOS 17 animation tools

- `.animation(_:body:)` scopes an animation to specific modifiers [66].
- `.sensoryFeedback(.selection, trigger: model.theme)` gives haptics on chip change [64].
- `@Entry` creates custom environment keys and back-deploys (iOS 13) [63].

---

## 5. Image display

### 5.1 Displaying

```swift
struct PhotoImage: View {
    let photo: Photo
    var body: some View {
        Color.clear                                    // takes the proposed size exactly
            .overlay {
                Image(decorative: photo.cgImage, scale: 1)  // or Image(photo.assetName)
                    .resizable()                       // required before any sizing [38]
                    .scaledToFill()                    // fills, overflows the frame [39]
            }
            .clipped()                                 // visual clip only [40]
            .contentShape(Rectangle())                 // hit-test clip [41][42]
            .accessibilityLabel(photo.altText)
    }
}
```

- `resizable()` must come before `scaledToFill()` / `aspectRatio` [38].
- `scaledToFill` makes the image larger than its frame. **`clipped()` doesn't affect hit testing** [41], so the invisible overflow can steal taps meant for the specimen pane or the mixer button. Add `.contentShape(Rectangle())` as a parent of the sizing frame. Ole Begemann notes `.contentShape` and `.clipped()` can be swapped, as long as `contentShape` sits outside the frame that sets the size [41].
- The `Color.clear.overlay { image }` pattern stops the image's ideal size from pushing the layout. It's widely used (**unverified** as Apple guidance). An alternative is `.frame(maxWidth: .infinity, maxHeight: .infinity)` before `.clipped()`.

### 5.2 Loading 12 large bundled JPEGs efficiently

- `UIImage(named:)` / `Image("name")` cache in the system image cache [48]. For single-use large images, Apple suggests `UIImage(contentsOfFile:)`, which loads data marked purgeable [48][49].
- Decoded bitmap memory scales with the *source* pixel dimensions, not the view size (WWDC18 "Image and Graphics Best Practices" [51]; I found this via search summaries and did not fetch the transcript, so **partly unverified**). A 4000×6000 Unsplash JPEG is ~96 MB decoded at 4 bytes/pixel (arithmetic).
- **Downsample with ImageIO** to roughly screen pixel size [43]–[47]:

```swift
nonisolated enum ImageLoader {
    /// maxPixel ≈ max(screen.width, screen.height) * displayScale
    static func downsampled(url: URL, maxPixel: CGFloat) -> CGImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOpts) else { return nil }
        let opts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,   // else may use embedded tiny thumb [45]
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,        // always set; default is full size [45][46]
            kCGImageSourceCreateThumbnailWithTransform: true,     // respect EXIF orientation [47]
            kCGImageSourceShouldCacheImmediately: true            // decode now, not at first render [44]
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts)
    }
}
```

- `kCGImageSourceShouldCacheImmediately` default is false, which means decoding happens at render time on the main thread. Setting it true decodes at creation [44]. Do this off the main actor (`@concurrent` / `Task.detached`) and preload the *next* photo so a tap shows a ready image.
- With `kCGImageSourceCreateThumbnailFromImageAlways` but no max pixel size, ImageIO "creates the thumbnail using the image's full size, which in most cases is not desirable" [45].
- **Asset catalog caveat:** files in `Assets.xcassets` compile into `Assets.car` and have no file URL, so you can't use `CGImageSourceCreateWithURL` on them (**unverified**; general knowledge). Options:
  1. Put the JPEGs in a `Photos/` folder reference and use `Bundle.main.url(forResource:withExtension:)` + ImageIO (recommended).
  2. Keep them in the asset catalog but pre-size them to about 1290×2796 (iPhone Pro Max portrait pixels; **unverified** dimensions) so no runtime downsampling is needed.
  3. `UIImage.preparingThumbnail(of:)` (iOS 15) on an already-loaded `UIImage` avoids keeping the full-size decode around for display [50], but it still needs the source loaded.
- Simplest good approach for 12 photos: **pre-resize at build time to about 1500 px on the long edge, ship as HEIC/JPEG in the bundle, then ImageIO-downsample to the exact screen size.**

Palette derivation (fg/bg from the photo) should run on a much smaller thumbnail (for example 64 px) produced the same way.

---

## 6. Gestures

- **`Button` vs `onTapGesture`.** Apple: "If you create a control that's functionally equivalent to a Button, use ButtonStyle to create a customized button instead" [52]. Buttons get accessibility traits, keyboard and pointer support for free [53]. For "tap photo to advance", either works. Recommended:

```swift
Button { model.advance() } label: { PhotoPane() }
    .buttonStyle(.plain)                     // no highlight dimming on the photo (verify visually)
    .accessibilityLabel("Next photo")
    .accessibilityHint("Shows photo \(model.photoIndex + 2) of 12")
```

- **Avoiding double-advance (the web bug):**
  1. Attach exactly **one** advance handler. Don't put `onTapGesture` on both the photo and an ancestor. Don't combine `Button` with `onTapGesture`. Don't use `simultaneousGesture` for taps; it explicitly processes both gestures [simultaneousGesture docs, iOS 13]. The likely web cause (pointerdown + click both firing) has no direct SwiftUI analogue, but stacked handlers do recreate it (**unverified** that nested `onTapGesture`s fire only the innermost one; test).
  2. Make `advance()` idempotent per gesture. Optionally gate it with `isRevealing`, cleared in the `withAnimation` completion [27], so a second tap within 0.6 s is ignored or queued. Decide whether fast taps should skip ahead or be ignored (open question).
  3. Use `.contentShape(Rectangle())` so taps don't land on overflowing image pixels from the other pane [41].
- **Tap vs drag conflicts:** if a swipe-to-change-photo `DragGesture` is added later, attach it with `.gesture(...)` on the same view. A `Button` plus a drag on an ancestor can delay or cancel the button highlight. Use `DragGesture(minimumDistance: 10)` so small finger jitter still counts as a tap (**unverified** thresholds). Sliders in the drawer take their own drags, and the drawer sits outside the photo's hit area in layout A, so there's no conflict.
- When the drawer is open, decide whether a tap on the (shrunken) canvas advances or closes the drawer. Open question; check the web behavior.

---

## 7. Pasteboard, scenePhase, persistence

### 7.1 Pasteboard

```swift
UIPasteboard.general.string = model.shareURL.absoluteString   // "Copy link" [54][55]
UIPasteboard.general.string = model.markdownSnippet            // "Copy Markdown"
```

- Writing doesn't trigger the paste-permission banner. iOS notifies only when an app *reads* cross-app pasteboard content without user intent [54].
- Give feedback with `.sensoryFeedback(.success, trigger: copyCount)` [64] and a transient "Copied" label (`contentTransition(.opacity)`).
- If you set both a URL and a plain string, use `UIPasteboard.general.setItems` / `items` so the rich and plain representations are one item (**unverified** that this matters for the paste targets). `ShareLink` (iOS 16) is the native alternative if a share sheet is wanted later [68].

### 7.2 `scenePhase`

Read it with `@Environment(\.scenePhase)`. At the `App` level it's an aggregate of all scenes. "When an app enters the background phase, expect the app to terminate soon after" [56], so save there (snippet in §1.2). Use the iOS 17 `onChange(of:initial:_:)` forms [58].

### 7.3 `@AppStorage`

- `@AppStorage` (iOS 14) reflects a `UserDefaults` value and invalidates the view when it changes [57]. It supports `Bool/Int/Double/String/URL/Data` and `RawRepresentable` values.
- **Pitfall:** `@AppStorage` is a SwiftUI dynamic property meant for views. Inside an `@Observable` class, the macro rewrites stored properties, so property wrappers like `@AppStorage` don't compose. They must be `@ObservationIgnored` and then aren't tracked (**unverified** in Apple docs; it's a well-known community issue and consistent with how [1] describes the macro).
- **Recommendation:** keep persistence inside `AppModel`. Load from `UserDefaults` in `init`, save in `persist()` on background (or in `didSet` for the few values). Use `@AppStorage` only for view-local preferences, if any.

```swift
extension AppModel {
    private enum Key { static let index = "photoIndex", hue = "hueShift", light = "lightness", theme = "theme" }
    func persist() {
        defaults.set(photoIndex, forKey: Key.index)
        defaults.set(hueShift, forKey: Key.hue)
        defaults.set(lightness, forKey: Key.light)
        defaults.set(theme.rawValue, forKey: Key.theme)
    }
    func restore() {
        photoIndex = min(max(defaults.integer(forKey: Key.index), 0), Photo.all.count - 1)
        hueShift = defaults.double(forKey: Key.hue)
        // …
    }
}
```

Don't persist `isDrawerOpen` unless the web does. Cold launches usually start with it closed (design call).

---

## 8. Project structure, previews, tests

### 8.1 Layout for a tiny app

```
ColorShift/
  App/
    ColorShiftApp.swift          // @main, owns AppModel, scenePhase → persist
  Model/
    AppModel.swift               // @Observable, intents (advance, toggleDrawer, setTheme…)
    Photo.swift                  // static catalog of 12 photos (name, credit, alt text, cached palette)
    Theme.swift
  Color/                         // pure, `nonisolated`, unit-tested
    RGB.swift  OKLCH.swift  ContrastMath.swift (WCAG + APCA)  ColorPair.swift
  Views/
    RootView.swift  CanvasView.swift  PhotoPane.swift  SpecimenPane.swift
    ControlsDrawer.swift  ThemeChip.swift  WaveLabel.swift  ContrastReadout.swift
  Support/
    ImageLoader.swift  Animation+App.swift  PhotoReveal.swift
  Resources/
    Photos/ (12 JPEG/HEIC, folder reference)   Assets.xcassets (AppIcon, accent)
ColorShiftTests/
  ContrastMathTests.swift  ColorPairTests.swift
```

Alternatively put `Color/` in a local Swift package (`ColorCore`) with default `nonisolated` isolation. That makes the isolation boundary explicit and tests fast [5][8].

### 8.2 Previews

```swift
#Preview("Drawer open") {
    @Previewable @State var model = AppModel.preview(drawerOpen: true)   // iOS 17 [59]
    RootView().environment(model)
}
```

`@Previewable` lets you use dynamic properties inline in `#Preview` [59]. Xcode 27 adds `#Preview(arguments:)` grids [9]. That would suit previewing all 12 photos, but its minimum deployment requirements are **unverified**. Preview bodies run on the main actor in Xcode 27 [9].

### 8.3 Swift Testing for the pure color functions

Swift Testing ships with Xcode and supports parameterized tests, tags and parallel execution [60]. `@Test` declares a test and `#expect` checks a condition [61][62].

```swift
import Testing
@testable import ColorShift

struct ContrastMathTests {
    @Test("WCAG: black on white is 21:1")
    func blackOnWhite() {
        #expect(abs(ContrastMath.wcagRatio(.black, .white) - 21) < 0.01)
    }

    @Test("APCA Lc reference pairs", arguments: [
        (RGB(hex: 0x888888), RGB(hex: 0xFFFFFF), 63.056),   // verified vectors: see color-apca-image-sampling.md
        (RGB(hex: 0xFFFFFF), RGB(hex: 0x888888), -68.541),
        (RGB(hex: 0x000000), RGB(hex: 0xAAAAAA), 58.146),
        (RGB(hex: 0xAAAAAA), RGB(hex: 0x000000), -56.241),
        (RGB(hex: 0x000000), RGB(hex: 0xFFFFFF), 106.041),
        (RGB(hex: 0xFFFFFF), RGB(hex: 0x000000), -107.885),
    ])
    func apca(text: RGB, bg: RGB, expected: Double) {
        #expect(abs(ContrastMath.apcaLc(text: text, background: bg) - expected) < 0.001)
    }
}
```

If the color types stay MainActor-isolated (app-target default), annotate the suite `@MainActor` or the tests won't compile synchronously (see §1.4). The APCA expected values above are the six vectors reproduced exactly by the Swift and Python ports in `color-apca-image-sampling.md` (0.0.98G-4g).

---

## Availability

| API | Minimum iOS | Ref |
|---|---|---|
| `@Observable`, Observation framework | 17 | [1][3] |
| `@Bindable` | 17 | [4] |
| `@State` holding an `@Observable` ref, `.environment(obj)`, `@Environment(T.self)` | 17 | [1] |
| `Observations` async sequence | **26** | [11] |
| Default actor isolation setting / `nonisolated(nonsending)` / `@concurrent` | Swift 6.2 compiler feature (Xcode 26+), not an OS gate | [5][6] |
| `@Entry` macro | 13 (needs Xcode 16+) | [63] |
| `@Animatable` macro | docs list 13 (needs Xcode 26+ SDK) | [36] |
| `@Previewable` | 17 | [59] |
| `#Preview(arguments:)` | Xcode 27; OS minimum **unverified** | [9] |
| `GeometryReader` | 13 | [17] |
| `safeAreaInset(edge:…)` | 15 | [12] |
| `Layout` protocol, `ViewThatFits` | 16 | [15][16] |
| `onGeometryChange(for:of:action:)` | 16 (back-deployed) | [14] |
| `containerRelativeFrame`, `visualEffect`, `safeAreaPadding`, `geometryGroup` | 17 | [13][65][67][35] |
| `.sheet` + `presentationDetents` | 16 | [18] |
| `presentationBackgroundInteraction`, `presentationBackground` | 16.4 | [19][20] |
| `.spring(response:dampingFraction:)`, `.interpolatingSpring(mass:…)` | 13 | [23][24] |
| `Spring` struct, `.spring(_ Spring)`, `.interpolatingSpring(_ Spring)` | 17 | [21][25] |
| `withAnimation(_:completionCriteria:_:completion:)` | 17 | [27] |
| `PhaseAnimator` / `phaseAnimator`, `KeyframeAnimator` / `keyframeAnimator` | 17 | [29][30] |
| `Transition` protocol, `.blurReplace` | 17 | [31][32] |
| `contentTransition(_:)`, `.numericText(countsDown:)` | 16 | [33] |
| `.numericText(value:)` | 17 | — (doc JSON checked) |
| `matchedGeometryEffect` | 14 | [34] |
| `animation(_:body:)`, `sensoryFeedback` | 17 | [66][64] |
| `onChange(of:initial:_:)` | 17 | [58] |
| `ScenePhase`, `@AppStorage` | 14 | [56][57] |
| `onTapGesture(count:perform:)`, `contentShape`, `clipped`, `simultaneousGesture` | 13 | [52][42][40] |
| `ShareLink` | 16 | [68] |
| `UIPasteboard.general.string` | 3 | [54][55] |
| `CGImageSourceCreateThumbnailAtIndex` | 4 | [43] |
| `UIImage.preparingThumbnail(of:)` | 15 | [50] |
| Swift Testing (`@Test`, `#expect`) | Xcode 16+ toolchain; runs on iOS 17 targets | [60]–[62] |

Everything recommended in the TL;DR works with an **iOS 17** deployment target. The only iOS 26-gated item discussed (`Observations`) isn't needed.

---

## Open questions / uncertain

1. **Push semantics:** does the web canvas *shrink* (reflow) or *translate up* at a fixed size when the drawer opens? This decides between VStack reflow and fixed height + offset (§2.1).
2. **Settle time:** the brief says ~650 ms, but SwiftUI's `Spring.settlingDuration` reports 0.88 s and displacement is within 0.1% by 0.56 s. Where does 650 ms come from (a web library's rest threshold)? This doesn't affect parity of the curve itself.
3. **Chip "wave":** per-letter bounce, gradient shimmer, or ripple? The implementation differs (§4.4).
4. **Rapid taps during reveal:** skip ahead immediately (interrupting the 0.6 s reveal) or ignore? And does tapping the canvas while the drawer is open advance or close the drawer?
5. **safeAreaInset + ignoresSafeArea interaction** (§2.1 B) is inferred, not verified on device.
6. **Removal side of the photo transition:** z-ordering of outgoing and incoming photos with `.id` swaps needs on-device testing (§4.5).
7. **Asset catalog vs bundle files** for ImageIO downsampling (no file URL for catalog images) is general knowledge, not confirmed from a fetched Apple page.
8. **Blur cost** of an 8 pt blur on a full-screen image for 0.6 s on the oldest iOS 17 device is unmeasured.
9. **iOS 26 Liquid Glass** automatic restyling of sheets and controls (and any iOS 27 SwiftUI additions from WWDC26) wasn't surveyed here. It may affect the mixer button and chips if standard button styles are used.
10. **`@Animatable` macro on an iOS 17 target:** docs list iOS 13, but test it with the `Layout` conformance. Hand-written `animatableData` is the fallback.
11. ~~APCA reference values~~ resolved: replaced with verified vectors from `color-apca-image-sampling.md`.

---

## Sources

1. Apple, "Migrating from the Observable Object protocol to the Observable macro": https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
2. Apple, "Managing model data in your app": https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
3. Apple, `Observable()` macro: https://developer.apple.com/documentation/observation/observable()
4. Apple, `Bindable`: https://developer.apple.com/documentation/swiftui/bindable
5. Swift Evolution SE-0466, "Control default actor isolation inference" (Implemented, Swift 6.2): https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md
6. Swift Evolution SE-0461, "Run nonisolated async functions on the caller's actor by default" (Implemented, Swift 6.2): https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
7. Donny Wals, "Setting default actor isolation in Xcode 26": https://www.donnywals.com/setting-default-actor-isolation-in-xcode-26/
8. Fatbobman, "Default Actor Isolation: New Problems from Good Intentions": https://fatbobman.com/en/posts/default-actor-isolation/
9. Apple, Xcode 27 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
10. Apple, Xcode 26 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes
11. Apple, `Observations`: https://developer.apple.com/documentation/observation/observations
12. Apple, `safeAreaInset(edge:alignment:spacing:content:)`: https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)
13. Apple, `containerRelativeFrame(_:alignment:)`: https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:)
14. Apple, `onGeometryChange(for:of:action:)`: https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)
15. Apple, `ViewThatFits`: https://developer.apple.com/documentation/swiftui/viewthatfits
16. Apple, `Layout`: https://developer.apple.com/documentation/swiftui/layout
17. Apple, `GeometryReader`: https://developer.apple.com/documentation/swiftui/geometryreader
18. Apple, `presentationDetents(_:)`: https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:)
19. Apple, `presentationBackgroundInteraction(_:)`: https://developer.apple.com/documentation/swiftui/view/presentationbackgroundinteraction(_:)
20. Apple, `presentationBackground(_:)`: https://developer.apple.com/documentation/swiftui/view/presentationbackground(_:)
21. Apple, `Spring`: https://developer.apple.com/documentation/swiftui/spring
22. Apple, `Spring.settlingDuration`: https://developer.apple.com/documentation/swiftui/spring/settlingduration
23. Apple, `spring(response:dampingFraction:blendDuration:)`: https://developer.apple.com/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:)
24. Apple, `interpolatingSpring(mass:stiffness:damping:initialVelocity:)`: https://developer.apple.com/documentation/swiftui/animation/interpolatingspring(mass:stiffness:damping:initialvelocity:)
25. Apple, `spring(_:blendDuration:)`: https://developer.apple.com/documentation/swiftui/animation/spring(_:blendduration:)
26. WWDC23 "Animate with springs" (10158): https://developer.apple.com/videos/play/wwdc2023/10158/
27. Apple, `withAnimation(_:completionCriteria:_:completion:)`: https://developer.apple.com/documentation/swiftui/withanimation(_:completioncriteria:_:completion:)
28. WWDC23 "Wind your way through advanced animations in SwiftUI" (10157): https://developer.apple.com/videos/play/wwdc2023/10157/
29. Apple, `phaseAnimator(_:trigger:content:animation:)`: https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:trigger:content:animation:)
30. Apple, `keyframeAnimator(initialValue:trigger:content:keyframes:)`: https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:trigger:content:keyframes:)
31. Apple, `Transition`: https://developer.apple.com/documentation/swiftui/transition
32. Apple, `Transition.blurReplace`: https://developer.apple.com/documentation/swiftui/transition/blurreplace
33. Apple, `contentTransition(_:)`: https://developer.apple.com/documentation/swiftui/view/contenttransition(_:)
34. Apple, `matchedGeometryEffect(id:in:properties:anchor:isSource:)`: https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:)
35. Apple, `geometryGroup()`: https://developer.apple.com/documentation/swiftui/view/geometrygroup()
36. Apple, `Animatable()` macro: https://developer.apple.com/documentation/swiftui/animatable()
37. Apple, `accessibilityReduceMotion`: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion
38. Apple, `Image.resizable(capInsets:resizingMode:)`: https://developer.apple.com/documentation/swiftui/image/resizable(capinsets:resizingmode:)
39. Apple, `scaledToFill()`: https://developer.apple.com/documentation/swiftui/view/scaledtofill()
40. Apple, `clipped(antialiased:)`: https://developer.apple.com/documentation/swiftui/view/clipped(antialiased:)
41. Ole Begemann, "clipped() doesn't affect hit testing": https://oleb.net/2022/clipped-hit-testing/
42. Apple, `contentShape(_:eoFill:)`: https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:)
43. Apple, `CGImageSourceCreateThumbnailAtIndex`: https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex(_:_:_:)
44. Apple, `kCGImageSourceShouldCacheImmediately`: https://developer.apple.com/documentation/imageio/kcgimagesourceshouldcacheimmediately
45. Apple, `kCGImageSourceCreateThumbnailFromImageAlways`: https://developer.apple.com/documentation/imageio/kcgimagesourcecreatethumbnailfromimagealways
46. Apple, `kCGImageSourceThumbnailMaxPixelSize`: https://developer.apple.com/documentation/imageio/kcgimagesourcethumbnailmaxpixelsize
47. Apple, `kCGImageSourceCreateThumbnailWithTransform`: https://developer.apple.com/documentation/imageio/kcgimagesourcecreatethumbnailwithtransform
48. Apple, `UIImage.init(named:)`: https://developer.apple.com/documentation/uikit/uiimage/init(named:)
49. Apple, `UIImage.init(contentsOfFile:)`: https://developer.apple.com/documentation/uikit/uiimage/init(contentsoffile:)
50. Apple, `UIImage.preparingThumbnail(of:)`: https://developer.apple.com/documentation/uikit/uiimage/preparingthumbnail(of:)
51. WWDC18 "Image and Graphics Best Practices" (219), via search-result summaries only (transcript not fetched): https://developer.apple.com/videos/play/wwdc2018/219/ and https://wwdcnotes.com/documentation/wwdc18-219-image-and-graphics-best-practices/
52. Apple, `onTapGesture(count:perform:)`: https://developer.apple.com/documentation/swiftui/view/ontapgesture(count:perform:)
53. Apple, `Button`: https://developer.apple.com/documentation/swiftui/button
54. Apple, `UIPasteboard`: https://developer.apple.com/documentation/uikit/uipasteboard
55. Apple, `UIPasteboard.string`: https://developer.apple.com/documentation/uikit/uipasteboard/string
56. Apple, `ScenePhase`: https://developer.apple.com/documentation/swiftui/scenephase
57. Apple, `AppStorage`: https://developer.apple.com/documentation/swiftui/appstorage
58. Apple, `onChange(of:initial:_:)`: https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)
59. Apple, `Previewable()`: https://developer.apple.com/documentation/swiftui/previewable()
60. Apple, Swift Testing: https://developer.apple.com/documentation/testing
61. Apple, `Test(_:_:)`: https://developer.apple.com/documentation/testing/test(_:_:)
62. Apple, `expect(_:_:sourceLocation:)`: https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)
63. Apple, `Entry()` macro: https://developer.apple.com/documentation/swiftui/entry()
64. Apple, `sensoryFeedback(_:trigger:)`: https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)
65. Apple, `visualEffect(_:)`: https://developer.apple.com/documentation/swiftui/view/visualeffect(_:)
66. Apple, `animation(_:body:)`: https://developer.apple.com/documentation/swiftui/view/animation(_:body:)
67. Apple, `safeAreaPadding(_:_:)`: https://developer.apple.com/documentation/swiftui/view/safeareapadding(_:_:)
68. Apple, `ShareLink`: https://developer.apple.com/documentation/swiftui/sharelink

Also checked but not given a number: Apple `simultaneousGesture(_:including:)` (https://developer.apple.com/documentation/swiftui/view/simultaneousgesture(_:including:)), `ContentTransition.numericText(value:)` (https://developer.apple.com/documentation/swiftui/contenttransition/numerictext(value:)) and `KeyframeTrack.init(content:)` (https://developer.apple.com/documentation/swiftui/keyframetrack/init(content:)), all iOS availability as stated above. The spring numbers in §4.2 come from a local Swift script using SwiftUI's `Spring` (Swift 6.4.2, macOS 26), not from a URL.
