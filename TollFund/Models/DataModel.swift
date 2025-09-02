import Foundation
import SwiftUI

// MARK: - 任务类型枚举
enum TaskType: String, CaseIterable {
    case study = "学习"
    case reading = "阅读"
    case exercise = "运动"
    case health = "健康"
    case hobby = "兴趣"
    case leisure = "休闲"
    case other = "其他"
    
    var icon: String {
        switch self {
        case .study: return "graduationcap.fill"
        case .reading: return "book.fill"
        case .exercise: return "figure.run"
        case .health: return "heart.fill"
        case .hobby: return "music.note"
        case .leisure: return "gamecontroller.fill"
        case .other: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .study: return .purple
        case .reading: return .blue
        case .exercise: return .orange
        case .health: return .pink
        case .hobby: return .green
        case .leisure: return .cyan
        case .other: return .gray
        }
    }
}

// MARK: - 消费类型枚举
enum ExpenseCategory: String, CaseIterable {
    case games = "游戏"
    case toys = "玩具"
    case books = "书籍"
    case entertainment = "娱乐"
    case electronics = "电子产品"
    case clothes = "服装"
    case food = "美食"
    case other = "其他"
    
    var icon: String {
        switch self {
        case .games: return "gamecontroller.fill"
        case .toys: return "teddybear.fill"
        case .books: return "book.fill"
        case .entertainment: return "tv.fill"
        case .electronics: return "laptopcomputer"
        case .clothes: return "tshirt.fill"
        case .food: return "fork.knife"
        case .other: return "bag.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .games: return .purple
        case .toys: return .yellow
        case .books: return .blue
        case .entertainment: return .red
        case .electronics: return .gray
        case .clothes: return .pink
        case .food: return .orange
        case .other: return .brown
        }
    }
}

// MARK: - 大任务状态枚举
enum BigTaskStatus: String, CaseIterable {
    case notStarted = "未开始"
    case inProgress = "进行中"
    case completed = "已完成"
    
    var color: Color {
        switch self {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        }
    }
}

// MARK: - 统计数据结构
struct DashboardStats {
    let totalBalance: Double
    let totalIncome: Double
    let totalExpense: Double
    let dailyTasksCompleted: Int
    let bigTasksCompleted: Int
    let expenseThisMonth: Double
    let incomeThisMonth: Double
}

struct CategoryExpense {
    let category: ExpenseCategory
    let amount: Double
    let percentage: Double
}

struct MonthlyData {
    let month: String
    let income: Double
    let expense: Double
}
