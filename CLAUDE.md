# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Environment

This repo uses a Linux devcontainer for editing. **Xcode on macOS is required to build and run** — the container has no iOS SDK or simulator.

To open in Xcode from the Mac terminal:
```sh
open -a Xcode ShootChart.xcodeproj
```

Build from the Mac terminal (not inside the container):
```sh
xcodebuild -scheme ShootChart -destination 'platform=iPadOS Simulator,name=iPad (10th generation)' build
```

There are no linters, tests, or package managers configured.

## Project Overview

iPad-only mini-basketball (ミニバス/elementary school) shot chart app. Closed app, no App Store release. Landscape orientation only. All data stored on-device via SwiftData.

- **iOS 17.0+**, **Xcode 15+** required (SwiftData dependency)
- `TARGETED_DEVICE_FAMILY = 2` (iPad only)
- Orientation locked to landscape in `Info.plist` (`UISupportedInterfaceOrientations~ipad`)

## Architecture

Three SwiftData models, no relationships between Player and Game/Shot by design:

- **Player** — global roster, imported from CSV. Independent of any game.
- **Game** — owns `[Shot]` via `@Relationship(deleteRule: .cascade)`.
- **Shot** — belongs to a Game. Denormalizes player info (`playerNumber`, `playerName`) so shots survive player edits/deletes. `quarter` is an `Int` (1–4 = Q1–Q4, 5 = OT1, 6 = OT2). `shotType` is a `String` (`"field"` or `"freeThrow"`, default `"field"`). Shot position stored as normalized coordinates `x/y ∈ [0.0, 1.0]` relative to the full-court rectangle.

The `Quarter` and `ShotType` enums (both in `Shot.swift`) are the single source of truth for quarter labels and shot type values across the app.

**Schema change rule**: always assign a stored default to new non-optional `@Model` properties (e.g. `var x: T = defaultValue`). Without it, SwiftData deletes the existing store on launch.

## Key Component: CourtView

`Components/CourtView.swift` handles all court rendering and tap interaction.

- Displays `Assets.xcassets/basketball-court.imageset/basketball-court.svg` (SVG viewBox 942×540).
- Private `Court` enum holds boundary constants as fractions of SVG dimensions: `left=40/942, right=906/942, top=39/540, bottom=504/540`.
- `imageRect(in:)` letterboxes the SVG at 942:540 aspect. `courtRect(in:)` is the sub-rect used for shot placement and tap detection.
- Tap handling uses `DragGesture(minimumDistance: 0)`. A tap within **22pt** of an existing marker calls `onShotTap`; a tap elsewhere calls `onTap` with normalized court coordinates.
- Shot markers: ○/× (32pt, line width 4pt) with player number in center. Field goal: green/red. Free throw: blue/orange. Selected shot: yellow at 40pt.

## ShotChartView Layout

`Views/ShotChartView.swift` — the main recording screen:
- Left area: `CourtView` (fills remaining width) + player display filter bar (52pt, below court — shows players who have shots; hidden when none)
- Right 280pt: control panel — status bar / shot type (2P·FT, 40pt) / made·missed (72pt) / quarter section (記録Q + 表示Q combined) / player list / action buttons
- Player selection persists across shots; tapping a shot marker selects it (toggle) and enables the delete button.
- `init(game:initialFilterPlayerId:)` pre-selects a player display filter; used when navigating from `SummaryView`.

## CSV Import

`Utilities/CSVImporter.swift` exports two free functions used from `GameEditView`:
- `parseCSV(from: URL) throws -> [ParsedPlayer]` — reads UTF-8, skips header row, requires `number` and `name` columns, `grade` optional.
- `upsertPlayers(_ parsed: [ParsedPlayer], context: ModelContext)` — overwrites existing player with same `number`.

Import is triggered from the **メンバー** section inside `GameEditView` (not a separate screen).
