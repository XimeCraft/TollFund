import SwiftUI
import CoreData

struct DailyTasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: PersistenceController

    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var showingTaskConfig = false
    @State private var showingHistory = false

    // 获取选中日期的任务
    var tasksForSelectedDate: [DailyTask] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let fetchRequest: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "(taskDate >= %@) AND (taskDate < %@)", startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DailyTask.isFixed, ascending: false), NSSortDescriptor(keyPath: \DailyTask.createdDate, ascending: true)]

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching tasks: \(error)")
            return []
        }
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
                                    color: .blue
                                )
                            }

                            // 临时任务区域
                            if !tempTasks.isEmpty {
                                TaskSectionView(
                                    title: "临时任务",
                                    tasks: tempTasks,
                                    icon: "plus.circle",
                                    color: .green
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // 底部操作栏
                BottomActionBar(
                    onAddTask: { showingAddTask = true },
                    onTaskConfig: { showingTaskConfig = true },
                    onHistory: { showingHistory = true }
                )
            }
            .navigationTitle("每日任务")
            .sheet(isPresented: $showingAddTask) {
                AddDailyTaskView(selectedDate: selectedDate)
            }
            .sheet(isPresented: $showingTaskConfig) {
                FixedTaskConfigView()
            }
            .sheet(isPresented: $showingHistory) {
                TaskHistoryView()
            }
            .onAppear {
                ensureDailyTasksExist(for: selectedDate)
            }
            .onChange(of: selectedDate) { newDate in
                ensureDailyTasksExist(for: newDate)
            }
        }
    }

    // 确保选中日期的固定任务存在
    private func ensureDailyTasksExist(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // 获取所有活跃的固定任务模板
        let templateFetch: NSFetchRequest<FixedTaskTemplate> = FixedTaskTemplate.fetchRequest()
        templateFetch.predicate = NSPredicate(format: "isActive == YES")

        guard let templates = try? viewContext.fetch(templateFetch) else { return }

        // 为每个模板检查是否已有对应日期的任务
        for template in templates {
            let taskFetch: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
            taskFetch.predicate = NSPredicate(format: "isFixed == YES AND taskDate == %@ AND title == %@", startOfDay as NSDate, template.title ?? "")

            if let existingTasks = try? viewContext.fetch(taskFetch), existingTasks.isEmpty {
                // 创建新的固定任务
                let newTask = DailyTask(context: viewContext)
                newTask.id = UUID()
                newTask.title = template.title
                newTask.taskType = template.taskType
                newTask.rewardAmount = template.rewardAmount
                newTask.originalRewardAmount = template.rewardAmount
                newTask.isFixed = true
                newTask.isCompleted = false
                newTask.taskDate = startOfDay
                newTask.createdDate = Date()
            }
        }

        dataManager.save()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            ForEach(tasks, id: \.id) { task in
                DailyTaskRow(task: task)
            }
        }
        .padding()
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
                        .font(.subheadline)
                        .fontWeight(.medium)
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
    }

    private func toggleCompletion() {
        withAnimation {
            task.isCompleted.toggle()
            if task.isCompleted {
                task.completedDate = Date()
            } else {
                task.completedDate = nil
            }
            dataManager.save()
        }
    }
}

// MARK: - 底部操作栏
struct BottomActionBar: View {
    let onAddTask: () -> Void
    let onTaskConfig: () -> Void
    let onHistory: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ActionButton(
                title: "添加任务",
                icon: "plus.circle.fill",
                color: .green,
                action: onAddTask
            )

            ActionButton(
                title: "任务配置",
                icon: "slider.horizontal.3",
                color: .blue,
                action: onTaskConfig
            )

