# Sharing, Pasteboard, and Deep Links: Color Shift for iOS

Last checked: 2026-11-24

Scope: iPhone, iOS 17+, SwiftUI. This covers how the web app's "Copy link" (`?fg=&bg=&photo=`) and "Markdown" features map to iOS, and how links can open the app.

---

## TL;DR

- **Sharing:** Use `ShareLink` (iOS 16+) [1]. For the link, share a `URL` and pass a `SharePreview`, so the sheet shows a preview right away and doesn't fetch metadata over the network [1][2]. For an image, wrap an `ImageRenderer` PNG in a `Transferable` type. Add a `FileRepresentation` if Messages, Mail, or AirDrop don't show up [1][3][4]. Keep `UIActivityViewController` only as a fallback [5].
- **Pasteboard:** Copying never triggers the paste prompt. `UIPasteboard.general.string = ...` / `.url = ...` is silent. The iOS 14+ notice and paste prompt only apply when the app *reads* another app's content without user intent [6]. If the app ever needs paste (for example, a hex field), use `PasteButton` [7]. Show a short "Copied" state, as the web app does (1.6 s).
- **Custom scheme `colorshift://`:** Easy to add (`CFBundleURLTypes` plus `.onOpenURL`) [8][9]. However, Apple "strongly recommend[s]" universal links instead. Schemes aren't unique: "If multiple apps register the same scheme, the app the system targets is undefined" [8]. A `colorshift://` link also does nothing for recipients without the app, so **don't put it in "Copy link"**.
- **Universal links need a domain you control** that serves `https://<domain>/.well-known/apple-app-site-association` with a valid certificate and no redirects [10]. A `*.figma.site` host is owned by Figma, so it can't serve this file. Figma staff also say published Make sites have "no access to a public folder or custom server routes" (Jun 2026) [15]. Even a custom domain attached to Figma Make probably can't serve the AASA without an edge proxy such as a Cloudflare Worker (**not verified for AASA specifically**).
- **Recommendation for v1:** "Copy link" on iOS should produce the **same HTTPS web URL** the web app produces: `<web-origin>/?fg=RRGGBB&bg=RRGGBB&photo=<index>`. Use 6 hex digits with no `#`, and use `photo` as the **0-based index into the photo array** (this is what `App.tsx` does today). Recipients without the app can then open it in the browser. Parse the same format in `.onOpenURL` so a later universal-link domain needs no format change. Universal links can come later, from a small domain you own (Vercel/GitHub Pages/Cloudflare) that serves the AASA and forwards to the Figma Make URL.

---

## 0. What the web app actually does (from `App.tsx`)

Verified by reading the web repo's `src/App.tsx`:

```ts
// copyLink
url.searchParams.set("fg", foreground.slice(1));   // "#1A2B3C" -> "1A2B3C"
url.searchParams.set("bg", background.slice(1));
url.searchParams.set("photo", String(photos.indexOf(photo)));  // index, not an id
await navigator.clipboard.writeText(url.toString());
setCopied(true); setTimeout(() => setCopied(false), 1600);

// on load
fg?.match(/^[\da-f]{6}$/i)  -> setForeground(`#${fg.toUpperCase()}`)
Number.isInteger(index) && index >= 0 && index < photos.length -> setPhotoIndex(index)
```

Implications for iOS:
- `photo` is an **array index**, so the iOS photo list must use the same order as the web `photos` array. Otherwise shared links will point to different photos. Consider adding a stable id later, keeping `photo=<index>` for compatibility.
- Hex is exactly 6 digits, case-insensitive, with no `#`. iOS should emit uppercase 6-digit hex without `#` and accept the same input pattern.
- The web "Markdown" button **downloads a `.md` file** (`color-shift-<fg>-<bg>.md`) rather than copying it. The task brief says "Copy Markdown". On iOS, either copy the text to the pasteboard or share it as a `.md` file through `ShareLink`. See Section 1.4.
- Markdown template: `# Color Shift`, a photo image line, Unsplash credit, Foreground/Background in backticks, and the WCAG ratio to 2 decimals.

---

## 1. Sharing with ShareLink, Transferable, and ImageRenderer

### 1.1 ShareLink basics

`ShareLink` is "a view that controls a sharing presentation". It is available on iOS 16.0+ [1], so it is fine for an iOS 17 target. It can share anything `Transferable`, and `URL` and `String` already conform [1].

