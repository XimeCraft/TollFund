import Foundation
import CoreData

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 添加一些预览数据
        let dailyTask = DailyTask(context: viewContext)
        dailyTask.id = UUID()
        dailyTask.title = "跑步30分钟"
        dailyTask.taskType = TaskType.exercise.rawValue
        dailyTask.rewardAmount = 20
        dailyTask.isCompleted = false
        dailyTask.createdDate = Date()
        
        let bigTask = BigTask(context: viewContext)
        bigTask.id = UUID()
        bigTask.title = "完成Swift学习课程"
        bigTask.taskDescription = "学习完整的Swift编程语言课程"
        bigTask.rewardAmount = 500
        // TODO: Temporarily commented out due to Core Data issues
        // bigTask.category = "学习"
        // bigTask.subcategory = "lecture"
        bigTask.status = BigTaskStatus.inProgress.rawValue
        bigTask.createdDate = Date()
        bigTask.targetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        bigTask.progress = 0.3
        
        let expense = Expense(context: viewContext)
        expense.id = UUID()
        expense.title = "买了新游戏"
        expense.amount = 60
        expense.category = ExpenseCategory.games.rawValue
        expense.date = Date()

        // 添加一些预览的固定任务模板
        let fixedTemplate = FixedTaskTemplate(context: viewContext)
        fixedTemplate.id = UUID()
        fixedTemplate.title = "健康生活"
        fixedTemplate.taskType = TaskType.health.rawValue
        fixedTemplate.rewardAmount = 10
        fixedTemplate.isActive = true

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TollFund")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // 启用轻量级迁移和持久化
            let description = container.persistentStoreDescriptions.first!
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                print("Error code: \(error.code)")
                print("Error domain: \(error.domain)")
                
                // 如果是迁移错误，尝试删除旧数据库并重新创建
                if error.code == NSPersistentStoreIncompatibleVersionHashError ||
                   error.code == NSMigrationMissingSourceModelError ||
                   error.code == NSMigrationMissingMappingModelError ||
                   error.domain == NSCocoaErrorDomain {
                    print("⚠️ Database migration/compatibility error detected, attempting to recreate database...")
                    self.deleteAndRecreateStore()
                } else {
                    print("❌ Fatal Core Data error that cannot be resolved")
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
            } else {
                print("✅ Core Data store loaded successfully")
                if let storeURL = storeDescription.url {
                    print("📂 数据库位置: \(storeURL)")
                }
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
                print("💾 数据已成功保存到Core Data")
            } catch {
                let nsError = error as NSError
                print("❌ Core Data保存失败: \(nsError), \(nsError.userInfo)")
                
                // 尝试回滚并重新保存
                context.rollback()
                print("🔄 已回滚上下文，尝试重新保存...")
                
                if context.hasChanges {
                    do {
                        try context.save()
                        print("✅ 重新保存成功")
                    } catch {
                        print("❌ 重新保存也失败了: \(error)")
                    }
                }
            }
        } else {
            print("📝 没有需要保存的更改")
        }
    }

    // 删除并重新创建数据库存储
    private func deleteAndRecreateStore() {
        guard let storeURL = container.persistentStoreCoordinator.persistentStores.first?.url else {
            return
        }

        do {
            // 删除旧的数据库文件
            try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)

            // 重新加载存储
            try container.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
            print("Database recreated successfully")
        } catch {
            print("Failed to recreate database: \(error)")
            // 如果重新创建也失败，则删除文件
            try? FileManager.default.removeItem(at: storeURL)
            fatalError("Could not recreate database: \(error)")
        }
    }
    
    // MARK: - 统计计算方法
    
    func calculateTotalBalance() -> Double {
        let totalIncome = calculateTotalIncome()
        let totalExpense = calculateTotalExpense()
        
        return totalIncome - totalExpense
    }
    
    func calculateTotalIncome() -> Double {
        let context = container.viewContext
        
        // 计算已完成的每日任务收入
        let dailyTaskFetch: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
        dailyTaskFetch.predicate = NSPredicate(format: "isCompleted == YES")
        
        let completedDailyTasks = (try? context.fetch(dailyTaskFetch)) ?? []
        let dailyIncome = completedDailyTasks.reduce(0) { $0 + $1.rewardAmount }
        
        print("💰 查询已完成的每日任务: \(completedDailyTasks.count) 个")
        for task in completedDailyTasks {
            print("   ✅ \(task.title ?? "无标题") - ¥\(task.rewardAmount) - 完成时间: \(task.completedDate?.description ?? "无")")
        }
        print("💰 每日任务总收入: ¥\(dailyIncome)")
        
        // 计算已完成的大任务收入
        let bigTaskFetch: NSFetchRequest<BigTask> = BigTask.fetchRequest()
        bigTaskFetch.predicate = NSPredicate(format: "status == %@", BigTaskStatus.completed.rawValue)
        
        let completedBigTasks = (try? context.fetch(bigTaskFetch)) ?? []
        let bigTaskIncome = completedBigTasks.reduce(0) { $0 + $1.rewardAmount }
        
        print("💰 查询已完成的大任务: \(completedBigTasks.count) 个")
        print("💰 大任务总收入: ¥\(bigTaskIncome)")
        print("💰 总收入: ¥\(dailyIncome + bigTaskIncome)")
        
        return dailyIncome + bigTaskIncome
    }
    
    func calculateTotalExpense() -> Double {
        let context = container.viewContext
        
        let expenseFetch: NSFetchRequest<Expense> = Expense.fetchRequest()
        let expenses = (try? context.fetch(expenseFetch)) ?? []
        
        return expenses.reduce(0) { $0 + $1.amount }
    }
    
    func getDashboardStats() -> DashboardStats {
        let context = container.viewContext
        
        let totalIncome = calculateTotalIncome()
        let totalExpense = calculateTotalExpense()
        let totalBalance = totalIncome - totalExpense
        
        // 计算已完成的每日任务数量
        let dailyTaskFetch: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
        dailyTaskFetch.predicate = NSPredicate(format: "isCompleted == YES")
        let dailyTasksCompleted = (try? context.count(for: dailyTaskFetch)) ?? 0
        
        // 计算已完成的大任务数量
        let bigTaskFetch: NSFetchRequest<BigTask> = BigTask.fetchRequest()
        bigTaskFetch.predicate = NSPredicate(format: "status == %@", BigTaskStatus.completed.rawValue)
        let bigTasksCompleted = (try? context.count(for: bigTaskFetch)) ?? 0
        
        // 计算本月收入和支出
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        
        let monthlyExpenseFetch: NSFetchRequest<Expense> = Expense.fetchRequest()
        monthlyExpenseFetch.predicate = NSPredicate(format: "date >= %@", startOfMonth as NSDate)
        let monthlyExpenses = (try? context.fetch(monthlyExpenseFetch)) ?? []
        let expenseThisMonth = monthlyExpenses.reduce(0) { $0 + $1.amount }
        
        // 本月收入（已完成的任务）
        let monthlyDailyTaskFetch: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
        monthlyDailyTaskFetch.predicate = NSPredicate(format: "isCompleted == YES AND completedDate >= %@", startOfMonth as NSDate)
        let monthlyDailyTasks = (try? context.fetch(monthlyDailyTaskFetch)) ?? []
        let monthlyDailyIncome = monthlyDailyTasks.reduce(0) { $0 + $1.rewardAmount }
        
        let monthlyBigTaskFetch: NSFetchRequest<BigTask> = BigTask.fetchRequest()
        monthlyBigTaskFetch.predicate = NSPredicate(format: "status == %@ AND completedDate >= %@", BigTaskStatus.completed.rawValue, startOfMonth as NSDate)
        let monthlyBigTasks = (try? context.fetch(monthlyBigTaskFetch)) ?? []
        let monthlyBigTaskIncome = monthlyBigTasks.reduce(0) { $0 + $1.rewardAmount }
        
        let incomeThisMonth = monthlyDailyIncome + monthlyBigTaskIncome
        
        return DashboardStats(
            totalBalance: totalBalance,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            dailyTasksCompleted: dailyTasksCompleted,
            bigTasksCompleted: bigTasksCompleted,
            expenseThisMonth: expenseThisMonth,
            incomeThisMonth: incomeThisMonth
        )
    }
    
    func getCategoryExpenses() -> [CategoryExpense] {
        let context = container.viewContext
        
        let expenseFetch: NSFetchRequest<Expense> = Expense.fetchRequest()
        let expenses = (try? context.fetch(expenseFetch)) ?? []
        
        let totalExpense = expenses.reduce(0) { $0 + $1.amount }
        
        let groupedExpenses = Dictionary(grouping: expenses) { $0.category }
        
        return ExpenseCategory.allCases.compactMap { category in
            let categoryExpenses = groupedExpenses[category.rawValue] ?? []
            let amount = categoryExpenses.reduce(0) { $0 + $1.amount }
            if amount > 0 {
                let percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0
                return CategoryExpense(category: category, amount: amount, percentage: percentage)
            }
            return nil
        }.sorted { $0.amount > $1.amount }
    }
}
