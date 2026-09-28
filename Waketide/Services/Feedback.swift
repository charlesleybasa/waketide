import UIKit
import AudioToolbox

/// Small haptic and sound cues. System sounds follow the silent switch, which is what
/// people expect from UI feedback. Real alarms always go through AlarmKit instead.
@MainActor
enum Feedback {
    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
        AudioServicesPlaySystemSound(1104)
    }

    static func toggle(on: Bool) {
        UIImpactFeedbackGenerator(style: on ? .medium : .light).impactOccurred()
        AudioServicesPlaySystemSound(on ? 1057 : 1104)
    }

    static func saved() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1407)
    }

    static func delete() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func press() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
