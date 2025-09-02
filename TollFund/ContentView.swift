import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var dataManager = PersistenceController.shared
    @AppStorage("hasShownWelcome") private var hasShownWelcome = false
    @State private var showWelcome = false
    
    var body: some View {
        ZStack {
            TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("概览")
                }
            
            DailyTasksView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("每日任务")
                }
            
            BigTasksView()
                .tabItem {
                    Image(systemName: "target")
                    Text("大任务")
                }
            
            ExpensesView()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("消费记录")
                }
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("统计")
                }
            }
            .accentColor(.blue)
            .environmentObject(dataManager)
            
            // 欢迎页面覆盖
            if showWelcome {
                WelcomeView(showWelcome: $showWelcome)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            if !hasShownWelcome {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showWelcome = true
                }
            }
        }
        .onChange(of: showWelcome) { newValue in
            if !newValue {
                hasShownWelcome = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
