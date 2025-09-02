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

// MARK: - 挑战类别枚举
enum ChallengeCategory: String, CaseIterable {
    case reading = "阅读"
    case project = "项目"
    case learning = "学习"
    case highScoreGame = "高分游戏"
    case highScoreMovie = "高分电影"
    case drums = "架子鼓"
    case guitar = "吉他"
    
    var subcategories: [ChallengeSubcategory] {
        switch self {
        case .reading:
            return [.reading300Pages, .reading500Pages]
        case .project:
            return [.projectAnalysis, .projectPrediction, .projectEngineering]
        case .learning:
            return [.learningPaper, .learningLecture]
        case .highScoreGame:
            return [.gameStory, .gameAdventure, .gamePuzzle, .gameNarrative]
        case .highScoreMovie:
            return [.movieDrama, .movieBiography, .movieSciFi, .movieArt, .movieAnimation, .movieComedy]
        case .drums:
            return [.drumsSimple, .drumsMedium]
        case .guitar:
            return [.guitarFingerstyle, .guitarSinging]
        }
    }
}

// MARK: - 挑战子类别枚举
enum ChallengeSubcategory: String, CaseIterable {
    // 阅读
    case reading300Pages = "300 pages"
    case reading500Pages = "500 pages"
    
    // 项目
    case projectAnalysis = "分析"
    case projectPrediction = "预测"
    case projectEngineering = "工程"
    
    // 学习
    case learningPaper = "论文"
    case learningLecture = "lecture"
    
    // 高分游戏
    case gameStory = "剧情"
    case gameAdventure = "冒险"
    case gamePuzzle = "解谜"
    case gameNarrative = "独立叙事"
    
    // 高分电影
    case movieDrama = "剧情"
    case movieBiography = "传记"
    case movieSciFi = "科幻"
    case movieArt = "文艺"
    case movieAnimation = "动画"
    case movieComedy = "喜剧"
    
    // 架子鼓
    case drumsSimple = "简单"
    case drumsMedium = "中等"
    
    // 吉他
    case guitarFingerstyle = "指弹"
    case guitarSinging = "弹唱"
    
    var category: ChallengeCategory {
        switch self {
        case .reading300Pages, .reading500Pages:
            return .reading
        case .projectAnalysis, .projectPrediction, .projectEngineering:
            return .project
        case .learningPaper, .learningLecture:
            return .learning
        case .gameStory, .gameAdventure, .gamePuzzle, .gameNarrative:
            return .highScoreGame
        case .movieDrama, .movieBiography, .movieSciFi, .movieArt, .movieAnimation, .movieComedy:
            return .highScoreMovie
        case .drumsSimple, .drumsMedium:
            return .drums
        case .guitarFingerstyle, .guitarSinging:
            return .guitar
        }
    }
    
    var defaultRewardAmount: Double {
        switch self {
        case .reading300Pages: return 100
        case .reading500Pages: return 150
        case .projectAnalysis: return 50
        case .projectPrediction: return 100
        case .projectEngineering: return 200
        case .learningPaper: return 20
        case .learningLecture: return 20
        case .gameStory, .gameAdventure, .gamePuzzle, .gameNarrative: return 20
        case .movieDrama, .movieBiography, .movieSciFi, .movieArt, .movieAnimation, .movieComedy: return 20
        case .drumsSimple: return 20
        case .drumsMedium: return 50
        case .guitarFingerstyle: return 50
        case .guitarSinging: return 20
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
