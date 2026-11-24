# Unsplash on iOS: SDK, API, License and Compliance (Color Shift)

Last checked: 2026-11-24

> This is not legal advice. It summarizes public Unsplash and Apple documents as they read on the date above. If a decision depends on a grey area, email Unsplash (api@unsplash.com) and keep their reply.

---

## TL;DR

- **Official iOS SDK:** `unsplash/unsplash-photopicker-ios` (UnsplashPhotoPicker) is still listed as the official iOS library in the Unsplash API docs [2]. It is **not archived**, but it is **effectively unmaintained**: the last tag is `1.3.0`, and the last commit on the default branch is from 2022-04-05 [5][6][7]. It supports SPM, is UIKit-only (a `UINavigationController` subclass), and needs the Access Key **embedded in the app** [4][7]. It works from SwiftUI through `UIViewControllerRepresentable`.
- **API basics:** You authenticate with an Access Key (`Authorization: Client-ID …` header or `client_id=` query param). The rate limit is **50 req/h in demo** and **1,000 req/h in production** after approval. Only `api.unsplash.com` calls count; `images.unsplash.com` image loads do not [2].
- **API rules (they apply only if you use the API):** hotlink `photo.urls.*` for every use and keep `ixid`, call `download_location` when a photo is "used", credit "Photo by X on Unsplash" with UTM links, don't replicate Unsplash, and keep the keys confidential (use a proxy for client apps) [2][3][8][9][10][11][12].
- **License:** The Unsplash License lets you copy, modify and distribute photos for free, including commercially, with no attribution required [1]. **Bundling 12 photos in a free app looks permitted.** The limits are: no selling unaltered copies, no compiling photos "to replicate a similar or competing service", and people, trademarks and artworks shown in photos are not covered [1][13].
- **Bundle vs hotlink:** The API hotlinking rule binds *API consumers*. Photos you download from unsplash.com and ship under the License are governed by the License, not the API guidelines [1][2][11]. For the 12 curated photos, **bundling is the simplest compliant option. Still show credits with UTM links.** If you later add a "pick more photos" feature, that feature uses the API, so it must hotlink, trigger downloads, attribute, and go through a key-holding proxy. That makes a **hybrid** design.
- **App Store:** The relevant rules are 5.2.1/5.2.2 (you must be permitted to use third-party content and services) and 2.3.9 (rights to images in screenshots). You also need a privacy policy link under 5.1.1(i) [14]. No rule requires a specific attribution format; Unsplash's rules supply that.

---

## 1. Official native iOS SDK: UnsplashPhotoPicker

### Status

| Item | Finding | Source |
|---|---|---|
| Repo | `github.com/unsplash/unsplash-photopicker-ios`, MIT, "© 2018–2022 Unsplash Inc." | [4] |
| Listed as official? | Yes. The API docs' "Libraries & SDKs" section lists iOS → `unsplash/unsplash-photopicker-ios` (alongside PHP, Ruby, JS and Android) | [2] |
| Archived? | `archived: false` | [5] |
| Last tag / release | Tags `1.0.0` … `1.3.0`. No GitHub Releases are published. `1.3.0` is the newest | [4][6] |
| Last commit on default branch | 2022-04-05 ("v1.3.0"). `pushed_at` is 2023-03-03, probably a non-default branch (unverified) | [5][7] |
| Open issues | 8 issues (the GitHub API count includes PRs). Roughly 436 stars | [5] |
| Verdict | **Dormant / unmaintained** for about 4.5 years. It still compiles in principle (Swift 5.3 tools), but there are no Swift 6 / strict-concurrency updates. Not verified against Xcode 26 | inferred |

### Packaging and requirements

- **SPM:** supported. `Package.swift` has `swift-tools-version:5.3`, `platforms: [.iOS(.v11)]`, and a single library product `UnsplashPhotoPicker` [7]. The README says to add it with `.upToNextMajor(from: "1.3.0")` [4].
- Carthage and CocoaPods (`pod 'UnsplashPhotoPicker', '~> 1.3'`) are also documented [4].
- The README states iOS 12.1+, Xcode 12.5+ and Swift 5.3+, and says it is not usable from Objective-C. (The README says 12.1 but Package.swift says 11; the mismatch is harmless for an iOS 17 target.) [4][7]