Key doc points [1]:
- "A preview isn't required when sharing URLs or non-attributed strings."
- For URLs, the automatic preview "first shows a placeholder link icon … while fetching the link's metadata over the network". "If you provide a preview instead, the preview appears immediately without fetching data over the network."
- `subject:` and `message:` pre-fill fields for activities that support them (Mail, for example).
- "Some applications offer their sharing service for files, but not for a wide range of different data types, for example, Mail.app, Notes.app, Messages.app or AirDrop. If you don't see a particular sharing service … try adding a `FileRepresentation`."

```swift
import SwiftUI

struct ShareControls: View {
    let pair: ColorPair          // fg, bg, photoIndex
    let swatch: Image            // small rendered preview

    var body: some View {
        ShareLink(
            item: pair.webURL,                                   // https URL, see Section 6
            subject: Text("Color Shift palette"),
            message: Text("\(pair.fgHex) on \(pair.bgHex)"),
            preview: SharePreview("Color Shift: #\(pair.fgHex) / #\(pair.bgHex)",
                                  image: swatch)
        ) {
            Label("Share link", systemImage: "square.and.arrow.up")
        }
    }
}
```

`SharePreview` takes a title, an `image` (usually a full-size representation), and an `icon` (a thumbnail of the source). "The system may reuse a single preview representation for multiple previews, and show different images in each context" [2].

> Note: when a recipient's Messages app builds the rich link bubble, it fetches the web page's metadata. The `SharePreview` only affects the share sheet on the sender's device [1][2]. The Figma Make SPA may serve generic `og:` tags, so the bubble may not show the colors (**unverified**, and outside iOS control).

### 1.2 Sharing a rendered palette image (ImageRenderer → PNG)

`ImageRenderer` (iOS 16+) "creates images from SwiftUI views" and exposes `cgImage`/`uiImage` [3]. Caveat [3]: output "only includes views that SwiftUI rasterizes directly … text, images, shapes". Views composited by Core Animation layers, "web views, media players, and most types of UIKit … views", render as a placeholder. Build a dedicated, plain SwiftUI "palette card" view for export rather than rendering the live screen. Set `scale` to the display scale or a fixed value such as 3 for crisp output.

```swift
import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

struct PaletteImage: Transferable {
    let pngData: Data
    let filename: String   // e.g. "color-shift-1A2B3C-F4F1EA.png"

    static var transferRepresentation: some TransferRepresentation {
        // Prefer a file: makes Messages / Mail / AirDrop / Save Image appear reliably [1]
        FileRepresentation(exportedContentType: .png) { item in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(item.filename)
            try item.pngData.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        // Raw data fallback for receivers that accept in-memory PNG
        DataRepresentation(exportedContentType: .png) { $0.pngData }
    }
}

@MainActor
func renderPalette(_ pair: ColorPair, photo: UIImage) -> PaletteImage? {
    let renderer = ImageRenderer(content: PaletteCard(pair: pair, photo: photo)
                                    .frame(width: 1080 / 3, height: 1350 / 3))
    renderer.scale = 3
    guard let data = renderer.uiImage?.pngData() else { return nil }
    return PaletteImage(pngData: data,
                        filename: "color-shift-\(pair.fgHex)-\(pair.bgHex).png")
}

// Usage
if let img = renderPalette(pair, photo: photo) {
    ShareLink(item: img,
              preview: SharePreview("Color Shift palette", image: Image(uiImage: photo)))
}
```

The `Transferable` docs [4] say the order of representations matters: "place the representation that most accurately represents your type first, followed by … more compatible but less preferable representations". `ProxyRepresentation` can also add a text/URL fallback.

Caveats:
- `ImageRenderer` is `@MainActor`. Render when the user taps or when state changes, not inside `body` on every frame. Cache the result.
- **Photo licensing:** photos come from Unsplash (see the Markdown template). Including a photo in a shared image is normally allowed under the Unsplash License, but keep the photographer credit in the image or message (**verify against current Unsplash terms**).

### 1.3 Sharing multiple things at once

`ShareLink(items:)` takes a collection with one preview per item [2]. Mixing types in one share (URL + image) is easier with a single custom `Transferable` that exports both a PNG and a `ProxyRepresentation { $0.url }`. Receivers then pick the representation they support. Alternatively, use the `UIActivityViewController` fallback with `activityItems: [url, image]`.

### 1.4 Markdown

