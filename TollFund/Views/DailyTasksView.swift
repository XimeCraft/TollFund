
import SwiftUI
import CoreData

struct DailyTasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: PersistenceController
    
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var showingTaskConfig = false
    @State private var editingTask: DailyTask?
    @State private var taskToDelete: DailyTask?
    @State private var showingDeleteConfirmation = false

    // 历史记录相关的状态变量
    @State private var historySelectedDate = Date()
    @State private var historyTasksForSelectedDate: [DailyTask] = []
    @State private var showingHistoryDatePicker = false

    // 使用 @FetchRequest 来自动监听数据变化
    @FetchRequest(
        entity: DailyTask.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \DailyTask.isFixed, ascending: false),
            NSSortDescriptor(keyPath: \DailyTask.createdDate, ascending: true)
        ]
    ) private var allTasks: FetchedResults<DailyTask>
    
    // 监听固定任务模板变化
    @FetchRequest(
        entity: FixedTaskTemplate.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FixedTaskTemplate.title, ascending: true)]
    ) private var fixedTaskTemplates: FetchedResults<FixedTaskTemplate>

    // 获取选中日期的任务
    var tasksForSelectedDate: [DailyTask] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let filtered = allTasks.filter { task in
            guard let taskDate = task.taskDate else { return false }
            return taskDate >= startOfDay && taskDate < endOfDay
        }

        print("🔍 查询日期 \(startOfDay) 的任务: 找到 \(filtered.count) 个任务")
        for task in filtered {
            print("   📋 \(task.title ?? "无标题") - 固定:\(task.isFixed) - 完成:\(task.isCompleted)")
        }
        
        return filtered
    }

    // 区分固定任务和临时任务
    var fixedTasks: [DailyTask] {
        tasksForSelectedDate.filter { $0.isFixed }
    }

    var tempTasks: [DailyTask] {
        tasksForSelectedDate.filter { !$0.isFixed }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 左右滑动翻页视图
                TabView {
                    // 第一页：每日任务
                    VStack {
                        // 日期选择器
                        DateSelectorView(selectedDate: $selectedDate)
                            .padding(.horizontal)

                        if tasksForSelectedDate.isEmpty {
                            EmptyStateView(selectedDate: selectedDate)
                        } else {
                            ScrollView {
                                VStack(spacing: 20) {
                                    // 固定任务区域
                                    if !fixedTasks.isEmpty {
                                        TaskSectionView(
                                            title: "固定任务",
                                            tasks: fixedTasks,
                                            icon: "pin.fill",
                                            color: .blue,
                                            onEditTask: { task in
                                                editingTask = task
                                            },
                                            onDeleteTask: { task in
                                                handleDeleteTask(task)
                                            }
                                        )
                                    }

                                    // 临时任务区域
                                    if !tempTasks.isEmpty {
                                        TaskSectionView(
                                            title: "临时任务",
                                            tasks: tempTasks,
                                            icon: "plus.circle",
                                            color: .green,
                                            onEditTask: { task in
                                                editingTask = task
                                            },
                                            onDeleteTask: { task in
                                                handleDeleteTask(task)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .tabItem {
                        Image(systemName: "checklist")
                        Text("今日任务")
                    }

                    // 第二页：历史记录
                    VStack {
                        TaskHistoryContent(selectedDate: $historySelectedDate, tasksForSelectedDate: $historyTasksForSelectedDate, showingDatePicker: $showingHistoryDatePicker, editingTask: $editingTask, onDateChange: loadTasksForHistoryDate)
                    }
                    .tabItem {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("历史记录")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationTitle("每日任务")
            .navigationBarItems(trailing:
                HStack(spacing: 16) {
                    // 任务配置按钮（齿轮）
                    Button(action: {
                        showingTaskConfig = true
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                    }

                    // 添加任务按钮（加号）
                    Button(action: {
                        showingAddTask = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.green)
                    }
                }
            )
            .sheet(isPresented: $showingAddTask) {
                AddDailyTaskView(selectedDate: selectedDate)
            }
            .sheet(isPresented: $showingTaskConfig) {
                FixedTaskConfigView()
            }
            .sheet(isPresented: $showingHistoryDatePicker) {
                DatePickerSheet(selectedDate: $historySelectedDate, isPresented: $showingHistoryDatePicker)
            }
            .sheet(item: $editingTask) { task in
                EditDailyTaskView(task: task)
            }
            .onAppear {
                print("🚀 进入每日任务页面 - 选中日期: \(selectedDate)")
                // 确保选中日期的固定任务存在
                ensureDailyTasksExist(for: selectedDate)
                // UI会通过计算属性自动更新，无需手动刷新
            }
            .onChange(of: selectedDate) { newDate in
                ensureDailyTasksExist(for: newDate)
            }
            .onChange(of: fixedTaskTemplates.count) { _ in
                print("🔄 固定任务模板发生变化，重新生成任务")
                ensureDailyTasksExist(for: selectedDate)
            }
            .onChange(of: fixedTaskTemplates.map { "\($0.isActive)" }.joined()) { _ in
                print("🔄 固定任务模板激活状态发生变化，重新生成任务")
                ensureDailyTasksExist(for: selectedDate)
            }
            .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) {
                    taskToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let task = taskToDelete {
                        deleteTaskDirectly(task)
                        taskToDelete = nil
                    }
                }
            } message: {
                Text("确定要删除该固定任务吗？删除后该任务将不再出现在每日任务清单中，但历史记录保留。")
            }
        }
    }

    // 确保选中日期的固定任务存在
    private func ensureDailyTasksExist(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        print("🔄 开始确保日期 \(startOfDay) 的固定任务存在")

        // 获取所有活跃的固定任务模板
        let templateFetch: NSFetchRequest<FixedTaskTemplate> = FixedTaskTemplate.fetchRequest()
        templateFetch.predicate = NSPredicate(format: "isActive == YES")

        guard let templates = try? viewContext.fetch(templateFetch) else {
            print("❌ 无法获取固定任务模板")
            return
        }

        print("📋 找到 \(templates.count) 个活跃的固定任务模板")
        for template in templates {
            print("   📝 模板: \(template.title ?? "无标题") - 活跃:\(template.isActive)")
        }

        // 首先删除已不活跃的固定任务
        let allFixedTasksFetch: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
        allFixedTasksFetch.predicate = NSPredicate(format: "isFixed == YES AND taskDate == %@", startOfDay as NSDate)

        do {
            let existingFixedTasks = try viewContext.fetch(allFixedTasksFetch)
            let activeTemplateNames = Set(templates.map { $0.title ?? "" })

            for task in existingFixedTasks {
                let taskTitle = task.title ?? ""
                if !activeTemplateNames.contains(taskTitle) {
                    print("🗑️ 删除已关闭的固定任务: \(taskTitle)")
                    viewContext.delete(task)
                }
            }
        } catch {
            print("❌ 清理固定任务时出错: \(error)")
        }

        // 为每个模板检查是否已有对应日期的任务
        for template in templates {
            let taskFetch: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
            taskFetch.predicate = NSPredicate(format: "isFixed == YES AND taskDate == %@ AND title == %@", startOfDay as NSDate, template.title ?? "")

            do {
                let existingTasks = try viewContext.fetch(taskFetch)
                if existingTasks.isEmpty {
                    // 创建新的固定任务
                    print("➕ 为日期 \(startOfDay) 创建固定任务: \(template.title ?? "")")
                    let newTask = DailyTask(context: viewContext)
                    newTask.id = UUID()
                    newTask.title = template.title
                    newTask.taskType = template.taskType
                    // 保存创建时的模板金额，之后不会随模板变化而变化
                    newTask.rewardAmount = template.rewardAmount
                    newTask.originalRewardAmount = template.rewardAmount
                    newTask.isFixed = true
                    newTask.isCompleted = false
                    newTask.taskDate = startOfDay
                    newTask.createdDate = Date()
                    // 记录任务创建时的模板信息，用于历史追踪
                    print("💰 创建任务金额: ¥\(template.rewardAmount) (模板当前金额)")
                } else {
                    print("✅ 固定任务已存在: \(template.title ?? "")")
                    // 历史任务保持原有金额，不受模板变化影响
                    for task in existingTasks {
                        print("   📋 历史任务金额: ¥\(task.rewardAmount)")
                    }
                }
            } catch {
                print("❌ 检查固定任务时出错: \(error)")
            }
        }

        // 保存更改并刷新UI
        do {
            try viewContext.save()
            print("💾 固定任务数据已保存")

            // 使用小延迟确保 UI 正确刷新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("💾 数据已保存，UI应该已经刷新")
                print("📊 当前选中日期的任务数量: \(self.tasksForSelectedDate.count)")
                for task in self.tasksForSelectedDate {
                    print("   📋 任务: \(task.title ?? "无标题") - 固定:\(task.isFixed)")
                }
            }
        } catch {
            print("❌ 保存固定任务数据失败: \(error)")
        }
    }
    
    // 智能删除任务（根据任务类型决定是否需要确认）
    private func handleDeleteTask(_ task: DailyTask) {
        if task.isFixed {
            // 固定任务需要确认
            taskToDelete = task
            showingDeleteConfirmation = true
        } else {
            // 临时任务直接删除
            deleteTaskDirectly(task)
        }
    }
    
    // 直接删除任务
    private func deleteTaskDirectly(_ task: DailyTask) {
        withAnimation {
            print("🗑️ 删除任务: \(task.title ?? "") - 类型: \(task.isFixed ? "固定" : "临时")")
            viewContext.delete(task)
            
            do {
                try viewContext.save()
                print("💾 任务删除成功")
            } catch {
                print("❌ 删除任务失败: \(error)")
            }
        }
    }

    private func loadTasksForHistoryDate(_ date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let fetchRequest: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "(taskDate >= %@) AND (taskDate < %@)", startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DailyTask.isFixed, ascending: false), NSSortDescriptor(keyPath: \DailyTask.createdDate, ascending: true)]

        do {
            let tasks = try viewContext.fetch(fetchRequest)
            historyTasksForSelectedDate = tasks
            print("📚 加载历史日期 \(startOfDay) 的任务: \(tasks.count) 个任务")
            for task in tasks {
                print("   - \(task.title ?? "") (\(task.isFixed ? "固定" : "临时"))")
            }
        } catch {
            print("❌ 加载历史任务失败: \(error)")
            historyTasksForSelectedDate = []
        }
    }
}

// MARK: - 日期选择器视图
struct DateSelectorView: View {
    @Binding var selectedDate: Date

    var body: some View {
        HStack {
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            Spacer()

            VStack(spacing: 4) {
                Text(formattedDate(selectedDate))
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(isToday(selectedDate) ? "今天" : isYesterday(selectedDate) ? "昨天" : "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                if tomorrow <= Date() { // 不允许选择未来的日期
                    selectedDate = tomorrow
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(selectedDate < Date() ? .blue : .gray.opacity(0.3))
            }
            .disabled(selectedDate >= Date())
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func isYesterday(_ date: Date) -> Bool {
        Calendar.current.isDateInYesterday(date)
    }
}

// MARK: - 任务区域视图
struct TaskSectionView: View {
    let title: String
    let tasks: [DailyTask]
    let icon: String
    let color: Color
    let onEditTask: (DailyTask) -> Void
    let onDeleteTask: (DailyTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(tasks.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.top)

            // 任务列表 - 使用List支持swipeActions
            List {
                ForEach(tasks, id: \.id) { task in
                    DailyTaskRow(task: task, onEdit: {
                        onEditTask(task)
                    })
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDeleteTask(task)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
            }
            .listStyle(PlainListStyle())
            .frame(height: CGFloat(tasks.count * 80)) // 动态高度
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - 任务行视图
struct DailyTaskRow: View {
    @ObservedObject var task: DailyTask
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: PersistenceController
    
    let onEdit: (() -> Void)?
    
    var taskType: TaskType {
        TaskType(rawValue: task.taskType ?? "") ?? .other
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 任务类型图标
            Image(systemName: taskType.icon)
                .font(.title2)
                .foregroundColor(taskType.color)
                .frame(width: 30)
            
            // 任务内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                Text(task.title ?? "未知任务")
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                    if task.isFixed {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                HStack {
                    Text(taskType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(taskType.color.opacity(0.2))
                        .foregroundColor(taskType.color)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text("¥\(task.rewardAmount, specifier: "%.0f")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // 完成按钮
            Button(action: toggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit?()
        }
    }
    
    private func toggleCompletion() {
        withAnimation {
            task.isCompleted.toggle()
            if task.isCompleted {
                task.completedDate = Date()
                print("✅ 任务完成: \(task.title ?? "") - 奖励: ¥\(task.rewardAmount)")
            } else {
                task.completedDate = nil
                print("❌ 取消完成: \(task.title ?? "")")
            }
            
            // 直接使用 viewContext 保存
            do {
                try viewContext.save()
                print("💾 任务状态已保存到数据库")
            } catch {
                print("❌ 保存任务状态失败: \(error)")
            }
            
            // 发送通知告知数据变化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("📢 发送任务完成状态变化通知")
                NotificationCenter.default.post(name: NSNotification.Name("TaskCompletionChanged"), object: nil)
            }
        }
    }
}


// MARK: - 添加每日任务视图
struct AddDailyTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController

    let selectedDate: Date
    
    @State private var title = ""
    @State private var selectedTaskType = TaskType.other
    @State private var rewardAmount = 10.0
    @State private var isFixed = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("任务信息") {
                    TextField("任务标题", text: $title)
                    
                    Picker("任务类型", selection: $selectedTaskType) {
                        ForEach(TaskType.allCases, id: \.self) { taskType in
                            HStack {
                                Image(systemName: taskType.icon)
                                    .foregroundColor(taskType.color)
                                Text(taskType.rawValue)
                            }
                            .tag(taskType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    HStack {
                        Text("奖励金额")
                        Spacer()
                        TextField("金额", value: $rewardAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元")
                            .foregroundColor(.secondary)
                    }

                    Toggle("设为固定任务", isOn: $isFixed)
                        .tint(.blue)
                }

                if isFixed {
                    Section("固定任务说明") {
                        Text("固定任务将每天自动生成，您可以在任务配置中管理所有固定任务。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("预设任务") {
                    PresetTaskButton(
                        title: "跑步30分钟",
                        type: .exercise,
                        amount: 20,
                        onSelect: { title, type, amount in
                        self.title = title
                        self.selectedTaskType = type
                        self.rewardAmount = amount
                    }
                    )
                    
                    PresetTaskButton(
                        title: "阅读1小时",
                        type: .reading,
                        amount: 15,
                        onSelect: { title, type, amount in
                        self.title = title
                        self.selectedTaskType = type
                        self.rewardAmount = amount
                    }
                    )
                    
                    PresetTaskButton(
                        title: "健康餐食",
                        type: .health,
                        amount: 10,
                        onSelect: { title, type, amount in
                        self.title = title
                        self.selectedTaskType = type
                        self.rewardAmount = amount
                    }
                    )
                    
                    PresetTaskButton(
                        title: "学习2小时",
                        type: .study,
                        amount: 30,
                        onSelect: { title, type, amount in
                        self.title = title
                        self.selectedTaskType = type
                        self.rewardAmount = amount
                    }
                    )
                }
            }
            .navigationTitle("添加每日任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveTask() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)

        let newTask = DailyTask(context: viewContext)
        newTask.id = UUID()
        newTask.title = title
        newTask.taskType = selectedTaskType.rawValue
        newTask.rewardAmount = rewardAmount
        newTask.originalRewardAmount = rewardAmount
        newTask.isFixed = isFixed
        newTask.isCompleted = false
        newTask.taskDate = startOfDay
        newTask.createdDate = Date()

        // 如果是固定任务，还需要保存到模板
        if isFixed {
            let templateFetch: NSFetchRequest<FixedTaskTemplate> = FixedTaskTemplate.fetchRequest()
            templateFetch.predicate = NSPredicate(format: "title == %@", title)

            if let existingTemplates = try? viewContext.fetch(templateFetch), existingTemplates.isEmpty {
                let template = FixedTaskTemplate(context: viewContext)
                template.id = UUID()
                template.title = title
                template.taskType = selectedTaskType.rawValue
                template.rewardAmount = rewardAmount
                template.isActive = true
            }
        }
        
        dataManager.save()
        dismiss()
    }
}

struct PresetTaskButton: View {
    let title: String
    let type: TaskType
    let amount: Double
    let onSelect: (String, TaskType, Double) -> Void
    
    var body: some View {
        Button(action: {
            onSelect(title, type, amount)
        }) {
            HStack {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                    .frame(width: 20)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("¥\(amount, specifier: "%.0f")")
                    .foregroundColor(.green)
                    .font(.system(size: 14, weight: .medium))
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyStateView: View {
    let selectedDate: Date

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "今天还没有任务"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "昨天还没有任务"
        } else {
            return "这天还没有任务"
        }
    }

    private var emptyStateMessage: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "点击底部的添加任务按钮来创建你的第一个任务"
        } else {
            return "可以点击任务完成按钮来补打卡"
        }
    }
}

// MARK: - 简化的固定任务配置视图
struct FixedTaskConfigView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController
    
    @FetchRequest(
        entity: FixedTaskTemplate.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FixedTaskTemplate.title, ascending: true)]
    ) private var templates: FetchedResults<FixedTaskTemplate>

    // 编辑状态
    @State private var showingTemplateEditor = false
    @State private var editingTemplate: FixedTaskTemplate?

    // 预设的固定任务列表
    private let defaultFixedTasks = [
        ("12点前睡觉", "健康", 2.0),
        ("外出不打车", "健康", 1.0),
        ("午餐轻食", "健康", 5.0),
        ("运动 > 30 mins", "运动", 5.0),
        ("阅读 > 2页", "阅读", 5.0),
        ("练习打鼓 > 30 mins", "兴趣", 2.0),
        ("练习吉他 > 30 mins", "兴趣", 5.0),
        ("记录新知识点", "学习", 5.0),
        ("记录idea", "学习", 2.0),
        ("爬楼梯 > 5层", "运动", 1.0)
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("固定任务列表") {
                    ForEach(defaultFixedTasks, id: \.0) { task in
                        let (title, category, amount) = task
                        let isActive = getTaskActiveStatus(title: title)

                        if let existingTemplate = templates.first(where: { $0.title == title }) {
                            FixedTaskTemplateRow(
                                template: existingTemplate,
                                onEdit: {
                                    editingTemplate = existingTemplate
                                    showingTemplateEditor = true
                                }
                            )
                        } else {
                            // 如果模板不存在，创建一个临时的
                            let buttonAction = {
                                // 创建新的模板
                                let template = FixedTaskTemplate(context: viewContext)
                                template.id = UUID()
                                template.title = title
                                template.taskType = category
                                template.rewardAmount = amount
                                template.isActive = false

                                editingTemplate = template
                                showingTemplateEditor = true
                            }

                            Button(action: buttonAction) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(title)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(category)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text("¥\(amount, specifier: "%.0f")")
                                        .font(.headline)
                                        .foregroundColor(.green)

                                    Toggle("", isOn: Binding(
                                        get: { isActive },
                                        set: { newValue in
                                            toggleTask(title: title, category: category, amount: amount, isActive: newValue)
                                        }
                                    ))
                                    .labelsHidden()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Section(footer: Text("开启的固定任务将每天自动生成，您可以随时开启或关闭。")) {
                    EmptyView()
                }
            }
            .navigationTitle("固定任务配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                createDefaultTemplatesIfNeeded()
            }
            .sheet(isPresented: $showingTemplateEditor) {
                if let template = editingTemplate {
                    EditFixedTaskTemplateView(template: template)
                }
            }
        }
    }
    
    // 获取任务的激活状态
    private func getTaskActiveStatus(title: String) -> Bool {
        return templates.first { $0.title == title }?.isActive ?? false
    }
    
    // 切换任务的激活状态
    private func toggleTask(title: String, category: String, amount: Double, isActive: Bool) {
        if let existingTemplate = templates.first(where: { $0.title == title }) {
            existingTemplate.isActive = isActive
        } else if isActive {
            // 创建新的模板
            let template = FixedTaskTemplate(context: viewContext)
            template.id = UUID()
            template.title = title
            template.taskType = category
            template.rewardAmount = amount
            template.isActive = true
        }
        dataManager.save()
    }


    // 创建默认模板（仅在首次使用时）
    private func createDefaultTemplatesIfNeeded() {
        // 只在完全没有模板时才创建，避免重复创建
        if templates.isEmpty {
            // 默认激活前3个任务作为示例
            for task in defaultFixedTasks.prefix(3) {
                let (title, category, amount) = task
                let template = FixedTaskTemplate(context: viewContext)
                template.id = UUID()
                template.title = title
                template.taskType = category
                template.rewardAmount = amount
                template.isActive = true
            }
            dataManager.save()
        }
    }

}

// MARK: - 任务历史视图 (已移除，功能整合到主视图)

// MARK: - 日期选择器弹窗
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack {
                Text("选择日期")
                    .font(.headline)
                    .padding()

                DatePicker(
                    "",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - 固定任务模板行视图
struct FixedTaskTemplateRow: View {
    @ObservedObject var template: FixedTaskTemplate
    let onEdit: () -> Void

    var taskType: TaskType {
        TaskType(rawValue: template.taskType ?? "") ?? .other
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: taskType.icon)
                    .font(.title2)
                    .foregroundColor(taskType.color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title ?? "未知任务")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack {
                        Text(taskType.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(taskType.color.opacity(0.2))
                            .foregroundColor(taskType.color)
                            .clipShape(Capsule())

                        Spacer()

                        Text("¥\(template.rewardAmount, specifier: "%.0f")")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                Circle()
                    .fill(template.isActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: template.isActive ? "checkmark" : "xmark")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                    )
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 预设模板按钮
struct PresetTemplateButton: View {
    let title: String
    let type: TaskType
    let amount: Double
    let onSelect: (String, TaskType, Double) -> Void

    var body: some View {
        Button(action: {
            onSelect(title, type, amount)
        }) {
            HStack {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                    .frame(width: 20)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                Text("¥\(amount, specifier: "%.0f")")
                    .foregroundColor(.green)
                    .font(.system(size: 14, weight: .medium))

                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 添加固定任务模板视图
struct AddFixedTaskTemplateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController

    @State private var title = ""
    @State private var selectedTaskType = TaskType.other
    @State private var rewardAmount = 10.0

    var body: some View {
        NavigationView {
            Form {
                Section("模板信息") {
                    TextField("任务标题", text: $title)

                    Picker("任务类型", selection: $selectedTaskType) {
                        ForEach(TaskType.allCases, id: \.self) { taskType in
                            HStack {
                                Image(systemName: taskType.icon)
                                    .foregroundColor(taskType.color)
                                Text(taskType.rawValue)
                            }
                            .tag(taskType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    HStack {
                        Text("奖励金额")
                        Spacer()
                        TextField("金额", value: $rewardAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("添加固定任务模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTemplate()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveTemplate() {
        let template = FixedTaskTemplate(context: viewContext)
        template.id = UUID()
        template.title = title
        template.taskType = selectedTaskType.rawValue
        template.rewardAmount = rewardAmount
        template.isActive = true

        dataManager.save()
        dismiss()
    }
}

// MARK: - 编辑固定任务模板视图
struct EditFixedTaskTemplateView: View {
    @ObservedObject var template: FixedTaskTemplate
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController

    @State private var title: String
    @State private var selectedTaskType: TaskType
    @State private var rewardAmount: Double
    @State private var isActive: Bool

    init(template: FixedTaskTemplate) {
        self.template = template
        self._title = State(initialValue: template.title ?? "")
        self._selectedTaskType = State(initialValue: TaskType(rawValue: template.taskType ?? "") ?? .other)
        self._rewardAmount = State(initialValue: template.rewardAmount)
        self._isActive = State(initialValue: template.isActive)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("模板信息") {
                    TextField("任务标题", text: $title)

                    Picker("任务类型", selection: $selectedTaskType) {
                        ForEach(TaskType.allCases, id: \.self) { taskType in
                            HStack {
                                Image(systemName: taskType.icon)
                                    .foregroundColor(taskType.color)
                                Text(taskType.rawValue)
                            }
                            .tag(taskType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    HStack {
                        Text("奖励金额")
                        Spacer()
                        TextField("金额", value: $rewardAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元")
                            .foregroundColor(.secondary)
                    }

                    Toggle("启用模板", isOn: $isActive)
                        .tint(.blue)
                }

                Section {
                    Button("保存修改") {
                        saveChanges()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("编辑任务模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveChanges() {
        template.title = title
        template.taskType = selectedTaskType.rawValue
        template.rewardAmount = rewardAmount
        template.isActive = isActive

        dataManager.save()
        dismiss()
    }
}

// MARK: - 编辑每日任务视图
struct EditDailyTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController
    
    @ObservedObject var task: DailyTask
    
    @State private var title: String
    @State private var selectedTaskType: TaskType
    @State private var rewardAmount: Double
    @State private var isFixed: Bool
    
    init(task: DailyTask) {
        self.task = task
        self._title = State(initialValue: task.title ?? "")
        self._selectedTaskType = State(initialValue: TaskType(rawValue: task.taskType ?? "") ?? .other)
        self._rewardAmount = State(initialValue: task.rewardAmount)
        self._isFixed = State(initialValue: task.isFixed)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("任务信息") {
                    TextField("任务标题", text: $title)
                    
                    Picker("类型", selection: $selectedTaskType) {
                        ForEach(TaskType.allCases, id: \.self) { taskType in
                            HStack {
                                Image(systemName: taskType.icon)
                                    .foregroundColor(taskType.color)
                                Text(taskType.rawValue)
                            }
                            .tag(taskType)
                        }
                    }
                    
                    HStack {
                        Text("奖励金额")
                        Spacer()
                        TextField("金额", value: $rewardAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元")
                            .foregroundColor(.secondary)
                    }
                }
                
                if task.isFixed {
                    Section("固定任务说明") {
                        Text("这是一个固定任务，修改金额只会影响今天的任务。如需永久修改，请前往任务配置。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("任务状态") {
                    HStack {
                        Text("任务类型")
                        Spacer()
                        Picker("", selection: $isFixed) {
                            Text("临时任务").tag(false)
                            Text("固定任务").tag(true)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }
                    
                    HStack {
                        Text("创建时间")
                        Spacer()
                        if let createdDate = task.createdDate {
                            Text(createdDate, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveTask() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.taskType = selectedTaskType.rawValue
        task.rewardAmount = rewardAmount
        task.isFixed = isFixed
        
        do {
            try viewContext.save()
            print("✅ 任务编辑保存成功")
        } catch {
            print("❌ 保存任务编辑失败: \(error)")
        }
        dismiss()
    }
}

// MARK: - 历史记录内容视图
struct TaskHistoryContent: View {
    @Binding var selectedDate: Date
    @Binding var tasksForSelectedDate: [DailyTask]
    @Binding var showingDatePicker: Bool
    @Binding var editingTask: DailyTask?
    var onDateChange: (Date) -> Void

    var body: some View {
        VStack {
            // 日期选择器
            Button(action: {
                showingDatePicker = true
            }) {
                HStack {
                    Text(formattedDate(selectedDate))
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal)
            }

            if tasksForSelectedDate.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("这天没有任务记录")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(tasksForSelectedDate, id: \.id) { task in
                        DailyTaskRow(task: task, onEdit: {
                            editingTask = task
                        })
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .padding(.top)
        .onChange(of: selectedDate) { newDate in
            onDateChange(newDate)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 固定任务模板行视图 (重复定义已删除)

// MARK: - 编辑固定任务模板视图 (重复定义已删除)

struct DailyTasksView_Previews: PreviewProvider {
    static var previews: some View {
        DailyTasksView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(PersistenceController.preview)
    }
}
