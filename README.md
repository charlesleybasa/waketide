# Waketide

An alarm app in SwiftUI with Liquid Glass, AlarmKit alarms and timers, Live Activity on the
Lock Screen and Dynamic Island, and a "just say it" box that turns a sentence into alarms.

Requires Xcode 26 and an iPhone running iOS 26. AlarmKit does not ring in the Simulator, so use a real iPhone.

## Run it on your iPhone

1. Install XcodeGen once: `brew install xcodegen`
2. In this folder run: `xcodegen generate`   (creates Waketide.xcodeproj from project.yml)
3. Open `Waketide.xcodeproj` in Xcode.
4. Select the Waketide project, then for BOTH targets (Waketide and WaketideWidget) open
   Signing & Capabilities, tick "Automatically manage signing" and pick your Team.
   If the bundle id is taken, change `com.waketide.app` in project.yml (widget must stay `<app id>.widget`) and re-run step 2.
5. Plug in your iPhone, choose it as the run destination, press Run.
6. Allow alarms when asked. Then tap the sparkles button and try:
   "Alarm for the AI seminar at 10, lunch at noon, and a 20 minute nap timer".

## Tests

Press Cmd+U in Xcode. The tests cover the alarm scheduling maths and the sentence parser
(WaketideTests). All tests pass on the iOS 26 Simulator.

## What is real and what is not

Working: alarms and timers via AlarmKit, weekly repeats, dated one-off alarms, snooze,
Live Activity and Dynamic Island, saving alarms on the device, the sentence parser (runs on the device,
no network), haptics and system tick sounds, Liquid Glass UI.

Not built yet: custom alarm tones (alarms use the system alarm sound), gradual volume rise,
Apple Intelligence based understanding (the parser is rule based), voice input other than the keyboard
microphone key, iCloud sync.

## Where things live

- Waketide/Core: alarm model and the sentence parser. No UI, easy to test.
- Waketide/Services: AlarmKit (AlarmScheduler.swift), storage and timer logic (AlarmStore.swift), haptics.
- Waketide/UI: the screens.
- WaketideWidget: Lock Screen and Dynamic Island.

AlarmKit is new, so if Xcode flags a signature, the only files to touch are
Waketide/Services/AlarmScheduler.swift and WaketideWidget/WaketideAlarmLiveActivity.swift.