Two options that match the web app:
- **Copy:** `UIPasteboard.general.string = markdown` (Section 2). Most useful on iPhone.
- **Share as file:** a `Transferable` with `FileRepresentation(exportedContentType: UTType(filenameExtension: "md") ?? .plainText)` named `color-shift-<fg>-<bg>.md`, matching the web download name. `UTType.markdown` (`net.daringfireball.markdown`) has existed since iOS 14 per my knowledge (**unverified** in this pass).

### 1.5 UIActivityViewController fallback

`UIActivityViewController` is "a view controller that you use to offer standard services from your app", including copy, Mail, Messages, and custom activities [5]. Use it only if you need `excludedActivityTypes`, a `completionWithItemsHandler`, or `UIActivityItemSource` per-activity content, none of which `ShareLink` exposes. "On iPad, you must present" it in a popover [5]. This app is iPhone-only, but set `popoverPresentationController?.sourceView` anyway to be safe.

```swift
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
// .sheet(isPresented: $showShare) { ActivityView(items: [pair.webURL, pngImage]) }
```

---

## 2. Pasteboard

### 2.1 Writing (copy)

`UIPasteboard.general` is the system-wide pasteboard. It has convenience properties for strings, URLs, images, and colors, and it supports multiple representation types per item [6]. With iCloud, the general pasteboard syncs to nearby devices through Universal Clipboard. `setItems(_:options:)` with `.localOnly` / `.expirationDate` controls this [6].

```swift
// Simple: matches web navigator.clipboard.writeText(url)
UIPasteboard.general.string = pair.webURL.absoluteString

// Or: one item with both URL and plain-text representations, so apps that
// prefer a URL type (Notes, Messages) get a link and plain text fields get the string.
UIPasteboard.general.setItems([[
    UTType.url.identifier:       pair.webURL,
    UTType.utf8PlainText.identifier: pair.webURL.absoluteString
]])

// Markdown copy
UIPasteboard.general.string = pair.markdown
```

Apple's docs describe providing multiple representation types per item so "various contexts … can then make use of an appropriate representation type" [6].

### 2.2 The paste prompt applies to reading only

From the `UIPasteboard` docs [6]: "Starting in iOS 14, the system notifies the user when an app gets general pasteboard content that originates in a different app without user intent. The system determines user intent based on user interactions, such as tapping a system-provided control or pressing Command-V."

