import SwiftUI

@main
struct TollFundApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(persistenceController)
        }
    }
}

struct AppRootView: View {
    @EnvironmentObject var persistenceController: PersistenceController
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        LaunchScreenView()
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
