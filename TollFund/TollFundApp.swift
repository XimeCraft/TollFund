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
    @State private var showLaunchScreen = true
    
    var body: some View {
        Group {
            if showLaunchScreen {
                LaunchScreen()
            } else {
                ContentView()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showLaunchScreen = false
                }
            }
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

struct LaunchScreen: View {
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 封面图片
                if let image = UIImage(named: "cover-image") {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 300, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                } else {
                    // 备用图标
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                }
                
                // 应用标题
                VStack(spacing: 8) {
                    Text("TollFund")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("智能挑战奖励系统")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // 版本信息
                Text("v1.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .scaleEffect(size)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 1.2)) {
                    self.size = 0.9
                    self.opacity = 1.0
                }
            }
        }
    }
}