- **Writing never prompts.** The "Copy link" and "Copy Markdown" flows have no privacy UI.
- Since iOS 16 the notice became an "Allow Paste" consent alert for programmatic reads (**from memory; Apple's page above describes it only as "notifies"**).
- To check what's on the pasteboard without triggering anything, use `hasStrings`, `hasURLs`, `hasColors`, `numberOfItems`, `types`, and the pattern-detection methods [6].

### 2.3 PasteButton (only if the app needs paste)

`PasteButton` (iOS 16+) is "a system button that reads items from the pasteboard and delivers it to a closure". It counts as user intent, so it reads without the alert. It "automatically validates and invalidates based on changes to the pasteboard on iOS" [7].

```swift
PasteButton(payloadType: String.self) { strings in
    guard let s = strings.first, let hex = HexColor(s) else { return }
    pair.foreground = hex
}
.labelStyle(.iconOnly)
.buttonBorderShape(.capsule)
```

A useful feature: let a user paste a Color Shift link or a `#RRGGBB` value and apply it with the same parser as `.onOpenURL` (Section 3.3).

### 2.4 "Copied" confirmation

There's no system toast. Mirror the web behavior (a 1.6 s label swap) and add haptics and accessibility:

```swift
@State private var copied = false

Button {
    UIPasteboard.general.string = pair.webURL.absoluteString
    copied = true
    UIAccessibility.post(notification: .announcement, argument: "Link copied")
    Task { try? await Task.sleep(for: .seconds(1.6)); copied = false }
} label: {
    Label(copied ? "Copied" : "Copy link",
          systemImage: copied ? "checkmark" : "link")
        .contentTransition(.symbolEffect(.replace))
}
.sensoryFeedback(.success, trigger: copied)   // iOS 17+
```

`sensoryFeedback` and `.symbolEffect` content transitions are iOS 17 APIs (from memory, **not re-verified here**).

---

## 3. Custom URL scheme (`colorshift://`)

### 3.1 Apple's position

From "Defining a custom URL scheme for your app" [8]:
- "While custom URL schemes are an acceptable form of deep linking, universal links are strongly recommended."
- Warning: "URL schemes offer a potential attack vector into your app, so make sure to validate all URL parameters and discard any malformed URLs … limit the available actions to those that don't risk the user's data … make sure your test cases include improperly formatted URLs."
- Uniqueness: a reverse-DNS identifier "doesn't prevent other apps from registering the same scheme and handling the associated links." "If multiple apps register the same scheme, the app the system targets is undefined. There's no mechanism to change the app."

**Collision risk for `colorshift`:** it's a generic name, and another color app could claim it. Treat the scheme as convenience only (for example, Shortcuts or your own widget). Never rely on it for anything sensitive. A more distinctive scheme (for example `colorshift-<something>`) lowers but doesn't remove the risk [8].

### 3.2 Registering (Info.plist)

In Xcode go to Target › Info › URL Types (Identifier, URL Schemes, Role = Editor) [8]. The raw plist:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.example.colorshift</string>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>colorshift</string>
    </array>
  </dict>
</array>
```

Suggested format, which reuses the web query so one parser handles both:
`colorshift://open?fg=1A2B3C&bg=F4F1EA&photo=2`

### 3.3 Handling with `.onOpenURL`, parsing, and validation

`onOpenURL(perform:)` is available on iOS 14+. "SwiftUI passes a Universal Link to your app directly as a URL, which you receive using this modifier" [9]. One handler covers both the custom scheme and future universal links. Apple says to use `URLComponents` to parse [8][11].

```swift
@main
struct ColorShiftApp: App {
    @State private var model = PaletteModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .onOpenURL { url in
                    if let link = ColorShiftLink(url: url) { model.apply(link) }
                    // else: silently ignore malformed links (Apple guidance [8])
                }
        }
    }
}

struct ColorShiftLink: Equatable {
    var fg: String?        // "1A2B3C" (uppercase, no #)
    var bg: String?
    var photoIndex: Int?

    /// Accepts:
    ///   colorshift://open?fg=..&bg=..&photo=..
    ///   https://<allowed-host>/?fg=..&bg=..&photo=..   (universal link / pasted link)
    init?(url: URL, photoCount: Int = Photos.all.count) {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        switch c.scheme?.lowercased() {
        case "colorshift":
            break
        case "https":
            guard let host = c.host?.lowercased(),
                  ColorShiftLink.allowedHosts.contains(host) else { return nil }
        default:
            return nil
        }
        let items = c.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value  // first wins, matching web URLSearchParams.get()
        }
        fg = value("fg").flatMap(Self.normalizeHex)
        bg = value("bg").flatMap(Self.normalizeHex)
        if let p = value("photo"), let i = Int(p), (0..<photoCount).contains(i) { photoIndex = i }
        if fg == nil && bg == nil && photoIndex == nil { return nil }
    }

    /// Mirrors web regex /^[\da-f]{6}$/i ; also tolerates a leading "#" or "%23" if hand-typed.
    static func normalizeHex(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, s.allSatisfy(\.isHexDigit) else { return nil }
        return s.uppercased()
    }

    static let allowedHosts: Set<String> = [
        // "<your-make-subdomain>.figma.site", "colorshift.example.com"
    ]
}
```

The web uses `URLSearchParams.get`, which returns the **first** duplicate key, so the parser uses `items.first(where:)` to match.

Security checklist, following Apple's warnings [8][11]:
- Treat every URL as untrusted. Accept only `fg`, `bg`, and `photo`, ignore unknown keys, and enforce strict regex and range checks. `Character.isHexDigit` accepts only ASCII 0-9/a-f/A-F (**from memory**).
- Bound the input size, for example by ignoring URLs over ~2 KB.
- A link should only change on-screen state. It should never delete data, write files, or open network URLs from parameters. Never build a URL from `photo` (the photo is chosen from the bundled list by index).
- Should an incoming link overwrite the user's current unsaved pair? Applying it immediately is reasonable because the action is non-destructive, but consider an undo affordance.
- Unit-test malformed inputs: `fg=GGGGGG`, `fg=12345`, `fg=` (empty), `photo=-1`, `photo=99`, `photo=1.5`, percent-encoded junk, a missing query, and wrong hosts.

### 3.4 Limitations of a custom scheme for sharing

- Recipients without the app get nothing useful. In Messages or Mail a `colorshift://` string often isn't even tappable, and Safari shows an error (**typical behavior; not re-verified**).
- For these reasons it's unsuitable as the "Copy link" output. Use it only internally (widgets, App Intents/Shortcuts, testing).

---

## 4. Universal links

### 4.1 How they behave

- "Because universal links are standard HTTP or HTTPS links, one URL works for both your website and your app. If the person hasn't installed your app, the system opens the URL in their default web browser, allowing your website to handle it." [12]
- "When a user browses your website in Safari and taps a universal link in the same domain, the system opens that link in Safari … If the user taps a universal link in a different domain, the system opens the link in your app." [12]
- If your own app calls `openURL`/`UIApplication.open` on its own universal link, "the link won't open in your app" [12].
- Same warning as for schemes: validate all parameters and limit actions [11].
- In SwiftUI, universal links arrive through `.onOpenURL` as a plain `URL` [9], so the parser in Section 3.3 is reused.

### 4.2 The `apple-app-site-association` (AASA) file

From "Supporting associated domains" [10] and the `applinks` reference [13]:
- Name it `apple-app-site-association` with **no extension**.
- Location: `https://<fully qualified domain>/.well-known/apple-app-site-association`.
- "You must host the file using `https://` with a valid certificate and with no redirects."
- Each subdomain (`example.com`, `www.example.com`) needs its own entitlement entry and its own file.
- `appIDs` format: `<Application Identifier Prefix (Team ID)>.<Bundle Identifier>`.
- `components` is an array of dictionaries matching URL parts: `"/"` path, `"?"` query (dictionary of name → pattern), `"#"` fragment, plus `"exclude": true` and `"comment"`.

Pattern syntax (WWDC20 "What's new in universal links" [14]):
- `*` matches zero or more characters (greedy). `?` matches exactly one character, and `?*` matches at least one.
- `"exclude": true` must come **before** the broader pattern it carves out.
- `"caseSensitive": false` (iOS 13.5+) and `"percentEncoded": false` (iOS 14+).
- `defaults` (iOS 14+) sets default keys for all patterns.
- **Substitution variables** (iOS 14+): define `"substitutionVariables": { "name": [ ... ] }` under `applinks` and reference them as `$(name)`. Built-ins include `alpha`, `upper`, `lower`, `alnum`, `digit`, `xdigit`, `region`, and `lang`. Values can contain `?`/`*` but can't reference other variables.

AASA for Color Shift, assuming a domain such as `colorshift.example.com` that you control:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": [ "ABCDE12345.com.example.colorshift" ],
        "components": [
          {
            "#": "no_universal_links",
            "exclude": true,
            "comment": "Escape hatch: append #no_universal_links to force the browser"
          },
          {
            "/": "/",
            "?": { "fg": "$(xdigit)$(xdigit)$(xdigit)$(xdigit)$(xdigit)$(xdigit)" },
            "comment": "Palette links: /?fg=RRGGBB&bg=...&photo=..."
          },
          {
            "/": "/p/*",
            "comment": "Optional future path-style links"
          }
        ]
      }
    ]
  }
}
```

Unverified points: (a) whether `$(xdigit)` matches one hex character, so six are needed, rather than a whole run of them. The talk describes variables as lists of strings matched against, so a single char is likely. (b) whether `"?"` matching requires that query item to be present (Apple's example `"articleNumber": "????"` implies yes [10]). (c) case sensitivity of hex. The web emits uppercase, but add `"caseSensitive": false` to be safe. Test on a device. If in doubt, the simpler `{ "/": "/*" }` is fine for a tiny app.

### 4.3 Hosting requirements and the Apple CDN

- HTTPS, valid cert, no redirects, path `/.well-known/` [10].
- **Content-Type:** serve as `application/json`. Apple's current page [10] doesn't state it explicitly, but it is the long-standing requirement in older Apple docs and in hosting-platform guides (**treat as required; not re-verified on a current Apple page**).
- Size limit: 128 KB uncompressed was historically documented (**unverified in this pass**).
- **Apple CDN:** "Starting with macOS 11 and iOS 14, apps no longer send requests for `apple-app-site-association` files directly to your web server. Instead, they send these requests to an Apple-managed content delivery network (CDN)". "Apple's content delivery network requests the `apple-app-site-association` file for your domain within 24 hours. Devices check for updates approximately once per week after app installation." [10] The CDN is on the public internet, so the file must be reachable publicly [14]. You can inspect the CDN copy at `https://app-site-association.cdn-apple.com/a/v1/<domain>`. This is widely used, but the URL is **not found on Apple's current doc pages** I checked.
- **Developer mode:** entitlement `applinks:<domain>?mode=developer`. "Only devices in developer mode can access the domain … you can use any valid SSL certificate … only apps that you sign with a development profile can use developer mode, and users must opt-in on any device they use" [16]. On iOS, opt in under Settings › Developer › Associated Domains Development. This bypasses the CDN, and the file must be in `.well-known`, not at the root [14]. Other modes are `managed` (MDM) and `developer+managed` [16]. Remove the `?mode=` entry, or keep only the plain entry, for TestFlight and App Store builds, which can't use developer mode [14].

