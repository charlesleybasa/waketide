import SwiftUI

struct TestView: View {
    var body: some View {
        Button(action: {}) {
            Text("Start")
        }
        .frame(width: 200, height: 60)
        .background {
            Capsule().fill(Color.blue)
                .overlay {
                    TimelineView(.animation) { context in
                        GeometryReader { geo in
                            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6
                            let p = min(1, t / 0.55)
                            let x = -80 + p * (geo.size.width * 1.1 + 80)
                            LinearGradient(colors: [.clear, Color.white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: 60)
                                .rotationEffect(.degrees(10))
                                .offset(x: x)
                        }
                    }
                    .clipShape(Capsule())
                }
        }
    }
}
