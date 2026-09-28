import SwiftUI
import AppKit

struct ContentView: View {
    var body: some View {
        VStack {
            Button(action: {}) {
                Text("Start Timer")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background {
                        Capsule().fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
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
                                .allowsHitTesting(false)
                            }
                    }
            }
            .frame(width: 300)
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.center()
        window.contentView = NSHostingView(rootView: ContentView())
        window.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