### 4.4 Associated Domains entitlement

Add the **Associated Domains** capability in Signing & Capabilities. This adds `com.apple.developer.associated-domains` to the app and the feature to the App ID [10]. Format: `<service>:<fully qualified domain>`, with no path, query, or trailing slash. `*.` wildcards are allowed except for `appclips` [10]. Services: `applinks`, `webcredentials`, `activitycontinuation`, `appclips` [16].

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:colorshift.example.com</string>
  <!-- dev only: -->
  <string>applinks:colorshift.example.com?mode=developer</string>
</array>
```

### 4.5 Can the Figma Make / figma.site host serve the AASA?

**Almost certainly no.**

1. **`<name>.figma.site` (default):** Figma owns `figma.site`. You can't place files at `https://<name>.figma.site/.well-known/`. Figma's universal-link association would have to list your Team ID, which isn't something a customer can configure. Apple: "Only you can store this file on your server, securing the association" [12]. This is inferred from how Figma hosting works and wasn't tested with a request.
2. **Static files on Make generally:** a June 2026 Figma forum thread reports that files in a Make project's `public/` folder (robots.txt, sitemap.xml, manifest.json) return 404 after publishing. A Figma staff member ("Figmate") replied: "This is a current platform limitation, not something a config will fix", citing "no access to a public folder or custom server routes like robots.txt/sitemap.xml" [15]. A separate feature request for "non-page requests" (static files and redirects) has no staff answer as of Apr 2026 [17]. Neither thread mentions `.well-known`, but the same limitation should apply. **Not directly verified for AASA.**
3. **Custom domain on Figma Sites/Make:** possible on paid plans (Professional allows 10, Org/Enterprise unlimited, Education reportedly unavailable). It works through TXT + CNAME (or A for apex), and Figma provisions SSL automatically [18][19]. It controls the *domain* but not the *file paths*, since the help page doesn't mention well-known or static files [18]. With your own DNS, though, you can put an **edge proxy** (Cloudflare Worker) in front that serves `/.well-known/apple-app-site-association` itself and passes everything else to Figma. Forum users report this pattern for robots.txt/sitemap [15][17]. Figma's help notes Cloudflare-proxied records must be "DNS only" for Figma's domain verification [18]. That may conflict with a Worker in front, so **test whether verification and SSL renewal survive proxying (unverified)**.

