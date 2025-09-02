import SwiftUI

@main
struct TollFundApp: App {
    let persistenceController = PersistenceController.shared
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(persistenceController)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                print("🟢 应用变为活跃状态")
            case .inactive:
                print("🟡 应用变为非活跃状态")
                persistenceController.save()
            case .background:
                print("🔴 应用进入后台")
                persistenceController.save()
            @unknown default:
                break
            }
        }
    }
}
