import SwiftUI

// 这个文件展示了应用的预览界面
struct AppPreviewShowcase: View {
    var body: some View {
        TabView {
            // 仪表盘预览
            DashboardPreview()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("概览")
                }
            
            // 每日任务预览
            DailyTasksPreview()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("每日任务")
                }
            
            // 大任务预览
            BigTasksPreview()
                .tabItem {
                    Image(systemName: "target")
                    Text("大任务")
                }
            
            // 消费记录预览
            ExpensesPreview()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("消费记录")
                }
            
            // 统计预览
            StatisticsPreview()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("统计")
                }
        }
        .accentColor(.blue)
    }
}

// MARK: - 仪表盘预览
struct DashboardPreview: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 余额卡片
                    VStack(spacing: 8) {
                        Text("账户余额")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("¥1,250.00")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // 收支概览
                    VStack(alignment: .leading, spacing: 12) {
                        Text("收支概览")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("总收入: ¥1,890.00")
                                    .foregroundColor(.green)
                                Text("总支出: ¥640.00")
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("本月收入: ¥420.00")
                                    .font(.caption)
                                Text("本月支出: ¥180.00")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    
                    // 任务完成情况
                    VStack(alignment: .leading, spacing: 12) {
                        Text("任务完成情况")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            VStack {
                                Text("15")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("每日任务")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            
                            VStack {
                                Text("3")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("大任务")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                }
                .padding()
            }
            .navigationTitle("奖励账户")
        }
    }
}

// MARK: - 每日任务预览
struct DailyTasksPreview: View {
    var body: some View {
        NavigationView {
            List {
                TaskRow(title: "跑步30分钟", type: "运动", amount: 20, completed: true)
                TaskRow(title: "阅读1小时", type: "阅读", amount: 15, completed: false)
                TaskRow(title: "冥想15分钟", type: "冥想", amount: 10, completed: true)
                TaskRow(title: "学习编程2小时", type: "学习", amount: 30, completed: false)
            }
            .navigationTitle("每日任务")
        }
    }
}

struct TaskRow: View {
    let title: String
    let type: String
    let amount: Double
    let completed: Bool
    
    var body: some View {
        HStack {
            Image(systemName: getIcon())
                .foregroundColor(getColor())
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .strikethrough(completed)
                Text(type)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(getColor().opacity(0.2))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            Text("¥\(amount, specifier: "%.0f")")
                .foregroundColor(.green)
            
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(completed ? .green : .gray)
        }
        .padding(.vertical, 4)
    }
    
    func getIcon() -> String {
        switch type {
        case "运动": return "figure.run"
        case "阅读": return "book.fill"
        case "冥想": return "leaf.fill"
        case "学习": return "graduationcap.fill"
        default: return "star.fill"
        }
    }
    
    func getColor() -> Color {
        switch type {
        case "运动": return .orange
        case "阅读": return .blue
        case "冥想": return .green
        case "学习": return .purple
        default: return .gray
        }
    }
}

// MARK: - 大任务预览
struct BigTasksPreview: View {
    var body: some View {
        NavigationView {
            List {
                BigTaskRow(title: "完成Swift学习课程", progress: 0.7, amount: 500)
                BigTaskRow(title: "读完10本专业书籍", progress: 0.4, amount: 300)
                BigTaskRow(title: "完成毕业论文", progress: 0.1, amount: 1000)
            }
            .navigationTitle("大任务")
        }
    }
}

struct BigTaskRow: View {
    let title: String
    let progress: Double
    let amount: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("¥\(amount, specifier: "%.0f")")
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("进度")
                        .font(.caption)
                    Spacer()
                    Text("\(progress * 100, specifier: "%.0f")%")
                        .font(.caption)
                }
                ProgressView(value: progress)
                    .tint(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 消费记录预览
struct ExpensesPreview: View {
    var body: some View {
        NavigationView {
            List {
                ExpenseRow(title: "买了新游戏", category: "游戏", amount: 60)
                ExpenseRow(title: "买乐高积木", category: "玩具", amount: 200)
                ExpenseRow(title: "购买编程书籍", category: "书籍", amount: 80)
                ExpenseRow(title: "看电影", category: "娱乐", amount: 40)
            }
            .navigationTitle("消费记录")
        }
    }
}

struct ExpenseRow: View {
    let title: String
    let category: String
    let amount: Double
    
    var body: some View {
        HStack {
            Image(systemName: getIcon())
                .foregroundColor(getColor())
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(getColor().opacity(0.2))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            Text("¥\(amount, specifier: "%.0f")")
                .foregroundColor(.red)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
    
    func getIcon() -> String {
        switch category {
        case "游戏": return "gamecontroller.fill"
        case "玩具": return "teddybear.fill"
        case "书籍": return "book.fill"
        case "娱乐": return "tv.fill"
        default: return "bag.fill"
        }
    }
    
    func getColor() -> Color {
        switch category {
        case "游戏": return .purple
        case "玩具": return .yellow
        case "书籍": return .blue
        case "娱乐": return .red
        default: return .gray
        }
    }
}

// MARK: - 统计预览
struct StatisticsPreview: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 收支对比
                    VStack(alignment: .leading) {
                        Text("收支对比")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            VStack {
                                Rectangle()
                                    .fill(.green)
                                    .frame(width: 40, height: 120)
                                Text("收入")
                                    .font(.caption)
                                Text("¥1,890")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            VStack {
                                Rectangle()
                                    .fill(.red)
                                    .frame(width: 40, height: 80)
                                Text("支出")
                                    .font(.caption)
                                Text("¥640")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                    
                    // 任务完成率
                    VStack(alignment: .leading) {
                        Text("任务完成率")
                            .font(.headline)
                        
                        HStack {
                            VStack {
                                Text("每日任务")
                                Text("85%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Text("大任务")
                                Text("60%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                }
                .padding()
            }
            .navigationTitle("统计分析")
        }
    }
}

// MARK: - 预览
struct AppPreviewShowcase_Previews: PreviewProvider {
    static var previews: some View {
        AppPreviewShowcase()
    }
}


