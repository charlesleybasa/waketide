import SwiftUI

struct AskAIView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var sentence: String?
    @State private var intents: [ParsedIntent] = []
    @State private var removed: Set<UUID> = []
    @FocusState private var focused: Bool

    private let examples = [
        "Wake me at 6:30 on weekdays",
        "Set alarm M W F at 7am",
        "Set timer until 4PM",
        "Remind me on Tuesday to prepare",
        "20 minute nap timer"
    ]

    private var kept: [ParsedIntent] { intents.filter { !removed.contains($0.id) } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(title: "Just say it") {
                        IconButton(icon: .close, label: "Close") { dismiss() }
                    }
                    if let sentence {
                        conversation(sentence)
                    } else {
                        intro
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { inputBar }
            .onChange(of: sentence) { _, _ in
                withAnimation(.easeOut) { proxy.scrollTo("end", anchor: .bottom) }
            }
        }
        .background(AuroraBackground())
        .onAppear { focused = true }
    }

    // MARK: Pieces

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                AIOrb()
                Text("Tell me what to set, in your own words. I will show you what I understood, and nothing is saved until you confirm.")
                    .font(.ui(16, .medium))
                    .foregroundStyle(WaketideTheme.ink)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }
            SectionEyebrow(text: "Try saying").padding(.top, 4)
            FlowLayout(spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    GlassPill(title: example) {
                        Feedback.tick()
                        submit(example)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func conversation(_ sentence: String) -> some View {
        Text(sentence)
            .font(.ui(16, .medium))
            .lineSpacing(4)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 26, bottomTrailingRadius: 8, topTrailingRadius: 26, style: .continuous)
                    .fill(WaketideTheme.cssGradient(150, [(0x7D7CF5, 0), (0x5B4FE0, 1)]))
                    .outlineShadow(UnevenRoundedRectangle(topLeadingRadius: 26, bottomLeadingRadius: 26, bottomTrailingRadius: 8, topTrailingRadius: 26, style: .continuous),
                                   color: Color(hex: 0x5B52E0).opacity(0.35), radius: 12, y: 10)
            }
            .frame(maxWidth: 300, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("You said: \(sentence)")

        HStack(alignment: .top, spacing: 10) {
            AIOrb()
            Text(reply)
                .font(.ui(16, .medium))
                .lineSpacing(4)
                .foregroundStyle(WaketideTheme.ink)
                .padding(.top, 4)
        }

        if !intents.isEmpty {
            ForEach(Array(intents.enumerated()), id: \.element.id) { index, intent in
                resultCard(intent, alarmIndex: intents[..<index].filter { $0.kind == .alarm || $0.kind == .reminder }.count)
            }
            HStack(spacing: 10) {
                CTAButton(title: addTitle, height: 56) { addAll() }
                    .disabled(kept.isEmpty)
                if let first = kept.first(where: { $0.kind == .alarm }) {
                    GlassPill(title: "Review", height: 56) { review(first) }
                }
            }
            if !suggestions.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { s in
                        GlassPill(title: s) { refine(s) }
                    }
                }
            }
        }
    }

    private var reply: String {
        if intents.isEmpty {
            return "I couldn't find a time or a duration in that. Try “wake me at 6:30 on weekdays” or “10 minute timer”."
        }
        return "Here is what I will set\(dayPhrase). Nothing is saved until you confirm."
    }

    /// " for Monday" when every alarm lands on the same single day.
    private var dayPhrase: String {
        let alarms = intents.filter { $0.kind == .alarm }
        guard !alarms.isEmpty, alarms.allSatisfy({ $0.weekdays.isEmpty }) else { return "" }
        let days = alarms.compactMap { $0.makeAlarm().nextFireDate() }.map { Calendar.current.startOfDay(for: $0) }
        guard let first = days.first, days.allSatisfy({ $0 == first }) else { return "" }
        if Calendar.current.isDateInToday(first) { return " for today" }
        if Calendar.current.isDateInTomorrow(first) { return " for tomorrow" }
        return " for " + first.formatted(.dateTime.weekday(.wide))
    }

    private var addTitle: String {
        switch kept.count {
        case 0: return "Add"
        case 1: return "Add 1"
        case intents.count: return "Add all \(kept.count)"
        default: return "Add \(kept.count)"
        }
    }

    private func resultCard(_ intent: ParsedIntent, alarmIndex: Int) -> some View {
        let isRemoved = removed.contains(intent.id)
        let isTimer = intent.kind == .timer
        let isReminder = intent.kind == .reminder
        let tileInk: Color
        let tileFill: Color
        if isTimer {
            tileInk = WaketideTheme.orangeInk
            tileFill = Color(hex: 0xFFC7A0).opacity(0.6)
        } else if isReminder {
            tileInk = Color(hex: 0xD4A5FF)
            tileFill = Color(hex: 0xC49BF7).opacity(0.35)
        } else {
            tileInk = alarmIndex % 2 == 0 ? WaketideTheme.accentInk : WaketideTheme.mintInk
            tileFill = alarmIndex % 2 == 0 ? Color(hex: 0x9A9BF7).opacity(0.35) : Color(hex: 0x8FE8D8).opacity(0.5)
        }
        return HStack(spacing: 12) {
            IconGlyph(icon: isTimer ? .timer : (isReminder ? .bell : .alarm), size: 22)
                .foregroundStyle(tileInk)
                .frame(width: 40, height: 40)
                .background(tileFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(intent.title)
                    .font(.ui(16, .bold))
                    .foregroundStyle(WaketideTheme.ink)
                    .strikethrough(isRemoved)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(intent.subtitle())
                    .font(.ui(13, .medium))
                    .foregroundStyle(WaketideTheme.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                Feedback.tick()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if isRemoved { removed.remove(intent.id) } else { removed.insert(intent.id) }
                }
            } label: {
                IconGlyph(icon: isRemoved ? .plus : .check, size: 16, stroke: 2.6)
                    .foregroundStyle(isRemoved ? WaketideTheme.inkSoft : WaketideTheme.mintInk)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.7)))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(isRemoved ? "Include \(intent.label)" : "Leave out \(intent.label)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 68)
        .glassCard(24)
        .opacity(isRemoved ? 0.5 : 1)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("", text: $draft, prompt: Text("Ask for an alarm, timer or plan").foregroundStyle(WaketideTheme.eyebrow), axis: .vertical)
                .lineLimit(1...4)
                .font(.ui(15, .medium))
                .foregroundStyle(WaketideTheme.ink)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { submit(draft) }
            IconButton(icon: draft.isEmpty ? .mic : .arrowUp, label: draft.isEmpty ? "Dictate" : "Send", prominent: true) {
                if draft.isEmpty { focused = true } else { submit(draft) }
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .frame(minHeight: 56)
        .glassCard(28)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: Actions

    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            sentence = trimmed
            intents = IntentParser().parse(trimmed)
            removed = []
        }
        draft = ""
        Feedback.tick()
    }

    private func addAll() {
        let result = store.apply(kept)
        Feedback.saved()
        store.banner = result.message
        dismiss()
    }

    private func review(_ intent: ParsedIntent) {
        dismiss()
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            router.edit(intent.makeAlarm())
        }
    }

    // MARK: Follow-up suggestions

    private var suggestions: [String] {
        var out: [String] = []
        if kept.contains(where: { $0.kind == .alarm || $0.kind == .reminder }) { out.append("Wake me 30 min earlier") }
        if kept.contains(where: { ($0.kind == .alarm || $0.kind == .reminder) && !$0.weekdays.isDisjoint(with: [1, 7]) }) { out.append("Silence weekends") }
        return out
    }

    private func refine(_ suggestion: String) {
        Feedback.tick()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            for i in intents.indices where (intents[i].kind == .alarm || intents[i].kind == .reminder) && !removed.contains(intents[i].id) {
                if suggestion == "Silence weekends" {
                    intents[i].weekdays.subtract([1, 7])
                    if intents[i].weekdays.isEmpty { intents[i].weekdays = [2, 3, 4, 5, 6] }
                } else {
                    var total = intents[i].hour * 60 + intents[i].minute - 30
                    if total < 0 {
                        total += 24 * 60
                        if let d = intents[i].date { intents[i].date = Calendar.current.date(byAdding: .day, value: -1, to: d) }
                    }
                    intents[i].hour = total / 60
                    intents[i].minute = total % 60
                }
            }
        }
    }
}

/// The breathing gradient orb that speaks for Waketide (`.orb`).
private struct AIOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var morph = false

    var body: some View {
        Ellipse()
            .fill(RadialGradient(stops: [
                .init(color: .white, location: 0),
                .init(color: Color(hex: 0xB9B7FF), location: 0.3),
                .init(color: Color(hex: 0x6F6CF0), location: 0.7),
                .init(color: Color(hex: 0x8FE8D8), location: 1)
            ], center: UnitPoint(x: 0.3, y: 0.28), startRadius: 0, endRadius: 34))
            .frame(width: morph ? 46 : 44, height: morph ? 42 : 44)
            .rotationEffect(.degrees(morph ? 40 : 0))
            .frame(width: 44, height: 44)
            .shadow(color: Color(hex: 0x5B52E0).opacity(0.45), radius: 9, y: 6)
            .animation(reduceMotion ? nil : .easeInOut(duration: 6).repeatForever(autoreverses: true), value: morph)
            .onAppear { if !reduceMotion { morph = true } }
            .accessibilityHidden(true)
    }
}

/// Wraps pills onto new lines (`.sugg`).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
