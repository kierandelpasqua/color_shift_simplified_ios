# Color Shift (iOS): Toolchain and App Store Release Requirements

Last checked: 2026-11-24

Scope: what a solo developer with no Apple Developer Program membership needs to take a free, single-screen SwiftUI iPhone utility ("Color Shift": no accounts, no analytics, no network calls, 12 bundled Unsplash photos with credits) through TestFlight to a public App Store release, as of late November 2026.

Conventions: `[n]` refers to the Sources list at the end. **(unverified)** marks a claim I could not confirm on an Apple or primary source. **(inference)** marks my own reasoning from sourced facts.

---

## TL;DR

- **Toolchain now:** Xcode 27.2 (27B52, Oct 29, 2026) is the current stable release, and Xcode 27.3 is in beta [3]. Xcode 27 ships Swift 6.4 and the iOS 27 SDK, needs **macOS Tahoe 26.6 or later**, and **runs only on Apple silicon Macs** [4][5]. Its iOS deployment-target range is iOS 15 to 27, so an **iOS 17 deployment target is fine** [5].
- **Upload rule in effect now:** builds must use Xcode 26+ and the iOS 26 SDK (since Apr 28, 2026), and iOS apps must target iOS 13 or later (since Sep 9, 2026) [1]. **Starting April 2027, uploads must use the iOS 27 SDK or later** [2]. Start on Xcode 27 so you aren't caught by the deadline.
- **iPhone Duo:** for apps built with the iOS 27.1 SDK or later, Apple's screenshot spec says **iPhone Duo screenshots will be required starting April 2027** [11]. The layout should resize freely; don't assume a fixed screen size [12][13].
- **Developer Program:** **US$99/year**. Enroll as an **Individual**: no D-U-N-S number is needed, but your **legal name is shown as the seller** [6][7]. You must also declare **EU DSA trader status**. A non-commercial free app can usually declare "not a trader", which avoids publishing your address and phone in the EU (that's your judgement call, not legal advice) [8].
- **Privacy:** a `PrivacyInfo.xcprivacy` is required if you use `UserDefaults`/`@AppStorage`. Declare `NSPrivacyAccessedAPICategoryUserDefaults` with reason **`CA92.1`** [14][15]. In App Store Connect, answer App Privacy with **"No, we do not collect data from this app"** [17]. **You still need a privacy policy URL**, and Guideline 5.1.1(i) also wants it **reachable inside the app** [17][18][22]. Set `ITSAppUsesNonExemptEncryption = NO` [19].
- **Age rating:** the 2025 system has tiers 4+/9+/13+/16+/18+ [20][21]. New "Shared Location" and "Dating and Relationships" descriptors started Nov 16, 2026, and are required for every app by **Jan 12, 2027** [23]. Color Shift should answer "None/No" to everything and get **4+**.
- **Main review risk:** **Guideline 4.2 (Minimum Functionality)** [22]. To mitigate, ship real utility: picking your own photo, saving or sharing the result, accessibility, polish, and a clear description.
- **Timing (sourced):** enrollment confirmation normally arrives within 24 hours, or you contact Apple [7]. App Review handles 50% of submissions in under 24 hours and 90% in under 48 hours [24]. TestFlight builds last 90 days [25].

---

## 1. Toolchain: Xcode, SDK, Swift, macOS

### 1.1 Current versions (as of 2026-11-24)

| Item | Current | Source |
|---|---|---|
| Xcode (stable) | **Xcode 27.2** (27B52), released Oct 29, 2026 | [3] |
| Xcode (beta) | Xcode 27.3 beta 2 (27C5035i), Nov 16, 2026 | [3] |
| Earlier 27.x | Xcode 27 (27A266a) Sep 14, 2026; Xcode 27.1 (27A9275) Oct 15, 2026 | [3] |
| iOS (shipping) | iOS 27.2.1 (Nov 9, 2026); iOS 27.3 beta 2 v2 (Nov 19, 2026) | [3] |
| Swift | **Swift 6.4** (Xcode 27.x); Swift 6.3 in Xcode 26.4–26.6 | [4][5] |
| SDKs in Xcode 27 | iOS 27, iPadOS 27, tvOS 27, watchOS 27, macOS 27, visionOS 27 | [4] |
| macOS needed for Xcode 27.x | **macOS Tahoe 26.6 or later** | [4][5] |
| Mac hardware | "Xcode 27 will only install and run on Apple silicon Macs." | [4] |
| iOS deployment-target range (Xcode 27.x) | iOS 15 – 27 | [5] |
| On-device debugging (Xcode 27) | iOS 17 and later | [4] |
| Swift language modes supported | 4, 4.2, 5, 6 | [5] |

The Xcode 27.1 SDK is the first SDK with iPhone Duo support. Apple's iPhone Duo page says "Xcode 27.1" provides the SDKs to build and test for iPhone Duo [12].

### 1.2 Minimum SDK/Xcode for App Store uploads

From Apple's "Upcoming Requirements" page [1]:

- **Since April 28, 2026:** apps uploaded to App Store Connect must be built with **Xcode 26 or later** using an SDK for iOS 26 (or the equivalent for other platforms).
- **Since September 9, 2026:** iOS and iPadOS apps uploaded to App Store Connect must target **iOS 13 or later**.

From Apple news, "App Store submissions now open for the latest OS releases" (Sep 9, 2026) [2]:

> "Starting April 2027, apps and games uploaded to App Store Connect need to meet the following minimum requirements: iOS and iPadOS apps must be built with the iOS 27 & iPadOS 27 SDK or later …"

Apple says "April 2027" but gives no exact day. Past requirements took effect in late April (for example, April 28, 2026 [1]). **(unverified: exact 2027 day)**

**Recommendation:** build with **Xcode 27.2** (or the latest 27.x) from day one. Xcode 26.x builds are accepted today but won't be after April 2027.

### 1.3 Liquid Glass and the deployment-target question

- If you build with the iOS 26+ SDK, standard SwiftUI controls pick up the new design on iOS 26+ devices. The old opt-out key `UIDesignRequiresCompatibility` is now ignored: Apple's documentation says "The system ignores this key when you build for iOS 27 or later" [26]. With Xcode 27 you get Liquid Glass styling on iOS 26/27 devices automatically.
- **Deployment target iOS 17 vs 26 (inference):** you don't need to raise the deployment target to get Liquid Glass. Raise it only if you want to call iOS 26-only APIs (for example, the explicit `glassEffect` modifiers) without `if #available` checks. Keeping iOS 17 reaches more devices. Raising it to 26 simplifies the code. Both are accepted, since Xcode 27's range is iOS 15–27 [5] and the floor is iOS 13 [1].
- **iPhone Duo (new foldable-class device in the iOS 27 cycle):**
  - Built with the iOS 26 SDK or earlier: the app shows at a familiar size in the center of the inner display, with empty space around it.
  - Built with the iOS 27 SDK: the app resizes dynamically.
  - Built with the iOS 27.1 SDK or later: the app gets the fully optimized layout, with toolbars and tab bars moving to a vertical position [13].

  Apple's guidance: don't size from `UIScreen.main.bounds`, don't base layout on orientation or `userInterfaceIdiom`/size class, and check `.aspectRatio(contentMode: .fill)` media for unwanted cropping [13]. **For Color Shift, a full-bleed photo is exactly the pattern to test.**

---

## 2. Apple Developer Program

### 2.1 Cost and enrollment type

| | Individual / sole proprietor | Organization |
|---|---|---|
| Fee | **99 USD per membership year** (shown in local currency) [6] | Same [6] |
| Seller name on App Store | **Your personal legal name** [6][7] | Legal entity name [6][7] |
| D-U-N-S Number | Not required | **Required** (except government entities) [6] |
| Other requirements | Apple Account with 2FA, age of majority, legal name (no alias or company name in the name fields) [6][7] | Legal entity able to sign contracts (no DBAs or trade names), signing authority, work email on the org's domain, a functional public website [6] |
| Verification | Legal name, email, phone, address (no P.O. boxes) [6] | Legal authority, entity status, D-U-N-S, domain email, website [6] |

- You can enroll in the **Apple Developer app** or on the web [7]. Enrolling through the app makes membership an auto-renewing annual subscription [7].
- If you enroll as an individual and pay by credit card, the card must be **your own**. Otherwise enrollment is delayed and Apple asks for government photo ID [7].
- **Fee waivers** exist only for nonprofits, accredited educational institutions, and government entities [6], so they don't apply here.
- **Recommendation for Color Shift:** enroll as an **Individual** unless you already have a legal entity with a D-U-N-S number and you don't want your personal name on the store listing.

### 2.2 Timeline

- Apple: "If you haven't received a membership confirmation within 24 hours of your purchase, contact us." [7]
- Several Apple Developer Forums posts report delays from days to weeks, especially outside the US or when the legal name doesn't match. These reports are anecdotal [27] **(unverified as typical)**. Organizations take longer because Apple verifies the D-U-N-S number first [6][7].
- Xcode Cloud can now build and test without Developer Program membership (new in Xcode 27) [28]. **TestFlight and App Store distribution still require membership** (inference from [25]: TestFlight runs through App Store Connect).

### 2.3 EU Digital Services Act (DSA) trader status

- **Since Oct 16, 2024:** trader status is required to submit app updates for apps distributed in the EU. **Since Feb 17, 2025:** apps without trader status are removed from the EU App Store until status is provided [1].
- Every developer must declare a status, even if they don't distribute in the EU [8].
- **Signs that you're a trader:** revenue (IAP, paid app, ads), commercial promotion, VAT registration, acting in a professional or business capacity [8].
- **If you're a trader:** your contact details are shown on EU product pages. For individuals that means an address (a P.O. box is allowed with proof), phone, and email. Apple verifies them with 2FA and supporting documents [8].
- **Non-trader option:** choose "This is not a trader account". No contact info is needed, and EU consumers are told that consumer-protection rights don't apply [8].
- **Color Shift (inference, not legal advice):** a free app with no IAP or ads, made by a hobbyist, probably qualifies as **non-trader**. Apple says it can't decide this for you [8]. Where to set it: App Store Connect > Business > Agreements > Compliance > Digital Services Act (Account Holder or Admin) [8].
- Also accept the **Free Apps Agreement** (part of the Program License Agreement). For a free app you don't need the Paid Apps Agreement, tax forms, or banking **(unverified on a fetched page in this pass; standard ASC behavior)**.

---

## 3. Project setup essentials (Xcode 27)

### 3.1 Bundle ID and signing

- Pick a reverse-DNS bundle ID you'll keep forever, such as `com.<yourname>.colorshift`. You can't change it after the first upload **(unverified on a fetched page)**.
- Use **Automatic signing** (Signing & Capabilities > Team > your Developer Program team). Xcode creates the App ID, the development and distribution certificates, and the provisioning profiles. TestFlight builds need application identifiers in their provisioning profiles [25].
- Before you join the program, a free "Personal Team" works for running on your own device. Its profiles are short-lived and can't upload to App Store Connect **(unverified)**.
- Don't create multiple bundle IDs for variants of the same app (Guideline 4.3(a)) [22].

### 3.2 App icon (Icon Composer and the asset catalog)

- **Icon Composer (recommended for a new app):** you make a single multilayer `.icon` file "that you can add to your Xcode project to represent your Liquid Glass app icon everywhere … across iOS, iPadOS, macOS, watchOS, and the App Store" [29].
  - The system renders every size and appearance from that one file.
  - If your deployment target is below 26, **Xcode automatically generates icon images for previous releases at build time** [29].
  - Adding an Icon Composer file **replaces** the asset-catalog AppIcon [29].
- **Artwork prep [29]:**
  - Use a 1024×1024 canvas for iPhone.
  - Export layers as **SVG** where possible (PNG otherwise), back-to-front, with text converted to outlines.
  - Strip blurs, shadows, background colors and gradients. Add those effects in Icon Composer instead.
  - Don't export the mask.
  - Open the tool via **Xcode > Open Developer Tool > Icon Composer**.
- **New in Xcode 27 (Icon Composer 2.0):** a sharper rendering mode for "upcoming 2027 operating systems" with refractivity, outside specular, and deeper shadows. You can preview the old and new design generations in the toolbar. Apple says to add the icon to the project once it looks good in both [4]. You can also adjust refraction per layer and preview the icon on previous OS releases [30].
- **Asset-catalog alternative:** a single 1024×1024 image from which Xcode generates all iOS sizes (the default) [31]. Variants:
  - **Any, Dark, Tinted** appearances, set via Attributes inspector > Appearance [31].
  - The Dark icon should have a **transparent background**. The Tinted icon should be **grayscale** [31].
  - If you skip them, the system auto-generates dark and tinted treatments [31].
- For an app named "Color Shift", a layered Icon Composer icon is the better showcase and avoids hand-making dark and tinted variants **(inference)**.

### 3.3 Launch screen

- "Every iOS app must provide a launch screen" [32]. For a SwiftUI app, use the **Info.plist `UILaunchScreen` dictionary** (for example, a background color and an optional image) rather than a storyboard [32]. New SwiftUI templates include `UILaunchScreen` already **(unverified for the Xcode 27 template)**.
- Make it look like the first screen, with basic views [32].

### 3.4 Orientation and device family

- **iPhone-only:** set Supported Destinations to iPhone only (remove iPad, Mac "Designed for iPad", and visionOS). `TARGETED_DEVICE_FAMILY = 1` **(unverified build-setting detail)**. Then you don't need iPad screenshots; they're required only "if your app supports iPadOS" [11].
- Apple's general practice is that iPhone-only apps still run on iPad in a compatibility window **(unverified on a fetched page in this pass)**.
- **Orientation:** portrait-only is allowed, but **iPhone Duo** changes the picture.
  - Apple tells developers to avoid orientation-based layout logic and to support arbitrary sizes and aspect ratios [13].
  - Developer forum threads discuss deprecation of `UIRequiresFullScreen` and of orientation locks in the iOS 27 era [33] **(unverified: Apple documentation not fetched)**.
  - **Recommendation:** build the SwiftUI layout to adapt to any width and height, even if you declare portrait on classic iPhones.

### 3.5 Info.plist checklist for this app

| Key | Value | Why |
|---|---|---|
| `ITSAppUsesNonExemptEncryption` | `NO` (Boolean false) | No custom crypto. Skips the export-compliance question on every build [19] |
| `UILaunchScreen` | dict | Launch screen requirement [32] |
| `CFBundleDisplayName` | "Color Shift" | Home Screen name |
| `UIDesignRequiresCompatibility` | **omit** | Ignored with the iOS 27 SDK [26] |
| `NSPhotoLibraryAddUsageDescription` | only if saving to Photos | Purpose string for any protected resource you add **(general practice; not fetched)** |

---

## 4. Privacy

### 4.1 Privacy manifest (`PrivacyInfo.xcprivacy`)

- A privacy manifest records (a) the data types your app collects and (b) the **required-reason APIs** it uses [14]. Create it with File > New File > **App Privacy** and add it to the app target. The filename must be `PrivacyInfo.xcprivacy` [14].
- **Since May 1, 2024**, App Store Connect rejects uploads that use required-reason APIs without declared reasons. This covers your own code, not just SDKs [1][15].
- The required-reason API categories are `NSPrivacyAccessedAPICategoryFileTimestamp`, `…SystemBootTime`, `…DiskSpace`, `…ActiveKeyboards`, and `…UserDefaults` [16].
- **UserDefaults / `@AppStorage`:** use category `NSPrivacyAccessedAPICategoryUserDefaults` with reason **`CA92.1`**. Apple's wording: "Declare this reason to access user defaults to read and write information that is only accessible to the app itself." [16] Other codes:
  - `1C8F.1`: App Group shared defaults.
  - `C56D.1`: third-party SDK wrappers only.
  - A code for MDM managed-configuration keys [16].
- For Color Shift (no data collected, no tracking):

```xml
<key>NSPrivacyTracking</key><false/>
<key>NSPrivacyTrackingDomains</key><array/>
<key>NSPrivacyCollectedDataTypes</key><array/>
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array><string>CA92.1</string></array>
  </dict>
</array>
```

- If the app reads file modification dates, such as `FileManager` attributes on bundled photos, also declare `FileTimestamp` with the right reason. Audit your code before upload **(inference)**.

### 4.2 App Privacy "nutrition label"

- "Collect" means "transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time." Data processed only on device isn't collected [9].
- In App Store Connect: App Privacy > Get Started > select **"No, we do not collect data from this app"** > Save, then **Publish**. No further questions follow [17]. The product page then shows "Data Not Collected" **(label wording unverified on a fetched page)**.
- This is only true if you really ship **no analytics, crash SDKs, or network calls**. Any remote image loading from Unsplash would change the answer **(inference)**.
- Roles: Account Holder, Admin, or App Manager [17].

### 4.3 Privacy policy URL: required even when you collect nothing

- App Store Connect Help: "A privacy policy URL is required for all apps" [17]. On the App Information page, the Privacy Policy URL is "Required for iOS and macOS apps" [10].
- Apple's App Privacy Details page lists "Privacy Policy (Required)" [9].
- **App Review Guideline 5.1.1(i):** "All apps must include a link to their privacy policy in the App Store Connect metadata field **and within the app in an easily accessible manner**." [22]
- **Action:**
  - Host a short policy, for example a GitHub Pages page or a page on the existing web app's domain. Say that the app collects no personal data, makes no network requests, stores preferences only on device, and include a contact email.
  - **Link it from inside the app** too, for example in an About/Credits sheet that also holds the Unsplash credits.

### 4.4 Export compliance

- Every upload counts as an export from US servers, so App Store Connect asks compliance questions per version unless Info.plist answers them [19].
- Set `ITSAppUsesNonExemptEncryption` to **NO** if the app (including libraries) "doesn't use encryption, or if it only uses forms of encryption that are exempt" [19]. Color Shift uses no networking and no crypto, so the value is **NO**.

---

## 5. Age rating and content rights

### 5.1 Age rating questionnaire (2025 system plus 2026 additions)

- **July 24, 2025:** Apple added **13+, 16+, 18+** to 4+ and 9+. New required question groups cover **in-app controls, capabilities, medical or wellness topics, and violent themes**. The response deadline was **Jan 31, 2026** [21][1].
- Current tiers: **4+, 9+, 13+, 16+, 18+, and Unrated**. Unrated apps can't be published on the App Store [20].
- Question groups [20]:
  - **In-App Controls:** parental controls, age assurance.
  - **Capabilities:** unrestricted web access, UGC, social media, messaging, shared location, advertising.
  - **Mature Themes:** includes dating and relationships.
  - **Medical or Wellness.**
  - **Sexuality or Nudity.**
  - **Violence.**
  - **Chance-Based Activities.**
- **Sept 2026:** a social-media capability question was added (it ties into Time Allowances) [2][34].
- **Nov 2, 2026 announcement:** starting **Nov 16, 2026**, the questionnaire adds **Shared Location** and **Dating and Relationships** descriptors. They're required on any update or questionnaire edit, and **all apps must complete them by Jan 12, 2027** [23].
- Age Rating is a required App Information field [10].
- **Color Shift:** answer No/None throughout. There is no web view, so "Unrestricted Web Access" is No. If the photo credits link out to Unsplash in Safari, that's an external link, not in-app unrestricted browsing **(inference)**. The expected result is **4+**.

### 5.2 Content rights declaration (Unsplash photos)

- In App Store Connect (App Information > Content Rights), you declare whether the app contains, shows, or accesses third-party content, and that you have the rights to it [10].
- For Color Shift, answer **Yes, it contains third-party content, and I have the necessary rights**. The basis is the **Unsplash License** [35]:
  - Free use for commercial and non-commercial purposes.
  - No permission needed.
  - Attribution is appreciated but not required.
- **Unsplash restrictions [35]:**
  - Images "cannot be **sold** without significant modification". A free app isn't selling them.
  - No "compiling images from Unsplash to replicate a similar or competing service". Twelve photos used as demo material for a color tool isn't a stock-photo service **(inference)**.
- **Guideline 5.2.1:** don't use protected third-party material without permission [22]. The Unsplash License doesn't address **people, trademarks, or property** shown in photos [35]. Avoid photos with recognizable people, logos, or brand products, or check them individually **(inference)**.
- **Practical tips:**
  - Keep the credits screen.
  - Keep a `CREDITS.md` in the repo with each photo's URL and photographer.
  - In App Review Notes, say the images are bundled under the Unsplash License, with a link.

---

## 6. App Store listing

### 6.1 Text fields and limits

| Field | Limit / rule | Required? | Source |
|---|---|---|---|
| App Name | 2–30 characters | Yes | [10] |
| Subtitle | ≤ 30 characters | Optional | [10] |
| Promotional Text | 170 characters (editable without a new version) | Optional | [36] |
| Description | 4,000 characters, plain text | Yes | [36] |
| Keywords | **100 bytes** total, comma-separated; each keyword longer than 2 characters | Yes | [36] |
| Support URL | Must include the protocol and lead to real contact info | **Yes** | [36] |
| Marketing URL | Must include the protocol | Optional | [36] |
| Privacy Policy URL | — | **Yes** (iOS) | [10][17] |
| Copyright | "Year Owner" (© is added automatically) | Yes | [36] |
| What's New | 4,000 characters; not shown for the first version | Required after v1 | [36] |
| App Review Notes | 4,000 bytes | Optional | [36] |
| Demo account | Only if the app requires sign-in | N/A here | [36] |

Category: probably **Photo & Video** or **Utilities** (your choice) [10].

### 6.2 Screenshots (iPhone-only app)

From "Screenshot specifications" [11]:

- **Required:** "At least one screenshot for iPhone with Dynamic Island (medium display)". Accepted sizes: 1179×2556 or **1206×2622** portrait. Devices: iPhone 14 Pro–18 Pro, 15/16/17.
- If you skip the medium size, App Store Connect falls back to scaled Face ID (large display) screenshots. In practice, if your UI is the same across sizes, upload at the highest required resolution and let App Store Connect scale down [11].
- **Dynamic Island (large display):** 1260×2736, 1290×2796, or **1320×2868** portrait. Devices: iPhone Air, 14 Pro Max–18 Pro Max, Plus models. **Recommended**, so the largest phones get sharp images [11].
- **iPhone Duo:** outer display 1398×2034, inner 2007×2853 (or landscape). "Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later." Supplying them earns a **"Made for iPhone Duo"** badge [11].
- 1–10 screenshots per size, in `.jpeg`, `.jpg`, or `.png`, with **no alpha or transparency** [11].
- Guideline 2.3.3: screenshots must "show the app in use, and not merely the title art, login page, or splash screen" [22].
- **App previews** (video) are optional, up to three per localization per device size [36].
- App Store Connect is adding a product page preview tool and new product page header and search result assets ("coming soon" as of Sep 9, 2026) [2].

**Practical approach:** capture from the iPhone 17 Pro Max simulator (6.9", 1320×2868) and the iPhone 17 Pro simulator (1206×2622). Add Duo screenshots from the Xcode 27.1+ iPhone Duo simulator if you build with the 27.1+ SDK [11][13]. Show 3–5 shots: before/after color shift, the photo picker, controls, the share/save result, and dark mode.

### 6.3 Accessibility Nutrition Labels

- These are **voluntary for now**. Apple says they'll become required for new apps and updates "over time", with "ample time" given beforehand. No date has been announced [37].
- Features you can claim: VoiceOver, Voice Control, Larger Text, Dark Interface, Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion, Captions, Audio Descriptions [37].
- Claim a feature only if users can complete **all common tasks** with it. Inaccurate claims fall under Guideline 2.3 [37]. The labels show on iOS 26+ product pages, and search can rank apps by declared features [37].
- **Relevant to a color app:**
  - "Differentiate Without Color Alone": make sure states aren't conveyed only by hue.
  - VoiceOver: label sliders and swatches.
  - Larger Text: Dynamic Type.
  - Dark Interface.
  - Reduced Motion.

  Declaring these honestly can also help against 4.2 by showing a polished app **(inference)**.

---

## 7. TestFlight

| Aspect | Internal testing | External testing |
|---|---|---|
| Who | Up to **100** App Store Connect users on your team [25] | Up to **10,000** people via email or **public link** [25] |
| Beta App Review | Not required **(implied by [25]; only external is described as reviewed)** | **The first build added to a group goes to Beta App Review.** Later builds may not need a full review [25] |
| Required test info | — | **Beta App Description is required.** Feedback email is recommended [38]. Other TestFlight App Review fields (contact, privacy policy) are in a separate reference page **(not fetched)** |
| Build lifetime | **90 days**, then unavailable [25] | Same [25] |

- The new **Xcode Cloud** workflow template can distribute builds to TestFlight automatically (new in Xcode 27) [28].
- A build you later submit to the App Store remains testable by invited testers unless you expire it [25].
- How long Beta App Review takes isn't published separately **(unverified)**. Treat it like App Review (about 24–48 hours) [24].
- Solo path: upload a build, start internal testing on your own devices right away, then add a small external group (friends, via public link) to check first-run behavior before submitting.

---

## 8. App Review Guidelines most relevant here

### 8.1 Guideline 4.2: Minimum Functionality (the main risk)

> "Your app should include features, content, and UI that elevate it beyond a repackaged website. If your app is not particularly useful, unique, or 'app-like,' it doesn't belong on the App Store. If your App doesn't provide some sort of lasting entertainment value or adequate utility, it may not be accepted." [22]

There are three risk factors for Color Shift: a single screen, a port of an existing web app, and a narrow feature set. **Mitigations (inference, based on the guideline text):**

1. **Use the user's own photos.** Add PhotosPicker so the app does more than recolor 12 stock images. PhotosPicker runs out of process and needs no photo-library permission for read **(unverified: not fetched this pass)**.
2. **Produce something.** Export or share the recolored image (ShareLink, or save to Photos with an add-only usage string).
3. **Be native, not a web wrapper.** No WKWebView. Use system controls, haptics, Dynamic Type, dark mode, and Liquid Glass. Guideline 4.2 explicitly targets "repackaged website[s]" [22].
4. **Add depth without adding screens:** presets or favorites (persisted via `@AppStorage`, already covered by `CA92.1`), undo/compare (before/after), and maybe copying hex values.
5. **Make the listing explain the utility.** The description and screenshots should show a clear use case [22 §2.3].
6. **Use App Review Notes** to explain what the app does, that it works fully offline, where the photos come from (Unsplash License), and where the privacy policy link is in the app.

### 8.2 Guideline 4.1: Copycats, and 4.3: Spam

- Don't copy a popular app's name, UI, or icon. Don't use another developer's brand in your icon or name without approval [22].
- **Action:** search the App Store for "Color Shift" before you settle on the name. The name must be unique on the store and can be at most 30 characters [10]. Choose a distinct icon.
- 4.3: don't submit something "indistinguishable from what's already widely available", and don't create several bundle IDs for the same app [22]. Real features (§8.1) also cover this.

### 8.3 Guideline 5.2: Intellectual property

- 5.2.1: no unlicensed trademarks or copyrighted works. Apps must be submitted by the person or entity that owns or licenses the IP [22].
- 5.2.2: if you display content from a third-party service, its terms must allow it, and you must be able to show authorization on request [22].
- Bundled Unsplash images fall under the Unsplash License, and keeping credits is good practice (see §5.2) [35]. If you ever switch to the Unsplash **API**, the API terms apply (attribution, hotlinking, and so on), and the privacy answers change too **(inference; API terms not fetched)**.
- Check the Figma-derived UI assets (fonts, icons) for license compatibility. SF Symbols and system fonts are fine within Apple platforms **(inference)**.

### 8.4 Other guidelines that commonly trip first submissions

- **2.1 App Completeness:** no placeholder text, every URL works (support, privacy), no crashes [22].
- **2.3 Accurate Metadata:** screenshots and description must match the app [22].
- **5.1.1(i):** privacy policy link both in App Store Connect and **inside the app** [22].

---

## 9. Release checklist for Color Shift

Time estimates are sourced where Apple gives them. Everything else is a rough personal estimate, marked *(est.)*.

### Phase A: Accounts (start first; it can block everything else)

- [ ] A1. Make sure your Apple Account uses 2FA and your **legal name** [6][7].
- [ ] A2. Enroll in the Apple Developer Program as an **Individual** (US$99/yr), in the Apple Developer app or on the web. Pay with **your own card** [6][7]. *Confirmation is normally within 24 hours. Contact Apple if it hasn't arrived by then [7]. Forum reports describe longer delays [27].*
- [ ] A3. In App Store Connect: accept agreements, then go to Business > Agreements > Compliance > **DSA** and declare trader or non-trader [8]. *(est. 15 min for non-trader; days if trader verification needs documents)*

### Phase B: Toolchain and project (can run in parallel with A)

- [ ] B1. Mac on Apple silicon, **macOS Tahoe 26.6+**, **Xcode 27.2** (or latest 27.x) [4][5]. *(est. 1–2 h download/install)*
- [ ] B2. New SwiftUI app: iPhone-only destination, deployment target **iOS 17** (or 26), Swift 6.4 language mode [5].
- [ ] B3. Final bundle ID. Automatic signing with your team (after A2).
- [ ] B4. Build an adaptive layout. No `UIScreen.main.bounds`, no orientation or idiom checks. Test in the resizable simulator and the iPhone Duo simulator (Xcode 27.1+) [13].
- [ ] B5. App icon: create a layered `.icon` in **Icon Composer** and preview both design generations [4][29]. *(est. 2–4 h)*
- [ ] B6. `UILaunchScreen` in Info.plist [32].
- [ ] B7. `ITSAppUsesNonExemptEncryption = NO` [19].
- [ ] B8. `PrivacyInfo.xcprivacy` with UserDefaults/**CA92.1**, no tracking, no collected data [14][16].
- [ ] B9. In-app **About / Credits** sheet with the Unsplash photographer credits **and the privacy policy link** [22][35].
- [ ] B10. Add 4.2 hardening features (PhotosPicker import, share/export, presets) [22].
- [ ] B11. Accessibility pass: VoiceOver labels, Dynamic Type, Reduce Motion, dark mode, not relying on color alone [37].

### Phase C: Web pages (est. 1 h)

- [ ] C1. Privacy policy page (public HTTPS) [17][22].
- [ ] C2. Support page with real contact info (HTTPS) [36].

### Phase D: App Store Connect record

- [ ] D1. Create the app record: name (≤30 characters, unique), primary language, bundle ID, SKU [10].
- [ ] D2. App Information: subtitle, category, **Content Rights = contains third-party content, rights held** [10], **age rating questionnaire**, including the Nov 2026 Shared Location / Dating descriptors (target 4+) [20][23].
- [ ] D3. App Privacy: **"No, we do not collect data from this app"**, then **Publish**. Privacy policy URL [17].
- [ ] D4. Pricing: Free. Choose availability (countries, EU included once DSA is set) [8].
- [ ] D5. Optional: fill in Accessibility Nutrition Labels [37].

### Phase E: TestFlight

- [ ] E1. Product > Archive > Distribute App > App Store Connect (upload). *(est. 10–30 min per build, including processing; unverified)*
- [ ] E2. Internal testing on your own devices. No review [25].
- [ ] E3. Optional external group or public link. Fill in the Beta App Description (required) and feedback email [38]. The first build goes to Beta App Review [25]. *(Expect about 1–2 days, by analogy with [24]; unverified)*
- [ ] E4. Fix issues. Builds expire after 90 days [25].

### Phase F: Submission

- [ ] F1. Screenshots: iPhone Dynamic Island **medium** (required) plus **large** (recommended), and **iPhone Duo** if built with the 27.1+ SDK (mandatory from April 2027) [11]. No alpha channel [11]. *(est. 2–3 h)*
- [ ] F2. Description, keywords (100 bytes), promotional text, support URL, copyright [36].
- [ ] F3. App Review notes: what the app does, that it's offline, the photo licensing, and where the privacy link lives in the app [36].
- [ ] F4. Select the build and answer any remaining compliance prompts. Choose manual or automatic release.
- [ ] F5. Submit. *App Review: about 50% within 24 hours, 90% within 48 hours [24].* If rejected under 4.2, answer in Resolution Center, add features, and resubmit.
- [ ] F6. Release. *(Store propagation time isn't documented in the sources here; unverified)*

**Realistic calendar (est.):** about 1 week from enrollment to public listing if enrollment clears in about a day and review passes the first time. Add 1–2 weeks of buffer for enrollment delays or a 4.2 rejection.

### Deadlines to watch

| Date | What | Source |
|---|---|---|
| **Jan 12, 2027** | All apps must have the Shared Location and Dating and Relationships age-rating declarations | [23] |
| **April 2027** | Uploads must use the iOS 27 SDK or later; iPhone Duo screenshots required for apps on the iOS 27.1+ SDK | [2][11] |

---

## Open questions / uncertain

1. **Exact April 2027 day** for the iOS 27 SDK requirement. Apple says only "April 2027" [2].
2. **iPhone Duo screenshots:** the spec page says they're "required for any app using the iOS 27.1 SDK or later" from April 2027 [11]. Does that also cover iPhone-only, portrait-only apps? Most likely yes, but confirm in App Store Connect at upload time.
3. **Orientation locks and `UIRequiresFullScreen` in the iOS 27 era:** only forum discussion was found [33]. Check Apple's iOS 27 release notes and HIG before locking to portrait.
4. **Enrollment time for individuals outside the US:** Apple gives only the 24-hour contact guidance [7]. Forums report longer waits [27].
5. **Beta App Review turnout time** isn't published.
6. **DSA trader determination** is a legal judgement. Apple won't decide it [8].
7. **Accessibility Nutrition Labels** will become mandatory at an unannounced date [37].
8. Whether App Store Connect's privacy policy requirement can be met with a minimal "we collect nothing" page. Nothing in the sources says otherwise, but 5.1.1(i) lists content items such as retention and deletion. Address them briefly ("no data is collected, so nothing is retained") [22].
9. Not fetched this pass: TestFlight App Review information properties (contact and privacy fields for external beta), PhotosPicker permission behavior, the default Info.plist contents of the SwiftUI template in Xcode 27, and Unsplash API terms (only relevant if the app ever fetches remotely).

---

## Sources

1. Apple Developer, "Upcoming Requirements": https://developer.apple.com/news/upcoming-requirements/
2. Apple Developer News, "App Store submissions now open for the latest OS releases" (Sep 9, 2026): https://developer.apple.com/news/?id=k1mtkt1k
3. Apple Developer, Releases: https://developer.apple.com/news/releases/
4. Xcode 27 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
5. Apple Developer, Xcode Support (versions/requirements table): https://developer.apple.com/support/xcode/
6. Apple Developer Program, Enrollment: https://developer.apple.com/programs/enroll/
7. Apple Developer Account Help, Program enrollment: https://developer.apple.com/help/account/membership/program-enrollment/
8. App Store Connect Help, Manage EU DSA trader requirements: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
9. Apple, App Privacy Details on the App Store: https://developer.apple.com/app-store/app-privacy-details/
10. App Store Connect Help, App information reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
11. App Store Connect Help, Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
12. Apple Developer, iPhone Duo: https://developer.apple.com/iphone-duo/
13. Apple Developer, Prepare your app for iPhone Duo: https://developer.apple.com/iphone-duo/prepare/
14. Apple Documentation, Privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
15. Apple Documentation, Describing use of required reason API: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
16. Apple Documentation, NSPrivacyAccessedAPIType (categories and reason codes, incl. CA92.1): https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
17. App Store Connect Help, Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
18. (see [22], Guideline 5.1.1(i))
19. Apple Documentation, Complying with encryption export regulations: https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
20. App Store Connect Help, Age ratings values and definitions: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
21. Apple Developer News, "Updated age ratings in App Store Connect" (Jul 24, 2025): https://developer.apple.com/news/?id=ks775ehf
22. App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
23. Apple Developer News, "Upcoming: New age rating content descriptors in App Store Connect" (Nov 2, 2026): https://developer.apple.com/news/?id=yxkh08us
24. Apple Developer, App Review: https://developer.apple.com/distribute/app-review/
25. App Store Connect Help, TestFlight overview: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview
26. Apple Documentation, UIDesignRequiresCompatibility: https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility
27. Apple Developer Forums, enrollment timing threads: https://developer.apple.com/forums/thread/85106 and https://developer.apple.com/forums/thread/807285
28. Apple Documentation, Xcode updates (June/Sept 2026 entries): https://developer.apple.com/documentation/updates/xcode
29. Apple Documentation, Creating your app icon using Icon Composer: https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer
30. (see [28], June 2026 "Asset management" entry)
31. Apple Documentation, Configuring your app icon: https://developer.apple.com/documentation/xcode/configuring-your-app-icon
32. Apple Documentation, Specifying your app's launch screen: https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen
33. Apple Developer Forums, "iOS 27 SDK requirements: UIDesignRequiresCompatibility & UIRequiresFullScreen deprecation and enforcement timeline": https://developer.apple.com/forums/thread/820475
34. Apple Developer News, "Age rating questionnaire now includes social media questions": https://developer.apple.com/news/?id=tlur8uvi
35. Unsplash License: https://unsplash.com/license
36. App Store Connect Help, Platform version information: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
37. App Store Connect Help, Overview of Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
38. App Store Connect Help, Provide test information: https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information
