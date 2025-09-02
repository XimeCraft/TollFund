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
            .accentColor(.green)
            .environmentObject(dataManager)
            
            // 欢迎页面覆盖
            if showWelcome {
                WelcomeScreen(showWelcome: $showWelcome)
                    .transition(AnyTransition.opacity)
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

struct WelcomeScreen: View {
    @Binding var showWelcome: Bool
    
    var body: some View {
        ZStack {
            // 绿色渐变背景
            LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.9), Color.mint.opacity(0.8), Color.teal.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // 主图标和装饰
                VStack(spacing: 20) {
                    // 主图标
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 140, height: 140)
                        
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                    }
                    
                    // 装饰性小图标
                    HStack(spacing: 30) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Image(systemName: "trophy.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // 欢迎内容
                VStack(spacing: 20) {
                    Text("欢迎来到 TollFund")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("智能挑战奖励系统")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 12) {
                        Text("🎯 设定每日任务和长期挑战")
                        Text("💰 完成任务获得虚拟奖励")
                        Text("📊 追踪进度和成就统计")
                        Text("🏆 让成长变得更有动力")
                    }
                    .font(.body)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // 开始按钮
                VStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showWelcome = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("开始我的奖励之旅")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal, 30)
                    
                    Button(action: {
                        showWelcome = false
                    }) {
                        Text("跳过介绍")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .underline()
                    }
                }
                
                Spacer().frame(height: 40)
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