            ActionButton(
                title: "历史记录",
                icon: "clock.arrow.circlepath",
                color: .purple,
                action: onHistory
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
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
                Section(header: Text("任务信息")) {
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
                    Section(header: Text("固定任务说明")) {
                        Text("固定任务将每天自动生成，您可以在任务配置中管理所有固定任务。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("预设任务")) {
                    PresetTaskButton(
                        title: "跑步30分钟",
                        type: .exercise,
                        amount: 20
                    ) { title, type, amount in
                        self.title = title
                        self.selectedTaskType = type
                        self.rewardAmount = amount
                    }

                    PresetTaskButton(
                        title: "阅读1小时",
                        type: .reading,
                        amount: 15
                    ) { title, type, amount in
                        self.title = title
                        self.selectedTaskType = type
                        self.rewardAmount = amount
                    }

                    PresetTaskButton(
                        title: "冥想15分钟",
                        type: .meditation,
                        amount: 10
                    ) { title, type, amount in
                        self.title = title
                        self.selectedTaskType = type
                        self.rewardAmount = amount
                    }

                    PresetTaskButton(
                        title: "学习2小时",
                        type: .study,
                        amount: 30
                    ) { title, type, amount in
                        self.title = title
                        self.selectedTaskType = type
                        self.rewardAmount = amount
                    }
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                
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
                .font(.title2)
                .fontWeight(.medium)
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

// MARK: - 固定任务配置视图
struct FixedTaskConfigView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController

    @FetchRequest(
        entity: FixedTaskTemplate.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FixedTaskTemplate.title, ascending: true)],
        animation: .default)
    private var taskTemplates: FetchedResults<FixedTaskTemplate>

    @State private var showingAddTemplate = false
    @State private var editingTemplate: FixedTaskTemplate?

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("固定任务模板")) {
                    ForEach(taskTemplates, id: \.id) { template in
                        FixedTaskTemplateRow(template: template) {
                            editingTemplate = template
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                deleteTemplate(template)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }

                Section(header: Text("预设模板")) {
                    PresetTemplateButton(
                        title: "跑步30分钟",
                        type: .exercise,
                        amount: 20
                    ) { title, type, amount in
                        addPresetTemplate(title: title, type: type, amount: amount)
                    }

                    PresetTemplateButton(
                        title: "阅读1小时",
                        type: .reading,
                        amount: 15
                    ) { title, type, amount in
                        addPresetTemplate(title: title, type: type, amount: amount)
                    }

                    PresetTemplateButton(
                        title: "冥想15分钟",
                        type: .meditation,
                        amount: 10
                    ) { title, type, amount in
                        addPresetTemplate(title: title, type: type, amount: amount)
                    }

                    PresetTemplateButton(
                        title: "学习2小时",
                        type: .study,
                        amount: 30
                    ) { title, type, amount in
                        addPresetTemplate(title: title, type: type, amount: amount)
                    }
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

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTemplate = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTemplate) {
                AddFixedTaskTemplateView()
            }
            .sheet(item: $editingTemplate) { template in
                EditFixedTaskTemplateView(template: template)
            }
        }
    }

    private func deleteTemplate(_ template: FixedTaskTemplate) {
        viewContext.delete(template)
        dataManager.save()
    }

    private func addPresetTemplate(title: String, type: TaskType, amount: Double) {
        let fetch: NSFetchRequest<FixedTaskTemplate> = FixedTaskTemplate.fetchRequest()
        fetch.predicate = NSPredicate(format: "title == %@", title)

        if let existing = try? viewContext.fetch(fetch), existing.isEmpty {
            let template = FixedTaskTemplate(context: viewContext)
            template.id = UUID()
            template.title = title
            template.taskType = type.rawValue
            template.rewardAmount = amount
            template.isActive = true
            dataManager.save()
        }
    }
}

// MARK: - 任务历史视图
struct TaskHistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var tasksForSelectedDate: [DailyTask] = []

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

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
                            DailyTaskRow(task: task)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("历史补打卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadTasksForDate(selectedDate)
            }
            .onChange(of: selectedDate) { newDate in
                loadTasksForDate(newDate)
            }
        }
    }

    private func loadTasksForDate(_ date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let fetchRequest: NSFetchRequest<DailyTask> = DailyTask.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "(taskDate >= %@) AND (taskDate < %@)", startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DailyTask.isFixed, ascending: false), NSSortDescriptor(keyPath: \DailyTask.createdDate, ascending: true)]

        if let tasks = try? viewContext.fetch(fetchRequest) {
            tasksForSelectedDate = tasks
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
                            .font(.subheadline)
                            .fontWeight(.medium)
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
                    .font(.subheadline)
                    .fontWeight(.medium)

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
                Section(header: Text("模板信息")) {
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
                Section(header: Text("模板信息")) {
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

struct DailyTasksView_Previews: PreviewProvider {
    static var previews: some View {
        DailyTasksView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(PersistenceController.preview)
    }
}