### 4.6 Realistic paths to universal links (later)

| Option | Effort | Notes |
|---|---|---|
| **A. Own small "link domain" + forwarder** (e.g. `cs.example.com` on Vercel / Cloudflare Pages / GitHub Pages) | Low | Serves the AASA. Its `/` page forwards the full query string to the Figma Make URL. App installed: iOS opens the app directly, with no network request to the page. Not installed: the browser loads the forwarder, which redirects to `https://<make>.figma.site/?fg=..&bg=..&photo=..`. Redirecting the **page** is fine; only the AASA must not redirect [10]. |
| **B. Custom domain on Figma Make + Cloudflare Worker for `/.well-known/*`** | Medium | Single canonical domain, but relies on proxying working alongside Figma's DNS-only requirement [18] (**unverified**). |
| **C. Move the web app off Make** (export code, host on Vercel/Netlify) | Medium | Full control of headers and files. A forum user describes exporting Make source and self-hosting [17]. |

Vercel `vercel.json` sketch for Option A. This is the standard config shape and wasn't validated in this pass:

```json
{
  "headers": [
    { "source": "/.well-known/apple-app-site-association",
      "headers": [{ "key": "Content-Type", "value": "application/json" }] }
  ],
  "redirects": [
    { "source": "/", "has": [{ "type": "query", "key": "fg" }],
      "destination": "https://<make-subdomain>.figma.site/", "permanent": false }
  ]
}
```

Check that the Vercel redirect preserves the incoming query string. Vercel normally passes the query through on redirects, but **verify**. A tiny `index.html` that runs `location.replace(MAKE + location.search)` is a robust alternative. On GitHub Pages, `.well-known` needs `include: [".well-known"]` in `_config.yml` or a `.nojekyll` file, and an extensionless file may be served as `application/octet-stream` (**unverified; prefer Vercel/Cloudflare Pages where headers are configurable**).