### API surface (from README and source)

- `UnsplashPhotoPickerConfiguration(accessKey:secretKey:query:allowsMultipleSelection:memoryCapacity:diskCapacity:contentFilterLevel:)` [4].
- `UnsplashPhotoPicker` is a `UINavigationController` subclass that you present modally [4].
- `UnsplashPhotoPickerDelegate` has two methods: `didSelect photos: [UnsplashPhoto]` and `didCancel` [4].
- **Behaviour in the source code (I cloned and grepped it):**
  - API calls send `Authorization: Client-ID <accessKey>` (`UnsplashRequest.swift`) [7].
  - On selection, it **automatically pings `links.download_location?client_id=<accessKey>`** (`UnsplashPhotoPicker.trackDownloads`), which satisfies the download-trigger guideline [7][9].
  - `secretKey` is stored in the config, but I found no use of it beyond that [7].
  - It does **not** build attribution or UTM links for you. You render credits yourself from `UnsplashPhoto.user`.
- **Compliance catch:** the picker calls `api.unsplash.com` directly from the device, so the Access Key ships inside the app binary. The guidelines say keys "must remain confidential" and suggest a proxy for client-side access [3]. The API Terms forbid sharing credentials with third parties [12]. Unsplash publishes this picker itself, so it evidently tolerates an embedded *Access Key* in practice. Still, a key extracted from the binary can be abused and could get your app's access revoked. **Do not embed the Secret Key** (the picker doesn't need it at runtime; pass `""`, unverified that it is never required).

### Using it from SwiftUI

It works with a thin `UIViewControllerRepresentable` wrapper: create the picker in `makeUIViewController`, and have a `Coordinator` conform to `UnsplashPhotoPickerDelegate` and forward selections through a binding or closure. Present it with `.sheet` / `.fullScreenCover`. This is a standard pattern; I have not compiled it against iOS 17/26 SDKs.

**Recommendation:** don't adopt it for v1 (it isn't needed for 12 bundled photos). If you build the "more photos" feature, writing a small SwiftUI search grid over your own proxy is probably cleaner than wrapping a dormant UIKit component that requires a client-side key.

### Community Swift clients (none official, none clearly maintained)

| Package | Notes | Source |
|---|---|---|
| ArnavMotwani/UnsplashSwiftUI | SwiftUI views, SPM, iOS 15. Latest release v2.1.0 (Jan 2022) per search result | [15] |
| jasudev/UnsplashProvider | SwiftUI, SPM, needs an access key in config | [15] |
| modo-studio (carambalabs)/UnsplashKit | Older general client, CocoaPods-focused, last push 2023 | [15] |
| n3v1/unsplash-swift ("Splashy") | Unofficial wrapper, last push around Jul 2024 per search result | [15] |

All of these are stale (unverified beyond search snippets). The API surface you need is tiny (`/search/photos`, `/photos/:id`, `download_location`), so a hand-rolled `URLSession` + `Codable` client of about 100 lines, talking to your proxy, is lower-risk.

---

## 2. Unsplash API

### Auth

- Register as a developer, then create an app under "Your apps" to get an **Access Key** and **Secret Key** [2].
- Public endpoints take `Authorization: Client-ID YOUR_ACCESS_KEY` or `?client_id=YOUR_ACCESS_KEY` [2].
- Endpoints that act on behalf of a user need OAuth bearer tokens. Color Shift doesn't need them.
- Decentralised apps (plugins) are pointed to dynamic client registration or a proxy [2].

### Rate limits

- **Demo:** 50 requests/hour. **Production (after approval):** 1,000 requests/hour [2]. (A third-party search snippet claimed 5,000/h. The official docs say 1,000, so use 1,000.)
- Headers: `X-Ratelimit-Limit` and `X-Ratelimit-Remaining` [2].
- Only JSON requests to `api.unsplash.com` count. **Image requests to `images.unsplash.com` don't count** [2].
- To get more than 1,000/h, contact Unsplash [2].
- With a proxy, the limit applies to the whole app (all users share one key). Cache search results server-side.

