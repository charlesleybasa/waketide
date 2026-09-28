# Waketide (Claude Code project notes)

SwiftUI alarm app for iOS 26: Liquid Glass UI, AlarmKit alarms and timers, Live Activity
and Dynamic Island, and a "just say it" box that turns a sentence into alarms.
Tabs: Your Week, Schedule, Plans, Timer, plus a "+" editor and an AI sentence sheet.

## Status: builds and passes tests (Xcode 26.6, iOS 26 Simulator)

The app and widget build cleanly and all unit tests pass. It has run in the iPhone 17 Pro
Simulator in light and dark mode. Not yet run on a physical iPhone: check that alarms ring there.

1. `brew install xcodegen` (once), then `xcodegen generate` to create `Waketide.xcodeproj`.
2. Set your Team ID in `project.yml` (`DEVELOPMENT_TEAM`) or in Xcode for BOTH the app and widget targets.
3. Build: `xcodebuild -project Waketide.xcodeproj -scheme Waketide -destination 'generic/platform=iOS' build`
4. Test: `xcodebuild test` with a simulator destination (covers `WakeAlarm` schedule maths and `IntentParser`).
5. Run on a physical iPhone on iOS 26 to hear alarms. AlarmKit does not ring in the Simulator.

## UI follows the design canvas

The UI is a SwiftUI build of the design canvas (link below): match it rather than system defaults.

- Fonts: Bricolage Grotesque (display) and DM Sans (text), static cuts in `Waketide/Fonts` (OFL), registered with
  `UIAppFonts` in both targets. Use `Font.waketide(size, weight)` and `Font.ui(size, weight)`, never `.system`.
- Icons: the canvas's 24×24 stroke icons, drawn by `IconGlyph(icon:)` from `Waketide/Shared/WaketideIcons.swift`.
  Add new ones there from SVG path data rather than using SF Symbols.
- Components (`Waketide/UI/Theme.swift`): `AuroraBackground` (blurred blobs), `.glassCard(r)` / `.glassCapsule()`,
  `IconButton`, `GlassPill`, `CTAButton`, `WaketideToggle`, `ScreenHeader`, `GlassRow`, `WheelPicker` + `WheelLens`.
- Tabs: `TabView` with the system bar hidden; `WaketideTabBar` in `RootView.swift` draws the glass bar and plus button.

## Layout

- `Waketide/Core`: `WakeAlarm.swift` (model, next fire date, text helpers) and `IntentParser.swift` (regex sentence parser). No UI, no AlarmKit. Keep it pure so it stays testable.
- `Waketide/Services`: `AlarmScheduler.swift` (all AlarmKit calls), `AlarmStore.swift` (state, persistence in UserDefaults key `waketide.alarms.v1`, timer, undo), `Feedback.swift` (haptics and system sounds).
- `Waketide/Shared`: compiled into BOTH the app and the widget: `WaketideMetadata.swift` (metadata, colour tokens,
  gradients, fonts), `WaketideIcons.swift`, `WaketideIntents.swift` (Live Activity Stop/Snooze/Pause/Resume).
- `Waketide/UI`: one file per screen, plus `Theme.swift` (aurora background, glass helpers) and `RootView.swift` (tabs, sheets, ringing cover, toasts).
- `WaketideWidget`: Live Activity and Dynamic Island.
- `WaketideTests`: XCTest. Dates are pinned to UTC with now = Mon 2026-09-21 03:00 (`TestSupport.swift`).
- `project.yml`: XcodeGen spec. It is the source of truth. Do not hand-edit `Waketide.xcodeproj` (it is git-ignored and generated); after adding or moving files, re-run `xcodegen generate`.

## Conventions and decisions

- Weekdays are Calendar weekday numbers (Sunday = 1 ... Saturday = 7), stored as `Set<Int>`. An empty set means one-off.
- AlarmKit owns the actual ringing screen. `RingingView` is only the in-app screen when the app is open.
- Colours: every `WaketideTheme` token is adaptive (day/night values) in `Waketide/Shared/WaketideMetadata.swift`.
  Use tokens, not literal `.white`/`.black`. AlarmKit gets the fixed `brandIndigo`. `AuroraBackground` picks
  day, dusk (dark mode) or night (ringing only). Appearance override: `AppAppearance`, key `waketide.appearance`.
- Clock: `WakeAlarm.uses24HourClock` follows the locale; tests pin it to 12-hour in `setUp`.
- "Once" alarms get pinned to the day they ring (`pinningOneOffDate`) so a relaunch never reschedules them.
- Only one timer at a time. It is saved in UserDefaults key `waketide.timer.v1` and kept in sync with AlarmKit state. Alarms use the system alarm sound (no custom tones, no volume ramp yet).
- The AI box is deterministic and on-device: it splits on commas, "and", "then", and always shows a confirm step before anything is set. It classifies intent into alarm, timer, or reminder. It understands "timer until 4PM", recurring days like "M W F only", and "remind me on Tuesday to prepare". Reminders are stored as alarms with a bell icon in the AI view.
- Bundle ids: app `com.waketide.app`, widget `com.waketide.app.widget` (must stay prefixed by the app id), tests `com.waketide.app.tests`.

## Behaviour references (not part of the build)

- `Reference/web-preview.html`: a single-file web version of the whole app. It mirrors the Swift model and parser (a JS port of `IntentParser`), so use it to check intended behaviour and animation feel. Keep parser changes in sync with `Waketide/Core/IntentParser.swift` and `WaketideTests/IntentParserTests.swift`.
- Design canvas (screens, icon, UX and motion notes): https://claude.ai/artifact/NmmoQBE9kRNyoW6K8ACU5w
- Live web preview: https://claude.ai/artifact/XnVfq2d2et8gMpkiZZiSg4

## Not built yet

Custom alarm tones, gradual volume rise, Apple Intelligence parsing, iCloud sync, more than one running timer,
labels containing "and" (the parser splits on it).
