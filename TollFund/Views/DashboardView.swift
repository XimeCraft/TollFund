import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: PersistenceController
    @State private var stats = DashboardStats(totalBalance: 0, totalIncome: 0, totalExpense: 0, dailyTasksCompleted: 0, bigTasksCompleted: 0, expenseThisMonth: 0, incomeThisMonth: 0)
    @State private var categoryExpenses: [CategoryExpense] = []
    
    // 监听数据变化以自动刷新
    @FetchRequest(entity: DailyTask.entity(), sortDescriptors: []) private var dailyTasks: FetchedResults<DailyTask>
    @FetchRequest(entity: BigTask.entity(), sortDescriptors: []) private var bigTasks: FetchedResults<BigTask>
    @FetchRequest(entity: Expense.entity(), sortDescriptors: []) private var expenses: FetchedResults<Expense>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 余额卡片
                    BalanceCard(balance: stats.totalBalance)
                    
                    // 收入支出概览
                    IncomeExpenseOverview(stats: stats)
                    
                    // 任务完成情况
                    TaskCompletionCard(stats: stats)
                    
                    // 消费类别分布
                    if !categoryExpenses.isEmpty {
                        CategoryExpenseChart(categoryExpenses: categoryExpenses)
                    }
                    
                    // 快速操作按钮
                    QuickActionsCard()
                }
                .padding()
            }
            .navigationTitle("奖励账户")
            .onAppear {
                refreshData()
            }
            .refreshable {
                refreshData()
            }
            .onChange(of: dailyTasks.count) { _ in
                refreshData()
            }
            .onChange(of: bigTasks.count) { _ in
                refreshData()
            }
            .onChange(of: expenses.count) { _ in
                refreshData()
            }
            // 监听任务完成状态变化
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
                // 添加延迟确保Core Data保存完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    refreshData()
                }
            }
            // 额外监听任务状态变化
            .onChange(of: dailyTasks.map { "\($0.isCompleted)" }.joined()) { _ in
                refreshData()
            }
            // 监听任务完成状态变化的自定义通知
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskCompletionChanged"))) { _ in
                print("📊 收到任务完成状态变化通知，刷新概述数据")
                refreshData()
            }
        }
    }
    
    private func refreshData() {
        print("🔄 刷新概述数据...")
        stats = dataManager.getDashboardStats()
        categoryExpenses = dataManager.getCategoryExpenses()
        print("💰 当前总收入: ¥\(stats.totalIncome)")
        print("💸 当前总支出: ¥\(stats.totalExpense)")
        print("💰 当前余额: ¥\(stats.totalBalance)")
    }
}

struct BalanceCard: View {
    let balance: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text("账户余额")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("¥\(balance, specifier: "%.2f")")
                .font(.largeTitle)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(balance >= 0 ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(balance >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct IncomeExpenseOverview: View {
    let stats: DashboardStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("收支概览")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 16) {
                // 总收入
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("总收入")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text("¥\(stats.totalIncome, specifier: "%.2f")")
                        .font(.title2)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 总支出
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                        Text("总支出")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text("¥\(stats.totalExpense, specifier: "%.2f")")
                        .font(.title2)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            // 本月收支
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本月收入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(stats.incomeThisMonth, specifier: "%.2f")")
                        .font(.subheadline)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("本月支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(stats.expenseThisMonth, specifier: "%.2f")")
                        .font(.subheadline)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct TaskCompletionCard: View {
    let stats: DashboardStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("任务完成情况")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 16) {
                // 每日任务
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("\(stats.dailyTasksCompleted)")
                        .font(.title2)
                        .font(.system(size: 34, weight: .bold))
                    Text("每日任务")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
                
                // 大任务
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("\(stats.bigTasksCompleted)")
                        .font(.title2)
                        .font(.system(size: 34, weight: .bold))
                    Text("大任务")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct CategoryExpenseChart: View {
    let categoryExpenses: [CategoryExpense]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("消费类别分布")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(categoryExpenses.prefix(5), id: \.category.rawValue) { expense in
                HStack {
                    Image(systemName: expense.category.icon)
                        .foregroundColor(expense.category.color)
                        .frame(width: 20)
                    
                    Text(expense.category.rawValue)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("¥\(expense.amount, specifier: "%.2f")")
                            .font(.subheadline)
                            .font(.system(size: 15, weight: .medium))
                        Text("\(expense.percentage, specifier: "%.1f")%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                // 进度条
                ProgressView(value: expense.percentage / 100)
                    .tint(expense.category.color)
                    .scaleEffect(y: 0.8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct QuickActionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速操作")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "添加任务",
                    icon: "plus.circle",
                    color: .blue
                ) {
                    // TODO: 添加任务操作
                }
                
                QuickActionButton(
                    title: "记录消费",
                    icon: "creditcard",
                    color: .red
                ) {
                    // TODO: 记录消费操作
                }
                
                QuickActionButton(
                    title: "查看统计",
                    icon: "chart.bar",
                    color: .green
                ) {
                    // TODO: 查看统计操作
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(PersistenceController.preview)
    }
}
