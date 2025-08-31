import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var dataManager = PersistenceController.shared
    
    var body: some View {
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