### Production approval

- New apps start in demo mode. Apply via "Apply for Production" on the app page [2].
- The application must show that every guideline is met (hotlinking, download trigger, attribution with links, no replication, a non-"Unsplash" app name). Reports say incomplete examples get rejected; plan to supply screenshots of the attribution UI (unverified: the exact form fields weren't fetched) [2][3].

### Required behaviours (API Guidelines [3] plus detail articles)

1. **Hotlinking** [3][11]: use the URLs in `photo.urls` (raw/full/regular/small/thumb, or resized `raw`) for *every* use, not just search results. The stated reason is that views are tracked through the CDN and credited to photographers. Exceptions: remixed derivative images, or companies with their own image infrastructure who contact the API team [11]. Resized URLs must **keep the `ixid` param** [2]. The API Terms §6 make this a contractual requirement, and failing it is called a material breach [12].
2. **Trigger a download** [9]: when the user "uses" a photo (sets it as a background, inserts it into content, and similar), call `photo.links.download_location` (not `links.download`). Authorize the call with `client_id` or a bearer token (otherwise you get a 401), keep every query param including `ixid`, and fire it asynchronously. It only increments a counter; never use it to display the image [9][2].
   - *For Color Shift:* choosing a photo to generate a palette is arguably "using" it. Fire the ping once when a user adds or selects an API photo for palette generation. Don't fire it for merely scrolling search results (my interpretation).
3. **Attribution** [3][10]: credit Unsplash **and** the photographer, and link to the photographer's Unsplash profile. Suggested wording: **"Photo by [Name] on Unsplash"**, with the name linked to the profile and "Unsplash" linked to the homepage. Every link needs `?utm_source=your_app_name&utm_medium=referral` [10]. API Terms §9 restate this [12].
4. **Don't replicate Unsplash** [3][16]: no unofficial clients and no wallpaper apps. Unsplash's test is whether the app still has value without the integration. Good examples are Ghost, Trello and Medium [16]. *Color Shift's value is palette derivation and contrast tooling, so it should pass. A screen that is just "browse Unsplash" would weaken that case.*
5. **Keys confidential** [3][12]: "may require using a proxy if accessing the API client-side" [3]. Credentials must not be shared with third parties [12].
6. **No forced user registration**: users shouldn't need their own Unsplash developer account. Use a proxy that signs requests with your key [3].
7. **Naming**: don't put "Unsplash" in the app name and don't use the Unsplash logo as the app icon [3]. Also don't imply Unsplash sponsorship (API Terms §9) [12].
8. **No selling unaltered photos** via the API, and no abusive request volumes [3].

### Implication for a client-only, no-account app

- **v1 (bundled photos, no API):** no key, no proxy, no API obligations.
- **Later "more photos" feature:** run a tiny stateless proxy (Cloudflare Worker, Vercel Function or similar) that:
  - holds the Access Key and forwards only `/search/photos`, `/photos/:id` and `download_location` pings;
  - caches search responses;
  - rate-limits per IP or App Attest token (optional).

  The app then talks only to your proxy for JSON and loads images directly from `images.unsplash.com`. Image requests don't count against the limit and don't need the key [2].

---

## 3. The Unsplash License: can we bundle?

### What the License grants (paraphrased) [1]

- A worldwide, irrevocable, nonexclusive copyright license to download, copy, modify, distribute, perform and use photos for free, including commercially, with no permission or attribution required. Attribution is "appreciated" but not required [1].

### What it excludes [1][13]

- Selling photos "without significant modification". The Terms §8 extend this to copies that are unaltered, slightly altered, or altered by automatic script (e.g. prints or physical goods) [1][13].
- Compiling photos "to replicate a similar or competing service" [1][13].
- Not covered by the license: **trademarks/logos/brands, recognizable people, and works of art or authorship** depicted in photos. You may need the owner's or person's permission, depending on use [13].
- Sublicensing images obtained via the API requires prior written consent (API Terms §8). This is about the API context [12].

### Applying it to Color Shift's 12 bundled photos

- Shipping 12 photos inside a **free** app binary is "copying and distributing" as part of a larger work. It is not a sale of the photos and not a stock-photo service, so it **appears permitted** [1].
- The "compile to replicate a competing service" clause targets photo-library or wallpaper-style products. Twelve curated photos as input to a palette tool are far from that.
- Risk check: review each of the 12 photos for **recognizable people, prominent logos or brands, and artworks**. Those elements aren't covered by the License [13]. A palette app is low-risk, but swap any photo that shows an identifiable face or a brand-heavy scene. App Store screenshots are a more visible use.
- If you ever charge for the app, it's still not "selling the photo", but this sits nearer the grey zone. Bundled photos should stay a minor, transformed part of the experience (unverified interpretation).

### License vs API Guidelines: why bundling doesn't break the hotlinking rule

| | Unsplash License [1] + Terms [13] | API Terms [12] + API Guidelines [3] |
|---|---|---|
| Applies to | Photos you obtain from Unsplash, e.g. the "Download" button on unsplash.com | Your **use of the API** (`api.unsplash.com`) and the image URLs it returns |
| Hotlinking required? | No. The License grants copy and distribute rights | **Yes.** Use `photo.urls` for all uses and keep `ixid` [2][11][12] |
| Attribution required? | No (appreciated) | **Yes**, with profile link and UTM [10][12] |
| Download trigger required? | No | **Yes** [9][12] |

So the hotlinking obligation comes from the API Terms, which you accept by registering an API app. It covers images *returned by the API*. If you download the 12 photos manually from unsplash.com (no API key involved) and bundle them, the License governs them and hotlinking doesn't apply. The docs frame hotlinking as an API requirement ("we require the image URLs returned by the API to be directly used") [2]. **Caveat:** if the same app also holds an API key and shows those same photos via API URLs, keep the two paths separate and clear: bundled assets are local, API-picked photos are hotlinked.

**Note on the web app as it stands today:** `src/App.tsx` hotlinks raw `images.unsplash.com/photo-…?auto=format&fit=crop&w=1800&q=88` URLs that were **not** obtained through the API. They have no `ixid`, and the credit links go to `unsplash.com/@handle` without UTM. No API key is involved, so the API Terms arguably don't apply. I couldn't confirm whether Unsplash's general Terms say anything about hotlinking CDN URLs outside the API (marked uncertain). Adding UTM params to the credit links is free and goodwill-positive.

---

## 4. Image URL parameters (if hotlinking)

Officially supported imgix params [2]:

| Param | Use |
|---|---|
| `w`, `h` | Width and height in px |
| `crop` | Crop mode (e.g. `entropy`, `faces`, `edges`) |
| `fit` | `max` (no upscaling), `crop`, `clip`, etc. |
| `fm` | Output format (`jpg`, `png`, `webp`, `avif`…) |
| `auto=format` | Let the CDN choose the best format based on the client's `Accept` header |
| `q` | Quality for lossy formats (the API's presets use 75–85) |
| `dpr` | Device pixel ratio multiplier |

- Other imgix params "can be used" but are unsupported and may be removed at any time [2].
- Build sizes from `urls.raw` and **always keep `ixid`** [2].
- Preset widths: `regular` 1080, `small` 400, `thumb` 200, `full` (max, slow) [2].
- `blur_hash` and `color` fields come back on photo objects. They are useful for placeholders and as a quick dominant-color hint [2].

### Suggested sizes for iPhone (iOS 17+)

- The widest current iPhone screens are about 440 pt × 3x = 1320 px (Pro Max class). Typical devices are 390–430 pt @3x, or 1170–1290 px.
- **Full-screen hero:** `w=<viewWidthPt>&dpr=<UIScreen scale>&fit=max&q=80` (e.g. `w=430&dpr=3`) or simply `w=1290&fit=max&q=80`. Cap at about 1400 px.
- **Thumbnails / grid:** `w=200–300&dpr=3&fit=crop&h=…`, or use `urls.small` / `urls.thumb`.
- **Palette extraction:** run it on a downsampled copy (e.g. `w=256&q=70`) instead of the hero image. That makes extraction faster and the result is essentially the same.
- **Format:** iOS decodes JPEG, HEIC, WebP (iOS 14+) and AVIF (iOS 16+). The `Accept` header that `URLSession`/`AsyncImage` sends may not advertise these formats, so `auto=format` may fall back to JPEG. Setting `fm=jpg` (or `fm=webp`) explicitly makes the output predictable. (Unverified: I didn't inspect the actual `Accept` header iOS sends.)

### Caching

- Standard HTTP caching of hotlinked image responses (`URLCache` or an image cache) is normal client behaviour. Nothing found in the docs or Terms forbids it [2][12]. The guidelines' concern is that you *serve from Unsplash URLs* so views register. Each network fetch still registers. Whether views served from a local cache count is unclear (unverified).
- Don't re-host API images on your own server or CDN; that breaks hotlinking [11][12].
- Don't persist API images as app assets for later "offline" use unless Unsplash approves (the guidelines give no offline exception) [11].

---

## 5. Recommendation for Color Shift

### Decision: **bundle now, hybrid later**

**v1 (ship to the App Store): bundle the 12 photos**

1. **Re-acquire the 12 photos properly.** The web app references CDN IDs (`photo-1500964757637-…` etc.), not photo-page slugs. For each one:
   - find the unsplash.com photo page;
   - download it with the site's Download button (this credits a download to the photographer naturally);
   - record the photographer name, `@handle`, photo page URL and photo slug/ID.
   
   Store this in a `photos.json` bundled with the app.
2. **Resize and encode for the bundle:** long edge about 1600–2000 px (portrait crops at about 1320 × 2868 px if you pre-crop), HEIC or high-quality JPEG. That's roughly 300–600 KB each, or about 4–7 MB total. You don't need to keep originals in the binary.
3. **Show credits in-app** (not required by the License, but strongly recommended; it matches the web app and Unsplash norms):
   - On each photo: "Photo by **Name** on **Unsplash**". The name links to `https://unsplash.com/@handle?utm_source=color_shift&utm_medium=referral`, and "Unsplash" links to `https://unsplash.com/?utm_source=color_shift&utm_medium=referral`.
   - Open links with `Link` / `openURL` (Safari) or `SFSafariViewController`.
   - An "About / Credits" screen listing all 12 photographers with links, plus a line such as "Photos from Unsplash, used under the Unsplash License" linked to https://unsplash.com/license.
4. **Screen out photos with license exclusions** (recognizable people, logos/brands, artworks), at least for the ones you use in App Store screenshots [13][14].
5. **No API key in v1.** That avoids the key-secrecy, proxy and production-approval work entirely.

**v2 ("pick more photos"): API + proxy, hotlinked**

1. Register an API app and develop in demo mode (50/h). Apply for production with screenshots of attribution, hotlinking and the download ping [2][3].
2. Run a proxy that holds the Access Key. The app never contains the Secret Key, and ideally not the Access Key either [3][12].
3. Display only `photo.urls.*` (resized from `raw`, keeping `ixid`). Don't save picked photos into the app bundle or your own storage. If you persist a user's picks, persist the **photo ID and URLs**, then re-render from Unsplash [11][12].
4. Fire `download_location` (through the proxy, which adds `client_id`) when the user chooses a photo for a palette [9].
5. Use the same "Photo by X on Unsplash" + UTM credit UI as the bundled photos [10].
6. Keep the feature framed as "find an image to extract a palette from", not as a general Unsplash browser or wallpaper downloader [16]. Don't add "save to Photos" of unaltered images as a headline feature.
7. Don't use "Unsplash" in the app name or icon [3].

### What to do with the 12 existing photo IDs

- The `images.unsplash.com/photo-<timestamp>-<hash>` IDs are CDN filenames. They work for hotlinking without the API, but they are not API photo IDs (slugs like `cnwIyn_BTkc`).
- For v1 bundling: map each to its photo page (search unsplash.com, or use `GET /photos/:id` once you have a key), download, and record metadata as above.
- If you ever switch these 12 to API-hotlinked URLs, fetch each via `GET /photos/:id` so you get URLs that carry `ixid`. Then cache the JSON (IDs, URLs, user) in the app instead of calling the API on every launch (unverified whether long-lived cached `urls` stay valid; they generally do).
- Two IDs (`photo-1787012055240-…`, `photo-1787015163482-…`) have very recent timestamps. Double-check that they still resolve and that the credited photographer is correct.

---

## Compliance checklist

### v1: bundled photos (License-governed)

- [ ] All 12 photos downloaded from unsplash.com photo pages, with photographer name, handle and page URL recorded in `photos.json`.
- [ ] No recognizable people, prominent brands/logos or artworks, or else alternatives chosen (License exclusions) [13].
- [ ] Per-photo credit "Photo by {Name} on Unsplash", visible while the photo is on screen (e.g. a small caption or info sheet).
- [ ] Name links to `https://unsplash.com/@{handle}?utm_source=color_shift&utm_medium=referral`.
- [ ] "Unsplash" links to `https://unsplash.com/?utm_source=color_shift&utm_medium=referral`.
- [ ] Credits/About screen lists all photographers, plus a link to https://unsplash.com/license.
- [ ] App name and icon don't use "Unsplash" or its logo. No implied endorsement [3][12].
- [ ] App Store screenshots use only these bundled photos (rights covered by the License; 2.3.9) [14].
- [ ] Privacy policy URL in App Store Connect and in the app (5.1.1(i)), even if no data is collected [14].

### v2: API photo picker (API Terms-governed)

- [ ] Production approval obtained. Under 1,000 req/h, or a higher limit requested [2].
- [ ] Access Key only on the proxy. Secret Key never in the app [3][12].
- [ ] All displayed API images use `photo.urls.*` with `ixid` kept. No re-hosting [2][11].
- [ ] `download_location` pinged (with `client_id`, all params, async) when the user selects a photo [9].
- [ ] Credit and UTM links shown wherever an API photo is displayed, including thumbnails in context (a grid can link per item) [10].
- [ ] The app's value stands without Unsplash (palette and contrast tools). Not a wallpaper app or browser [16].
- [ ] No selling of unaltered photos (e.g. a paid export of the raw image) [3][13].
- [ ] Content filter: request `content_filter=high` for search results to reduce App Store 1.1 objectionable-content risk (the param name comes from the API docs and the picker's `contentFilterLevel`; I didn't verify the exact query key) [2][4].
- [ ] App Privacy "nutrition label" reviewed. Requests to your proxy and to images.unsplash.com expose IP and search terms to third parties; decide whether to disclose them as "Search History", unlinked (unverified requirement).

---

## 6. App Store Review angle

- **5.2 Intellectual Property:** use only content you created or are licensed to use [14].
  - **5.2.1:** no protected third-party material without permission. Covered by the Unsplash License for bundled photos [14].
  - **5.2.2 Third-Party Sites/Services:** if the app uses or displays content from a third-party service, you must be "specifically permitted" under that service's terms, and must be able to provide authorization on request [14]. For v2 this means following the API Terms and Guidelines. Keep a copy of your production-approval email in case App Review asks.
- **2.3.9:** you must secure rights to all materials in the icon, screenshots and previews. Unsplash photos qualify under the License, minus the exclusions for people, brands and art [13][14].
- **2.3.7 / 5.2.1 metadata:** don't stuff "Unsplash" into keywords or the subtitle as a trademark grab. Mentioning "photos from Unsplash" in the description is factual and probably fine (unverified; no explicit Apple ruling found) [14].
- **4.2 Minimum Functionality / 4.2.2:** the app must be more than a repackaged website, and not primarily an aggregator. Native palette extraction, contrast checking and SwiftUI interactions should clear this. A thin viewer of 12 photos might not [14].
- **4.3 Spam:** avoid being "indistinguishable" from common apps. Palette tools exist, so differentiate [14].
- **1.1 / 1.2:** search results from the API are third-party content. Use the content filter (and the `content_filter` param). Color Shift has no user-to-user sharing, so the full 1.2 UGC obligations (reporting, blocking) probably don't apply (unverified) [14].
- **5.1.1(i) / 5.1.2:** a privacy policy link is required for all apps. If v2 sends search queries to your proxy, disclose that; don't log them unnecessarily [14].
- Apple's guidelines contain **no attribution-format rule for third-party photos**; Unsplash's guidelines are the operative ones [3][10][14].

---

## Open questions / uncertain

1. **Hotlinking CDN URLs without the API** (what the web app does now): I found no explicit rule either way in the License or Terms. Bundling sidesteps the question for iOS.
2. **Embedded Access Key in the official picker** versus "must remain confidential": Unsplash's own SDK embeds it. Is that acceptable in production review? Ask api@unsplash.com if you plan to use the picker without a proxy.
3. **Does choosing a photo for palette extraction count as a "download"?** My reading is yes (comparable to "set as background"). Confirm with Unsplash during the production application.
4. **Persisting picked API photos** (e.g. a user's "My photos" list): storing IDs and URLs seems fine; storing image bytes is not clearly allowed (no offline exception found).
5. **Production application form contents and turnaround:** not fetched; based on secondary reports.
6. **UnsplashPhotoPicker on Xcode 26 / Swift 6:** untested. There may be warnings or errors under strict concurrency.
7. **Community package dates** come from search-result snippets, not verified repo pages.
8. **`auto=format` behaviour with iOS `URLSession`'s Accept header:** not tested.
9. **License text date:** the license page shows no effective date. The Terms may be revised; re-check before release.

---

## Sources

1. Unsplash License: https://unsplash.com/license
2. Unsplash API Documentation (auth, rate limits, production, Libraries & SDKs, hotlinking, dynamic resizing, supported params, ixid, download endpoint): https://unsplash.com/documentation
3. Unsplash API Guidelines: https://help.unsplash.com/en/articles/2511245-unsplash-api-guidelines
4. unsplash/unsplash-photopicker-ios (README): https://github.com/unsplash/unsplash-photopicker-ios
5. GitHub API repo metadata (archived, pushed_at, issues): https://api.github.com/repos/unsplash/unsplash-photopicker-ios
6. GitHub API tags: https://api.github.com/repos/unsplash/unsplash-photopicker-ios/tags
7. Picker source: `Package.swift` (https://raw.githubusercontent.com/unsplash/unsplash-photopicker-ios/master/Package.swift), commit log (https://api.github.com/repos/unsplash/unsplash-photopicker-ios/commits), and a shallow clone grepped for `download_location` / `Client-ID` / `secretKey`
8. Unsplash API Terms (see also [12]): https://unsplash.com/api-terms
9. Guideline: Triggering a Download: https://help.unsplash.com/en/articles/2511258-guideline-triggering-a-download
10. Guideline: Attribution: https://help.unsplash.com/en/articles/2511315-guideline-attribution
11. Guideline: Hotlinking Images: https://help.unsplash.com/en/articles/2511271-guideline-hotlinking-images
12. Unsplash API Terms (§2 credentials, §6 hotlinking/downloads, §8 sublicensing, §9 attribution/endorsement, §19 termination): https://unsplash.com/api-terms
13. Unsplash Terms & Conditions (§5 license exclusions, §8 restrictions): https://unsplash.com/terms
14. Apple App Store Review Guidelines (1.1, 1.2, 2.3.x, 4.2, 4.3, 5.1.1, 5.1.2, 5.2.x): https://developer.apple.com/app-store/review/guidelines/
15. Web search, community Swift Unsplash clients: https://github.com/ArnavMotwani/UnsplashSwiftUI, https://github.com/jasudev/UnsplashProvider, https://github.com/carambalabs/UnsplashKit, https://awesome.ecosyste.ms/projects/github.com%2Fn3v1%2Funsplash-swift
16. Guideline: Replicating Unsplash: https://help.unsplash.com/en/articles/2511257-guideline-replicating-unsplash
