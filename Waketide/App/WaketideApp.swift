import SwiftUI

@main
struct WaketideApp: App {
    @StateObject private var store = AlarmStore()
    @StateObject private var router = Router()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(router)
                .preferredColorScheme(appearance.colorScheme)
                .task { await store.bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refresh() }
                }
        }
    }
}
