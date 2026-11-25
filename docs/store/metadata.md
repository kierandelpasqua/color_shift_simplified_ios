# App Store metadata (draft, T-051)

Draft listing for **KDP Color**, version 1.0. Paste each field into App Store Connect when you create the record
(H-08). Limits are from App Store Connect Help as summarized in `research/app-store-release.md` §6.1 (sources [10],
[36] there). Each field below sits in a fenced block so `docs/store/check-metadata.py` can measure it; run
`python3 docs/store/check-metadata.py` after editing.

## Text fields

| Field | Apple's limit | Source |
|---|---|---|
| App Name | 2–30 characters, unique on the store | [10] |
| Subtitle | ≤ 30 characters | [10] |
| Promotional Text | ≤ 170 characters (editable without a new version) | [36] |
| Description | ≤ 4,000 characters, plain text | [36] |
| Keywords | ≤ 100 bytes, comma-separated, each keyword longer than 2 characters | [36] |
| Support URL | Must include the protocol and lead to real contact info | [36] |
| Copyright | "Year Owner" (© added automatically) | [36] |
| App Review Notes | ≤ 4,000 bytes | [36] |

### App Name
```name
KDP Color
```

### Subtitle
```subtitle
Photo color pairs and contrast
```

### Promotional Text
```promo
Turn a photo into a readable color pair. Tune it with HSL sliders, check WCAG and APCA contrast, and share the pair as a link or a Markdown file.
```

### Description
```description
KDP Color turns photographs into foreground and background color pairs, and checks whether text in those colors is easy to read.

Pick a photo and the app finds its most vivid color, then pairs it with a light or dark partner of a related hue. A large "Aa" specimen shows the pair right away, so you can judge it by eye as well as by the numbers.

TUNE THE PAIR
• Hue, saturation and lightness sliders for both colors
• Tap a color to open the system color picker, or swap foreground and background
• Filter the twelve built-in photos by theme: Outdoors, Urban, People, Animals, Abstract and Objects

CHECK CONTRAST
• WCAG 2 contrast ratio with a meter and AA / AAA marks
• APCA lightness contrast (Lc) for a second opinion
• One tap tunes the foreground's lightness until the pair passes AA or AAA, and tells you when a hue can't get there

SHARE
• Copy a link that reopens the exact pair and photo
• Export a Markdown file with the colors, the contrast ratio and the photo credit

BUILT FOR EVERYONE
• Full VoiceOver support, including adjustable sliders and spoken contrast results
• Dynamic Type up to the largest accessibility sizes
• Respects Reduce Motion, Increase Contrast, Bold Text and Differentiate Without Color
• Haptic feedback you can turn off

PRIVATE BY DESIGN
KDP Color collects no data. There are no accounts, ads or analytics, and the app works fully offline.

Photos by Unsplash photographers, credited in the app.
```

### Keywords
```keywords
color,palette,contrast,wcag,apca,accessibility,pairing,hex,hsl,swatch,typography,design,a11y
```

### Support URL
```support
https://github.com/kierandelpasqua/color_shift_simplified_ios/issues
```

### Marketing URL
None for v1 (optional). Use the web app's URL once it's published (H-03).

### Privacy Policy URL
```privacy
https://kierandelpasqua.github.io/color_shift_simplified_ios/privacy-policy.html
```
Live once GitHub Pages is on (H-07). The same URL is linked in the app's About sheet (Guideline 5.1.1(i)).

### Copyright
```copyright
2026 Kieran Del Pasqua
```
Use your legal name exactly as enrolled (H-02); with an Individual account it's also shown as the seller.

### App Review Notes
```review
KDP Color is a native SwiftUI color tool. It derives a foreground/background color pair from one of 12 bundled photos and checks its WCAG and APCA contrast. There is no login, no network access and no web view; everything works offline.

How to try it:
1. Tap the photo to see the next one; swipe to go back.
2. Tap the round slider button (bottom left) to open the controls: theme filters, color fields (tap to open the system color picker), HSL sliders, contrast meter and the "Jump to AA/AAA" button.
3. Copy link (top right of the controls) copies a share link; the download button exports a Markdown file through the share sheet.
4. Tap "Color Shift" at the top of the controls for the About sheet: photo credits, font licenses, the privacy policy link and the Haptics setting.

Photos: 12 images bundled under the Unsplash License (https://unsplash.com/license), each credited to its photographer in the app with a link to their Unsplash profile.
Fonts: Manrope and DM Mono, SIL Open Font License 1.1; license texts are in the About sheet.
```

## Category

- **Primary:** Graphics & Design
- **Secondary:** Utilities

## Age rating questionnaire

Answer **None / No** to every question; expected rating **4+** (research §5.1).

| Group | Answer | Why |
|---|---|---|
| In-App Controls (parental controls, age assurance) | No | Not applicable |
| Capabilities: unrestricted web access | No | No web view; credit and privacy links open Safari |
| Capabilities: user-generated content, social media, messaging | No | None |
| Capabilities: shared location (new descriptor, required by Jan 12, 2027) | No | No location use |
| Capabilities: advertising | No | No ads |
| Mature themes, including dating and relationships (new descriptor) | None | None |
| Medical or wellness | None | None |
| Sexuality or nudity | None | Photos reviewed (docs/photo-sources.md) |
| Violence | None | None |
| Chance-based activities | None | None |

## Content rights

**Yes, the app contains third-party content, and I have the rights to use it.** The 12 photos are bundled under the
Unsplash License (free for commercial and non-commercial use; no permission needed). Two photos show recognizable
people (#4, #5); the owner reviewed and kept them, as on the web app (docs/photo-sources.md). Fonts are SIL OFL 1.1.

## App Privacy ("nutrition label")

App Privacy → Get Started → **"No, we do not collect data from this app"** → Save → Publish. True because the app has
no analytics, crash SDKs or network calls; the only stored value is the Haptics setting, on device
(`PrivacyInfo.xcprivacy`: UserDefaults `CA92.1`). Export compliance is answered in Info.plist
(`ITSAppUsesNonExemptEncryption = NO`).

## Accessibility Nutrition Labels (voluntary)

Claim a feature only if every common task works with it (Guideline 2.3; research §6.3).

| Feature | Claim | Evidence |
|---|---|---|
| VoiceOver | Yes | T-042: every control labelled, sliders adjustable, photo actions, spoken Jump result; audit passes |
| Voice Control | **Not yet** | Not tested; check by hand on a device before claiming |
| Larger Text | Yes | T-040: Dynamic Type through AX5; layout adapts (docs/screens/t040) |
| Dark Interface | Yes | The app is dark only |
| Differentiate Without Color Alone | Yes | ✓/✗ marks on AA/AAA; text labels on every state |
| Sufficient Contrast | Yes | UI text ≥ 4.5:1 (TokenContrastTests); Increase Contrast supported (T-043) |
| Reduced Motion | Yes | Drawer eases instead of springing, photo reveal is a fade, chip wave is off (Motion.swift) |
| Captions | Not applicable | No audio or video |
| Audio Descriptions | Not applicable | No video |
