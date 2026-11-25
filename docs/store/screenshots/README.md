# App Store screenshots (T-052)

Captured by `ColorShiftUITests/StoreScreenshots.swift` with real photos and their derived pairs, status bar set to
9:41 (`xcrun simctl status_bar … override`). PNG, no alpha channel. Spec: `research/app-store-release.md` §6.2 [11].

| Folder | Pixels | App Store Connect slot | Status |
|---|---|---|---|
| `iPhone-18-Pro/` | 1206 × 2622 | iPhone with Dynamic Island, medium display | **Required** |
| `iPhone-18-Pro-Max/` | 1320 × 2868 | Large display | Recommended |
| `iPhone-Duo/` | 1398 × 2034 | iPhone Duo, outer display | Required from April 2027 for iOS 27.1+ SDK builds |

The iPhone Duo inner display (2007 × 2853) isn't captured: the simulator runs UI tests on the outer display.

Order for the listing:
1. `store-1-photo-pair`: a photo and its pair
2. `store-2-controls`: the controls
3. `store-3-contrast`: WCAG contrast after Jump to AAA (7.11:1)
4. `store-4-apca`: APCA reading (90 Lc)
5. `store-5-themes`: theme filter (Urban)

Regenerate: run `StoreScreenshots` on the three simulators with `-resultBundlePath`, then
`xcrun xcresulttool export attachments` into these folders.
