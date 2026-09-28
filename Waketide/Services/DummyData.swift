import Foundation

extension AlarmStore {
    func injectDummyData() {
        if self.alarms.isEmpty {
            var alarm1 = WakeAlarm(hour: 6, minute: 30)
            alarm1.label = "Morning Workout"
            alarm1.weekdays = [.monday, .wednesday, .friday]
            alarm1.isEnabled = true
            self.save(alarm1)

            var alarm2 = WakeAlarm(hour: 7, minute: 0)
            alarm2.label = "Breakfast"
            alarm2.weekdays = [.monday, .tuesday, .wednesday, .thursday, .friday]
            alarm2.isEnabled = true
            self.save(alarm2)
        }
        
        if self.timers.isEmpty {
            self.startTimer(label: "Focus Block", duration: 1500)
        }
    }
}
