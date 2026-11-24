# Color Shift — iOS

Native SwiftUI (iPhone, iOS 26+) port of the Color Shift web app: a photo-driven color pairing tool
that derives a foreground/background pair from each photo and scores it with WCAG and APCA contrast.

| File | What it is |
|---|---|
| [`prd.md`](prd.md) | Product requirements as an ordered task list, built to be worked through one task per loop |
| [`ios.md`](ios.md) | Port plan: decisions, architecture, phases, risks |
| [`PROJECT_MAP.md`](PROJECT_MAP.md) | Snapshot of the web app's full reference (behavior, color algorithms, test vectors) |
| [`research/`](research/README.md) | Sourced research: SwiftUI, Liquid Glass, Unsplash, color/APCA, accessibility, sharing, App Store |

Status: Phase 0 (setup) in progress. The Xcode project is generated with XcodeGen (`xcodegen generate`); see [`CLAUDE.md`](CLAUDE.md) for commands and [`prd.md`](prd.md) §6 for progress.
