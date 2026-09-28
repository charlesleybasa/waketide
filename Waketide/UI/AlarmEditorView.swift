import SwiftUI

struct AlarmEditorView: View {
    @EnvironmentObject private var store: AlarmStore
    @Environment(\.dismiss) private var dismiss

    private let original: WakeAlarm
    @State private var draft: WakeAlarm
    @State private var hour24: Int
    @State private var minute: Int
    @State private var hasDate: Bool
    @State private var oneOffDate: Date
    @State private var aiText = ""
    @State private var aiHint: String?
    @State private var savedText: String?
    @State private var twinkle = false
    @FocusState private var aiFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var calendar: Calendar { .current }
    private var isNew: Bool { !store.alarms.contains { $0.id == original.id } }
    private var uses24h: Bool { WakeAlarm.uses24HourClock }

    init(alarm: WakeAlarm) {
        original = alarm
        _draft = State(initialValue: alarm)
        _hour24 = State(initialValue: alarm.hour)
        _minute = State(initialValue: alarm.minute)
        _hasDate = State(initialValue: alarm.date != nil)
        _oneOffDate = State(initialValue: alarm.date ?? Calendar.current.startOfDay(for: Date()))
    }

    private var orderedWeekdays: [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    // 12-hour wheel bindings over the 24-hour state.
    private var hour12: Binding<Int> {
        Binding(get: { hour24 % 12 == 0 ? 12 : hour24 % 12 },
                set: { h in hour24 = (h % 12) + (hour24 >= 12 ? 12 : 0) })
    }
    private var meridiem: Binding<String> {
        Binding(get: { hour24 < 12 ? "AM" : "PM" },
                set: { m in hour24 = (hour24 % 12) + (m == "PM" ? 12 : 0) })
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 10) {
                    ScreenHeader(title: isNew ? "New alarm" : "Edit alarm") {
                        IconButton(icon: .close, label: "Close") { dismiss() }
                    }
                    aiBar
                    timePicker
                    dayPills
                    if draft.weekdays.isEmpty { dateRow }
                    labelRow
                    snoozeRow
                    planRow
                    CTAButton(title: isNew ? "Set alarm" : "Save", icon: .check, action: save)
                        .padding(.top, 6)
                    if !isNew { deleteButton }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            if let text = savedText {
                SavedOverlay(text: text)
                    .transition(.opacity)
            }
        }
        .background(AuroraBackground())
    }

    // MARK: Sections

