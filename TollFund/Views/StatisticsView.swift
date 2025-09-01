import SwiftUI
import CoreData

struct StatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: PersistenceController
    
    @State private var stats = DashboardStats(totalBalance: 0, totalIncome: 0, totalExpense: 0, dailyTasksCompleted: 0, bigTasksCompleted: 0, expenseThisMonth: 0, incomeThisMonth: 0)
    @State private var categoryExpenses: [CategoryExpense] = []
    @State private var monthlyData: [MonthlyData] = []
    
    // 监听数据变化以自动刷新
    @FetchRequest(entity: DailyTask.entity(), sortDescriptors: []) private var dailyTasks: FetchedResults<DailyTask>
    @FetchRequest(entity: BigTask.entity(), sortDescriptors: []) private var bigTasks: FetchedResults<BigTask>
    @FetchRequest(entity: Expense.entity(), sortDescriptors: []) private var expenses: FetchedResults<Expense>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 收支对比图表
                    IncomeExpenseChart(stats: stats)
                    
                    // 消费类别饼图
                    if !categoryExpenses.isEmpty {
                        CategoryPieChart(categoryExpenses: categoryExpenses)
                    }
                    
                    // 月度趋势图
                    if !monthlyData.isEmpty {
                        MonthlyTrendChart(monthlyData: monthlyData)
                    }
                    
                    // 详细统计信息
                    DetailedStatsView(stats: stats)
                    
                    // 任务完成率
                    TaskCompletionStats()
                }
                .padding()
            }
            .navigationTitle("统计分析")
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
                print("📈 收到任务完成状态变化通知，刷新统计数据")
                refreshData()
            }
        }
    }
    
    private func refreshData() {
        stats = dataManager.getDashboardStats()
        categoryExpenses = dataManager.getCategoryExpenses()
        monthlyData = generateMonthlyData()
    }
    
    private func generateMonthlyData() -> [MonthlyData] {
        let calendar = Calendar.current
        let now = Date()
        var data: [MonthlyData] = []
        
        // 获取最近6个月的数据
        for i in 0..<6 {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
                continue
            }
            
            let monthName = DateFormatter().monthSymbols[calendar.component(.month, from: monthStart) - 1]
            
            // 计算该月收入
            let monthlyIncome = calculateMonthlyIncome(start: monthInterval.start, end: monthInterval.end)
            
            // 计算该月支出
            let monthlyExpense = calculateMonthlyExpense(start: monthInterval.start, end: monthInterval.end)
            
            data.append(MonthlyData(month: monthName, income: monthlyIncome, expense: monthlyExpense))
        }
        
        return data.reversed()
    }
    
    private func calculateMonthlyIncome(start: Date, end: Date) -> Double {
        // 计算每日任务收入
        let dailyTaskFetch: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
        dailyTaskFetch.predicate = NSPredicate(format: "isCompleted == YES AND completedDate >= %@ AND completedDate < %@", start as NSDate, end as NSDate)
        
        let dailyTasks = (try? viewContext.fetch(dailyTaskFetch)) ?? []
        let dailyIncome = dailyTasks.reduce(0) { $0 + $1.rewardAmount }
        
        // 计算大任务收入
        let bigTaskFetch: NSFetchRequest<BigTask> = BigTask.fetchRequest()
        bigTaskFetch.predicate = NSPredicate(format: "status == %@ AND completedDate >= %@ AND completedDate < %@", BigTaskStatus.completed.rawValue, start as NSDate, end as NSDate)
        
        let bigTasks = (try? viewContext.fetch(bigTaskFetch)) ?? []
        let bigTaskIncome = bigTasks.reduce(0) { $0 + $1.rewardAmount }
        
        return dailyIncome + bigTaskIncome
    }
    
    private func calculateMonthlyExpense(start: Date, end: Date) -> Double {
        let expenseFetch: NSFetchRequest<Expense> = Expense.fetchRequest()
        expenseFetch.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        
        let expenses = (try? viewContext.fetch(expenseFetch)) ?? []
        return expenses.reduce(0) { $0 + $1.amount }
    }
}

struct IncomeExpenseChart: View {
    let stats: DashboardStats
    