### 4.7 Fallback when the app is not installed

The system opens the URL in the default browser [12], so the web app gets `?fg&bg&photo` and restores the state. This is why the shared URL format must stay identical to the web's. Other notes:
- Universal links generally don't trigger when a URL is typed or pasted into Safari's address bar, or for same-domain navigation [12]. Some in-app browsers (third-party apps' web views) may not honor them (**common knowledge, unverified**).
- `#no_universal_links` exclusion (Apple's own example [10]) gives users and testers a way to force the web.

---

## 5. Smart App Banners and App Clips (web → app)

### 5.1 Smart App Banner

Add to the web page `<head>` [20]:

```html
<meta name="apple-itunes-app" content="app-id=1234567890, app-argument=https://<make>.figma.site/?fg=1A2B3C&bg=F4F1EA&photo=2">
```

- If the app is installed, tapping opens it. If not, the banner goes to the App Store, and after install, "tapping the banner opens the app while preserving the user's content" [20].
- `app-argument` must be a valid URL, and the app receives it as an open-URL [20]. In SwiftUI it should arrive via `.onOpenURL` (**inferred**; Apple's sample uses the old app-delegate method).
- Banners "don't appear in the iOS simulator" and can't be shown inside a frame [20]. They don't reappear after dismissal.
- **Figma Make fit:** this needs a `<head>` meta tag. Figma Make reportedly allows "Custom Code" head snippets [15]. A static `app-id` works, but a per-page dynamic `app-argument` would need JS updating the meta tag after load. Whether Safari honors a meta tag injected or changed by JS is **unverified**. Fallback: a static `app-argument` with no params.
- Requires the app to be live on the App Store (an App Store ID).

### 5.2 App Clips

An App Clip is "a lightweight version of your app" launched from Smart App Banners, App Clip cards in Safari, links shared in Messages, Maps, Siri Suggestions, and App Clip Codes [21][22]. It uses the `appclips` AASA service and Associated Domains [10], so **it has the same "domain you control" requirement**. It adds a second target and App Store Connect experience config. For Color Shift, where the website already gives the full experience, an App Clip is **not worth it in v1 or v2**. Mentioned for completeness.

---

## 6. Recommendation for Color Shift iOS

### v1 (ship now)

1. **"Copy link"** writes an **HTTPS URL to the canonical web app** with the exact web params:
   `https://<make-subdomain>.figma.site/?fg=1A2B3C&bg=F4F1EA&photo=2`
   - `fg`/`bg`: 6 uppercase hex digits, no `#`. `photo`: 0-based index into the **same ordered photo list** as web.
   - Store the base URL as one constant (`ColorShiftLink.webBase`) so a later move to your own domain is a one-line change. Old figma.site links keep working in browsers regardless.
   - Use `UIPasteboard.general.string` (or a URL + text item) with a "Copied" swap of about 1.6 s, `.sensoryFeedback(.success)`, and a VoiceOver announcement.
2. **Share button:** `ShareLink(item: webURL, subject:, message:, preview: SharePreview(..., image: swatch))`. Add an image share using `ImageRenderer` → PNG `Transferable` with a `FileRepresentation`.
3. **Markdown:** "Copy Markdown" uses `UIPasteboard.general.string = markdown`, with the same template as the web. Optionally also share it as a `.md` file.
4. **Inbound:** implement `.onOpenURL` with the strict `ColorShiftLink` parser now. It accepts `colorshift://open?...` (registered scheme, internal use and testing) **and** `https://<allowed hosts>/?...`, so universal links later need no code change. Optional: a `PasteButton` "Paste link" that runs the same parser, giving users without universal links a way to bring a web link into the app.
5. **Don't** emit `colorshift://` in any user-facing share or copy output.

### Later (when you want links to open the app)

1. Get a domain you control (for example `colorshift.app` or a subdomain of an existing domain).
2. Easiest path: host a tiny forwarder plus AASA on Vercel/Cloudflare Pages (Section 4.6, Option A). Switch `webBase` to it. Add `applinks:<domain>` to the entitlement, using `?mode=developer` while testing.
3. Optionally attach the same or another domain to Figma Make and add a Smart App Banner meta tag through Make's custom head code.
4. Test that: the app is installed and the link is tapped from Messages/Notes; the app isn't installed and the web restores state; a long-press offers "Open in Safari"; `#no_universal_links` works; and malformed params are ignored.

---

## Open questions / uncertain

1. **Exact canonical web URL:** is there a published `*.figma.site` URL or a custom domain already? `copyLink` uses `window.location.href`, so links currently carry whatever host or path the visitor is on. The iOS app needs one fixed base.
2. **AASA on Figma Make:** not tested directly. The conclusion rests on Figma staff saying there's no public folder or custom routes [15], plus ownership of `figma.site`. Figma could add well-known file support later (Webflow and Framer have it), so recheck Figma's help center before deciding.
3. **Cloudflare Worker in front of a Figma custom domain:** compatibility with Figma's "DNS only" requirement [18] is unknown.
4. **AASA `?` matching with `$(xdigit)`:** exact semantics and case sensitivity need on-device testing. Simpler patterns are fine.
5. **`application/json` content type and 128 KB limit:** not stated on the current Apple page [10], but long-standing guidance.
6. **Smart App Banner with a JS-injected or modified meta tag:** unverified.
7. **Photo index stability:** if the web `photos` array is reordered or extended in the middle, old links break on both platforms. Consider adding a stable `photo` slug while still accepting numeric indexes.
8. **Duplicate query keys:** web `URLSearchParams.get` takes the first. Match this on iOS.
9. The `UIPasteboard` doc text about `localOnly` ("specify false … to exclude from Handoff") looks inverted relative to the parameter name [6]. Use the `.localOnly: true` option if you need it, and verify.
10. Unsplash license terms for photos embedded in shared images: recheck.

---

## Sources

[1] Apple, ShareLink (SwiftUI): https://developer.apple.com/documentation/swiftui/sharelink (content read via https://developer.apple.com/tutorials/data/documentation/swiftui/sharelink.json; availability iOS 16.0)
[2] Apple, SharePreview: https://developer.apple.com/documentation/swiftui/sharepreview
[3] Apple, ImageRenderer: https://developer.apple.com/documentation/swiftui/imagerenderer
[4] Apple, Transferable (Core Transferable): https://developer.apple.com/documentation/coretransferable/transferable
[5] Apple, UIActivityViewController: https://developer.apple.com/documentation/uikit/uiactivityviewcontroller
[6] Apple, UIPasteboard: https://developer.apple.com/documentation/uikit/uipasteboard
[7] Apple, PasteButton: https://developer.apple.com/documentation/swiftui/pastebutton
[8] Apple, Defining a custom URL scheme for your app: https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app
[9] Apple, onOpenURL(perform:): https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:)
[10] Apple, Supporting associated domains: https://developer.apple.com/documentation/xcode/supporting-associated-domains
[11] Apple, Supporting universal links in your app: https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app
[12] Apple, Allowing apps and websites to link to your content: https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content
[13] Apple, applinks (Bundle Resources): https://developer.apple.com/documentation/bundleresources/applinks
[14] Apple WWDC20, What's new in universal links (session 10098): https://developer.apple.com/videos/play/wwdc2020/10098/
[15] Figma Forum, "Static files in public folder not served at root URL after publish" (Jun 1 2026, Figmate reply): https://forum.figma.com/report-a-problem-6/static-files-in-public-folder-not-served-at-root-url-after-publish-54462
[16] Apple, com.apple.developer.associated-domains entitlement: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.associated-domains
[17] Figma Forum, "robots.txt, static files and redirects" feature request (Aug 2025 to Apr 2026): https://forum.figma.com/suggest-a-feature-11/robots-txt-static-files-and-redirects-44002
[18] Figma Help, Manage a custom domain for your site: https://help.figma.com/hc/en-us/articles/31414274019863
[19] Figma Forum, custom domain option missing for Figma Make site on Education plan: https://forum.figma.com/report-a-problem-6/custom-domain-option-missing-for-figma-make-site-on-education-plan-56810 (seen in search results only, not opened)
[20] Apple, Promoting apps with Smart App Banners: https://developer.apple.com/documentation/webkit/promoting-apps-with-smart-app-banners
[21] Apple, App Clips (framework overview): https://developer.apple.com/documentation/appclip
[22] Apple HIG, App Clips: https://developer.apple.com/design/human-interface-guidelines/app-clips

Local source read: the web repo's `src/App.tsx` (lines ~416–446: `copyLink`, `downloadMarkdown`, URL param parsing).