    private var aiBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconGlyph(icon: .sparkle, size: 22)
                    .foregroundStyle(WaketideTheme.indigo)
                    .scaleEffect(twinkle ? 1.2 : 1)
                    .rotationEffect(.degrees(twinkle ? 12 : 0))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: twinkle)
                    .onAppear { if !reduceMotion { twinkle = true } }
                TextField("", text: $aiText, prompt: Text("Say it: wake me at 6:30 on weekdays").foregroundStyle(WaketideTheme.inkSoft))
                    .font(.ui(15, .medium))
                    .foregroundStyle(WaketideTheme.ink)
                    .focused($aiFocused)
                    .submitLabel(.go)
                    .onSubmit(applySentence)
                IconButton(icon: .mic, label: "Dictate") { aiFocused = true }
                    .accessibilityHint("Opens the keyboard. Tap the microphone key to speak.")
            }
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .frame(minHeight: 56)
            .glassCapsule()
            if let hint = aiHint {
                Text(hint)
                    .font(.ui(13, .medium))
                    .foregroundStyle(WaketideTheme.inkSoft)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var timePicker: some View {
        ZStack {
            WheelLens()
            HStack(spacing: 6) {
                if uses24h {
                    WheelPicker(items: Array(0..<24), selection: $hour24, label: "Hour") { String(format: "%02d", $0) }
                } else {
                    WheelPicker(items: Array(1...12), selection: hour12, label: "Hour") { "\($0)" }
                }
                Text(":")
                    .font(.waketide(38, .heavy, fixed: true))
                    .foregroundStyle(WaketideTheme.ink)
                    .offset(y: -4)
                    .accessibilityHidden(true)
                WheelPicker(items: Array(0..<60), selection: $minute, label: "Minute") { String(format: "%02d", $0) }
                if !uses24h {
                    WheelPicker(items: ["AM", "PM"], selection: meridiem, label: "AM or PM") { $0 }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .glassCard(32)
    }

    private var dayPills: some View {
        HStack(spacing: 0) {
            ForEach(Array(orderedWeekdays.enumerated()), id: \.element) { index, wd in
                let on = draft.weekdays.contains(wd)
                if index > 0 { Spacer(minLength: 4) }
                Button {
                    Feedback.tick()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        if on { draft.weekdays.remove(wd) } else { draft.weekdays.insert(wd) }
                    }
                } label: {
                    Text(calendar.veryShortStandaloneWeekdaySymbols[wd - 1])
                        .font(.ui(14, .bold, fixed: true))
                        .foregroundStyle(on ? Color.white : WaketideTheme.iconInk)
                        .frame(width: 44, height: 44)
                        .background {
                            if on {
                                Circle().fill(WaketideTheme.selectedGradient)
                                    .outlineShadow(Circle(), color: Color(hex: 0x5B52E0).opacity(0.4), radius: 8, y: 6)
                            } else {
                                ControlSurface(shape: Circle(), fill: 0.5)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(calendar.standaloneWeekdaySymbols[wd - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Repeat on")
    }

    private var dateRow: some View {
        GlassRow {
            fieldCaption("Date")
            if hasDate {
                DatePicker("Date", selection: $oneOffDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(WaketideTheme.indigo)
            } else {
                Text("Next time it reaches this time")
                    .font(.ui(14, .medium))
                    .foregroundStyle(WaketideTheme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            WaketideToggle(isOn: $hasDate.animation(.spring), label: "Specific date")
        }
    }

    private var labelRow: some View {
        GlassRow {
            fieldCaption("Label")
            TextField("", text: $draft.label, prompt: Text("Alarm").foregroundStyle(WaketideTheme.inkSoft))
                .font(.ui(16, .medium))
                .foregroundStyle(WaketideTheme.ink)
                .submitLabel(.done)
        }
    }

    private var snoozeRow: some View {
        GlassRow {
            rowTitle("Snooze", icon: .moon)
            Spacer()
            Menu {
                Picker("Snooze", selection: $draft.snoozeMinutes) {
                    ForEach([5, 9, 10, 15], id: \.self) { Text("\($0) min").tag($0) }
                }
            } label: {
                rowValue("\(draft.snoozeMinutes) min")
            }
            .accessibilityLabel("Snooze length, \(draft.snoozeMinutes) minutes")
        }
    }

    private var planRow: some View {
        GlassRow {
            rowTitle("Plan length", icon: .timer)
            Spacer()
            Menu {
                Picker("Plan length", selection: $draft.durationMinutes) {
                    Text("None").tag(0)
                    ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { m in
                        Text(Self.lengthText(m)).tag(m)
                    }
                }
            } label: {
                rowValue(draft.durationMinutes == 0 ? "None" : Self.lengthText(draft.durationMinutes))
            }
            .accessibilityLabel("Plan length, \(draft.durationMinutes == 0 ? "none" : Self.lengthText(draft.durationMinutes))")
        }
    }

    private var deleteButton: some View {
        Button {
            store.delete(original)
            Feedback.delete()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                IconGlyph(icon: .trash, size: 20)
                Text("Delete alarm")
            }
            .font(.ui(16, .bold))
            .foregroundStyle(WaketideTheme.coral)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(ControlSurface(shape: Capsule()))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle(scale: 0.97))
    }

    private func fieldCaption(_ text: String) -> some View {
        Text(text)
            .font(.ui(13, .bold))
            .foregroundStyle(WaketideTheme.eyebrow)
            .frame(width: 54, alignment: .leading)
    }

    private func rowTitle(_ text: String, icon: WTIcon) -> some View {
        HStack(spacing: 8) {
            IconGlyph(icon: icon, size: 20)
                .foregroundStyle(WaketideTheme.iconInk)
            Text(text)
                .font(.ui(16, .medium))
                .foregroundStyle(WaketideTheme.ink)
        }
    }

    private func rowValue(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text).font(.ui(16, .bold))
            IconGlyph(icon: .chevronRight, size: 14, stroke: 2.2)
        }
        .foregroundStyle(WaketideTheme.accentInk)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    static func lengthText(_ m: Int) -> String {
        m < 60 ? "\(m) min" : (m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min")
    }

    // MARK: Actions

    private func applySentence() {
        let intents = IntentParser().parse(aiText)
        guard let first = intents.first(where: { $0.kind == .alarm }) else {
            aiHint = "I couldn't find a time. Try “wake me at 6:30 on weekdays”."
            Feedback.warning()
            return
        }
        withAnimation(.spring) {
            draft.label = first.label
            draft.weekdays = first.weekdays
            if let d = first.date, first.weekdays.isEmpty {
                hasDate = true
                oneOffDate = d
            } else {
                hasDate = false
            }
            hour24 = first.hour
            minute = first.minute
        }
        aiHint = intents.count > 1 ? "Filled in the first alarm. Use Ask Waketide to add several at once." : "Filled in from your sentence. Check it and set the alarm."
        aiFocused = false
        Feedback.saved()
    }

    private func save() {
        var alarm = draft
        alarm.hour = hour24
        alarm.minute = minute
        let trimmed = alarm.label.trimmingCharacters(in: .whitespacesAndNewlines)
        alarm.label = trimmed.isEmpty ? "Alarm" : trimmed
        alarm.date = (alarm.weekdays.isEmpty && hasDate) ? calendar.startOfDay(for: oneOffDate) : nil
        alarm.isEnabled = true
        store.save(alarm)
        Feedback.saved()

        var message = "Saved"
        if let fire = store.alarms.first(where: { $0.id == alarm.id })?.nextFireDate() ?? alarm.nextFireDate() {
            message = "Rings in \(DateText.countdown(fire.timeIntervalSinceNow))"
        }
        withAnimation(.easeOut(duration: 0.25)) { savedText = message }
        Task {
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            dismiss()
        }
    }
}

/// Confirmation: a droplet lands, ripples spread, and the ring time whispers in.
struct SavedOverlay: View {
    let text: String
    @State private var go = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color(hex: 0x5B52E0).opacity(0.5), lineWidth: 2)
                            .frame(width: 90, height: 90)
                            .scaleEffect(go ? 2.6 : 0.6)
                            .opacity(go ? 0 : 0.9)
                            .animation(.easeOut(duration: 1.2).delay(Double(i) * 0.18), value: go)
                    }
                    IconGlyph(icon: .check, size: 38)
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 92)
                        .background(Circle().fill(WaketideTheme.brandGradient)
                            .outlineShadow(Circle(), color: Color(hex: 0x5B52E0).opacity(0.5), radius: 14, y: 12))
                        .scaleEffect(go ? 1 : 0.2)
                        .animation(.spring(response: 0.5, dampingFraction: 0.55), value: go)
                }
                Text(text)
                    .font(.waketide(20))
                    .foregroundStyle(WaketideTheme.ink)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .glassCapsule()
                    .opacity(go ? 1 : 0)
                    .offset(y: go ? 0 : 12)
                    .animation(.easeOut(duration: 0.5).delay(0.25), value: go)
            }
        }
        .onAppear { go = true }
        .accessibilityElement(children: .combine)
    }
}