    var data: [(String, Double, Color)] {
        [
            ("收入", stats.totalIncome, .green),
            ("支出", stats.totalExpense, .red)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("收支对比")
                .font(.headline)
                .padding(.bottom, 4)
            
            // 简化的图表显示
            HStack(spacing: 20) {
                VStack {
                    Rectangle()
                        .fill(.green)
                        .frame(width: 40, height: stats.totalIncome > 0 ? max(10, min(120, CGFloat(stats.totalIncome / max(stats.totalIncome, stats.totalExpense) * 120))) : 10)
                    Text("收入")
                        .font(.caption)
                    Text("¥\(String(format: "%.0f", stats.totalIncome))")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                VStack {
                    Rectangle()
                        .fill(.red)
                        .frame(width: 40, height: stats.totalExpense > 0 ? max(10, min(120, CGFloat(stats.totalExpense / max(stats.totalIncome, stats.totalExpense) * 120))) : 10)
                    Text("支出")
                        .font(.caption)
                    Text("¥\(String(format: "%.0f", stats.totalExpense))")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .frame(height: 160)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct CategoryPieChart: View {
    let categoryExpenses: [CategoryExpense]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("消费类别分布")
                .font(.headline)
                .padding(.bottom, 4)
            
            // 简化的类别显示
            VStack(spacing: 8) {
                ForEach(categoryExpenses.prefix(5), id: \.category.rawValue) { expense in
                    HStack {
                        Circle()
                            .fill(expense.category.color)
                            .frame(width: 12, height: 12)
                        
                        Text(expense.category.rawValue)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", expense.percentage))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .frame(height: 200)
            
            // 图例
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(categoryExpenses.prefix(6), id: \.category.rawValue) { expense in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(expense.category.color)
                            .frame(width: 8, height: 8)
                        
                        Text(expense.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

struct MonthlyTrendChart: View {
    let monthlyData: [MonthlyData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("月度收支趋势")
                .font(.headline)
                .padding(.bottom, 4)
            
            // 简化的月度趋势
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(monthlyData, id: \.month) { data in
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Rectangle()
                                    .fill(.green)
                                    .frame(width: 15, height: max(10, min(80, CGFloat(data.income / 100 * 50))))

                                Rectangle()
                                    .fill(.red)
                                    .frame(width: 15, height: max(10, min(80, CGFloat(data.expense / 100 * 50))))
                            }

                            Text(data.month)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct DetailedStatsView: View {
    let stats: DashboardStats
    
    var averageDailyTaskReward: Double {
        stats.dailyTasksCompleted > 0 ? stats.totalIncome / Double(stats.dailyTasksCompleted) : 0
    }
    
    var averageBigTaskReward: Double {
        stats.bigTasksCompleted > 0 ? stats.totalIncome / Double(stats.bigTasksCompleted) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("详细统计")
                .font(.headline)
                .padding(.bottom, 4)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "总余额",
                    value: "¥\(String(format: "%.2f", stats.totalBalance))",
                    icon: "banknote",
                    color: stats.totalBalance >= 0 ? .green : .red
                )
                
                StatCard(
                    title: "本月收入",
                    value: "¥\(String(format: "%.2f", stats.incomeThisMonth))",
                    icon: "arrow.up.circle",
                    color: .green
                )
                
                StatCard(
                    title: "本月支出",
                    value: "¥\(String(format: "%.2f", stats.expenseThisMonth))",
                    icon: "arrow.down.circle",
                    color: .red
                )
                
                StatCard(
                    title: "净收益",
                    value: "¥\(String(format: "%.2f", stats.incomeThisMonth - stats.expenseThisMonth))",
                    icon: "chart.line.uptrend.xyaxis",
                    color: (stats.incomeThisMonth - stats.expenseThisMonth) >= 0 ? .green : .red
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

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct TaskCompletionStats: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DailyTask.createdDate, ascending: false)],
        animation: .default)
    private var dailyTasks: FetchedResults<DailyTask>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BigTask.createdDate, ascending: false)],
        animation: .default)
    private var bigTasks: FetchedResults<BigTask>
    
    var dailyTaskCompletionRate: Double {
        let total = dailyTasks.count
        let completed = dailyTasks.filter { $0.isCompleted }.count
        return total > 0 ? Double(completed) / Double(total) : 0
    }
    
    var bigTaskCompletionRate: Double {
        let total = bigTasks.count
        let completed = bigTasks.filter { $0.status == BigTaskStatus.completed.rawValue }.count
        return total > 0 ? Double(completed) / Double(total) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("任务完成率")
                .font(.headline)
                .padding(.bottom, 4)
            
            VStack(spacing: 16) {
                // 每日任务完成率
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("每日任务")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(String(format: "%.1f", dailyTaskCompletionRate * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    CircularProgressView(progress: dailyTaskCompletionRate, color: .blue)
                        .frame(width: 60, height: 60)
                }
                
                Divider()
                
                // 大任务完成率
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("大任务")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(String(format: "%.1f", bigTaskCompletionRate * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                    
                    Spacer()
                    
                    CircularProgressView(progress: bigTaskCompletionRate, color: .purple)
                        .frame(width: 60, height: 60)
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

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            
            Text("\(String(format: "%.0f", progress * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(PersistenceController.preview)
    }
}
