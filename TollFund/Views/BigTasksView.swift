import SwiftUI
import CoreData

struct BigTasksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: PersistenceController
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BigTask.createdDate, ascending: false)],
        animation: .default)
    private var bigTasks: FetchedResults<BigTask>
    
    @State private var showingAddTask = false
    @State private var selectedStatus = BigTaskStatus.inProgress
    
    var filteredTasks: [BigTask] {
        bigTasks.filter { task in
            BigTaskStatus(rawValue: task.status ?? "") == selectedStatus
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 状态筛选器
                StatusFilterPicker(selectedStatus: $selectedStatus)
                
                if filteredTasks.isEmpty {
                    BigTaskEmptyStateView(status: selectedStatus)
                } else {
                    List {
                        ForEach(filteredTasks, id: \.id) { task in
                            BigTaskRow(task: task)
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("挑战")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddBigTaskView()
            }
        }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredTasks[$0] }.forEach(viewContext.delete)
            dataManager.save()
        }
    }
}

struct StatusFilterPicker: View {
    @Binding var selectedStatus: BigTaskStatus
    
    var body: some View {
        Picker("状态", selection: $selectedStatus) {
            ForEach(BigTaskStatus.allCases, id: \.self) { status in
                Text(status.rawValue)
                    .tag(status)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }
}

struct BigTaskRow: View {
    @ObservedObject var task: BigTask
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: PersistenceController
    @State private var editableTitle: String = ""
    @State private var editableDescription: String = ""
    @State private var editableRewardAmount: Double = 0
    @State private var editableProgress: Double = 0
    @State private var editableTargetDate: Date = Date()
    @State private var isInitialized = false
    
    var taskStatus: BigTaskStatus {
        if editableProgress <= 0 {
            return .notStarted
        } else if editableProgress >= 1.0 {
            return .completed
        } else {
            return .inProgress
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 可编辑标题
            TextField("挑战标题", text: $editableTitle)
                .font(.headline)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    saveChanges()
                }
            
            // 可编辑描述
            TextField("描述（可选）", text: $editableDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    saveChanges()
                }
            
            // 状态和奖励金额
            HStack {
                Text(taskStatus.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(taskStatus.color.opacity(0.2))
                    .foregroundColor(taskStatus.color)
                    .clipShape(Capsule())
                
                Spacer()
                
                HStack {
                    Text("¥")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    TextField("0", value: $editableRewardAmount, format: .number)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                        .onSubmit {
                            saveChanges()
                        }
                }
            }
            
            // 可拖动进度条
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("进度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(editableProgress * 100, specifier: "%.0f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Slider(value: $editableProgress, in: 0...1, step: 0.01) {
                    Text("进度")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .tint(taskStatus.color)
                .onChange(of: editableProgress) { _ in
                    // 进度变化时自动保存
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        saveChanges()
                    }
                }
            }
            
            // 目标日期选择
            HStack {
                Label("目标日期", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                DatePicker("", selection: $editableTargetDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: editableTargetDate) { _ in
                        saveChanges()
                    }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            initializeEditableValues()
        }
    }
    
    private func initializeEditableValues() {
        if !isInitialized {
            editableTitle = task.title ?? ""
            editableDescription = task.taskDescription ?? ""
            editableRewardAmount = task.rewardAmount
            editableProgress = task.progress
            editableTargetDate = task.targetDate ?? Date()
            isInitialized = true
        }
    }
    
    private func saveChanges() {
        task.title = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        task.taskDescription = editableDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        task.rewardAmount = editableRewardAmount
        task.progress = editableProgress
        task.targetDate = editableTargetDate
        task.status = taskStatus.rawValue
        
        // 如果任务完成了，设置完成日期
        if taskStatus == .completed && task.completedDate == nil {
            task.completedDate = Date()
        } else if taskStatus != .completed {
            task.completedDate = nil
        }
        
        do {
            try viewContext.save()
            print("✅ 挑战更新成功: \(task.title ?? "") - 进度: \(editableProgress * 100)% - 状态: \(taskStatus.rawValue)")
        } catch {
            print("❌ 保存挑战失败: \(error)")
        }
    }
}

struct BigTaskDetailView: View {
    @ObservedObject var task: BigTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: PersistenceController
    
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var editedRewardAmount: Double
    @State private var editedProgress: Double
    @State private var editedStatus: BigTaskStatus
    @State private var editedTargetDate: Date
    @State private var isEditing = false
    
    init(task: BigTask) {
        self.task = task
        self._editedTitle = State(initialValue: task.title ?? "")
        self._editedDescription = State(initialValue: task.taskDescription ?? "")
        self._editedRewardAmount = State(initialValue: task.rewardAmount)
        self._editedProgress = State(initialValue: task.progress)
        self._editedStatus = State(initialValue: BigTaskStatus(rawValue: task.status ?? "") ?? .notStarted)
        self._editedTargetDate = State(initialValue: task.targetDate ?? Date())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("任务信息")) {
                    if isEditing {
                        TextField("任务标题", text: $editedTitle)
                        TextField("任务描述", text: $editedDescription)
                            .lineLimit(3)
                    } else {
                        Text(task.title ?? "未知任务")
                            .font(.headline)
                        
                        if let description = task.taskDescription, !description.isEmpty {
                            Text(description)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("奖励和进度")) {
                    if isEditing {
                        HStack {
                            Text("奖励金额")
                            Spacer()
                            TextField("金额", value: $editedRewardAmount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("元")
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("进度: \(editedProgress * 100, specifier: "%.0f")%")
                            Slider(value: $editedProgress, in: 0...1, step: 0.1)
                        }
                    } else {
                        HStack {
                            Text("奖励金额")
                            Spacer()
                            Text("¥\(task.rewardAmount, specifier: "%.0f")")
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("进度")
                                Spacer()
                                Text("\(task.progress * 100, specifier: "%.0f")%")
                                    .fontWeight(.medium)
                            }
                            ProgressView(value: task.progress)
                                .tint(.blue)
                        }
                    }
                }
                
                Section(header: Text("状态和时间")) {
                    if isEditing {
                        Picker("状态", selection: $editedStatus) {
                            ForEach(BigTaskStatus.allCases, id: \.self) { status in
                                Text(status.rawValue)
                                    .tag(status)
                            }
                        }
                        
                        DatePicker("目标完成日期", selection: $editedTargetDate, displayedComponents: .date)
                    } else {
                        HStack {
                            Text("状态")
                            Spacer()
                            Text(BigTaskStatus(rawValue: task.status ?? "")?.rawValue ?? "未知")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((BigTaskStatus(rawValue: task.status ?? "") ?? .notStarted).color.opacity(0.2))
                                .foregroundColor((BigTaskStatus(rawValue: task.status ?? "") ?? .notStarted).color)
                                .clipShape(Capsule())
                        }
                        
                        if let targetDate = task.targetDate {
                            HStack {
                                Text("目标完成日期")
                                Spacer()
                                Text(targetDate, style: .date)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let createdDate = task.createdDate {
                            HStack {
                                Text("创建日期")
                                Spacer()
                                Text(createdDate, style: .date)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let completedDate = task.completedDate {
                            HStack {
                                Text("完成日期")
                                Spacer()
                                Text(completedDate, style: .date)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                if !isEditing {
                    Section {
                        Button(action: {
                            markAsCompleted()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("标记为已完成")
                            }
                            .foregroundColor(.green)
                        }
                        .disabled(BigTaskStatus(rawValue: task.status ?? "") == .completed)
                    }
                }
            }
            .navigationTitle("任务详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "取消" : "关闭") {
                        if isEditing {
                            isEditing = false
                            resetEditedValues()
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "保存" : "编辑") {
                        if isEditing {
                            saveChanges()
                        } else {
                            isEditing = true
                        }
                    }
                }
            }
        }
    }
    
    private func resetEditedValues() {
        editedTitle = task.title ?? ""
        editedDescription = task.taskDescription ?? ""
        editedRewardAmount = task.rewardAmount
        editedProgress = task.progress
        editedStatus = BigTaskStatus(rawValue: task.status ?? "") ?? .notStarted
        editedTargetDate = task.targetDate ?? Date()
    }
    
    private func saveChanges() {
        task.title = editedTitle
        task.taskDescription = editedDescription
        task.rewardAmount = editedRewardAmount
        task.progress = editedProgress
        task.status = editedStatus.rawValue
        task.targetDate = editedTargetDate
        
        dataManager.save()
        isEditing = false
    }
    
    private func markAsCompleted() {
        task.status = BigTaskStatus.completed.rawValue
        task.progress = 1.0
        task.completedDate = Date()
        
        dataManager.save()
    }
}

struct AddBigTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController
    
    @State private var title = ""
    @State private var description = ""
    @State private var rewardAmount = 100.0
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("任务信息")) {
                    TextField("任务标题", text: $title)
                    TextField("任务描述", text: $description)
                        .lineLimit(3)
                }
                
                Section(header: Text("奖励设置")) {
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
                
                Section(header: Text("时间设置")) {
                    DatePicker("目标完成日期", selection: $targetDate, displayedComponents: .date)
                }
                
                Section(header: Text("预设任务")) {
                    PresetBigTaskButton(
                        title: "完成Swift编程课程",
                        description: "学习完整的Swift编程语言和iOS开发",
                        amount: 500
                    ) { title, desc, amount in
                        self.title = title
                        self.description = desc
                        self.rewardAmount = amount
                    }
                    
                    PresetBigTaskButton(
                        title: "读完10本专业书籍",
                        description: "在指定时间内阅读完成10本专业相关书籍",
                        amount: 300
                    ) { title, desc, amount in
                        self.title = title
                        self.description = desc
                        self.rewardAmount = amount
                    }
                    
                    PresetBigTaskButton(
                        title: "完成毕业论文",
                        description: "按时完成高质量的毕业论文并通过答辩",
                        amount: 1000
                    ) { title, desc, amount in
                        self.title = title
                        self.description = desc
                        self.rewardAmount = amount
                    }
                }
            }
            .navigationTitle("添加大任务")
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
        let newTask = BigTask(context: viewContext)
        newTask.id = UUID()
        newTask.title = title
        newTask.taskDescription = description
        newTask.rewardAmount = rewardAmount
        newTask.status = BigTaskStatus.notStarted.rawValue
        newTask.progress = 0.0
        newTask.createdDate = Date()
        newTask.targetDate = targetDate
        
        dataManager.save()
        dismiss()
    }
}

struct PresetBigTaskButton: View {
    let title: String
    let description: String
    let amount: Double
    let onSelect: (String, String, Double) -> Void
    
    var body: some View {
        Button(action: {
            onSelect(title, description, amount)
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("¥\(amount, specifier: "%.0f")")
                        .foregroundColor(.green)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BigTaskEmptyStateView: View {
    let status: BigTaskStatus
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("还没有\(status.rawValue)的大任务")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("点击右上角的 + 按钮添加你的第一个大任务")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BigTasksView_Previews: PreviewProvider {
    static var previews: some View {
        BigTasksView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(PersistenceController.preview)
    }
}
