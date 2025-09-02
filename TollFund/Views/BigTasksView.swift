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
    @State private var showingDetailView = false
    
    var taskStatus: BigTaskStatus {
        BigTaskStatus(rawValue: task.status ?? "") ?? .notStarted
    }
    
    var body: some View {
        Button(action: { showingDetailView = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题和状态
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title ?? "未知挑战")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let description = task.taskDescription, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        // 类别和子类别标签
                        if let category = task.category, let subcategory = task.subcategory {
                            HStack(spacing: 4) {
                                Text(category)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                                
                                Text(subcategory)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(taskStatus.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(taskStatus.color.opacity(0.2))
                            .foregroundColor(taskStatus.color)
                            .clipShape(Capsule())
                        
                        Text("¥\(task.rewardAmount, specifier: "%.0f")")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                
                // 进度条
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("进度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(task.progress * 100, specifier: "%.0f")%")
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    ProgressView(value: task.progress)
                        .tint(taskStatus.color)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetailView) {
            BigTaskDetailView(task: task)
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
    @State private var editedCategory: ChallengeCategory?
    @State private var editedSubcategory: ChallengeSubcategory?
    
    var computedStatus: BigTaskStatus {
        if editedProgress <= 0 {
            return .notStarted
        } else if editedProgress >= 1.0 {
            return .completed
        } else {
            return .inProgress
        }
    }
    
    init(task: BigTask) {
        self.task = task
        self._editedTitle = State(initialValue: task.title ?? "")
        self._editedDescription = State(initialValue: task.taskDescription ?? "")
        self._editedRewardAmount = State(initialValue: task.rewardAmount)
        self._editedProgress = State(initialValue: task.progress)
        self._editedCategory = State(initialValue: ChallengeCategory(rawValue: task.category ?? ""))
        self._editedSubcategory = State(initialValue: ChallengeSubcategory(rawValue: task.subcategory ?? ""))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("挑战信息")) {
                    TextField("挑战标题", text: $editedTitle)
                    
                    TextField("描述（可选）", text: $editedDescription)
                        .lineLimit(3)
                }
                
                Section(header: Text("类别设置")) {
                    CategorySelectionView(
                        selectedCategory: $editedCategory,
                        selectedSubcategory: $editedSubcategory,
                        rewardAmount: $editedRewardAmount
                    )
                }
                
                Section(header: Text("奖励和进度")) {
                    HStack {
                        Text("奖励金额")
                        Spacer()
                        TextField("金额", value: $editedRewardAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("进度")
                            Spacer()
                            Text("\(editedProgress * 100, specifier: "%.0f")%")
                                .font(.system(size: 15, weight: .medium))
                        }
                        
                        Slider(value: $editedProgress, in: 0...1, step: 0.01) {
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
                        .tint(computedStatus.color)
                        .onChange(of: editedProgress) { _ in
                            saveChanges()
                        }
                    }
                }
                
                Section(header: Text("状态和时间")) {
                    HStack {
                        Text("当前状态")
                        Spacer()
                        Text(computedStatus.rawValue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(computedStatus.color.opacity(0.2))
                            .foregroundColor(computedStatus.color)
                            .clipShape(Capsule())
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
            .navigationTitle("编辑挑战")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        task.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        task.taskDescription = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        task.rewardAmount = editedRewardAmount
        task.progress = editedProgress
        task.status = computedStatus.rawValue
        task.category = editedCategory?.rawValue
        task.subcategory = editedSubcategory?.rawValue
        
        // 如果任务完成了，设置完成日期
        if computedStatus == .completed && task.completedDate == nil {
            task.completedDate = Date()
        } else if computedStatus != .completed {
            task.completedDate = nil
        }
        
        do {
            try viewContext.save()
            print("✅ 挑战更新成功: \(task.title ?? "") - 进度: \(editedProgress * 100)% - 状态: \(computedStatus.rawValue)")
        } catch {
            print("❌ 保存挑战失败: \(error)")
        }
    }
}

struct AddBigTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController
    
    @State private var title = ""
    @State private var description = ""
    @State private var rewardAmount = 100.0
    @State private var selectedCategory: ChallengeCategory?
    @State private var selectedSubcategory: ChallengeSubcategory?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("任务信息")) {
                    TextField("任务标题", text: $title)
                    TextField("任务描述", text: $description)
                        .lineLimit(3)
                }
                
                Section(header: Text("类别设置")) {
                    CategorySelectionView(
                        selectedCategory: $selectedCategory,
                        selectedSubcategory: $selectedSubcategory,
                        rewardAmount: $rewardAmount
                    )
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
            .navigationTitle("添加挑战")
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
                    .disabled(title.isEmpty || selectedCategory == nil || selectedSubcategory == nil)
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
        newTask.category = selectedCategory?.rawValue
        newTask.subcategory = selectedSubcategory?.rawValue
        newTask.status = BigTaskStatus.notStarted.rawValue
        newTask.progress = 0.0
        newTask.createdDate = Date()
        
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
                        .font(.system(size: 15, weight: .medium))
                    
                    Spacer()
                    
                    Text("¥\(amount, specifier: "%.0f")")
                        .foregroundColor(.green)
                        .font(.system(size: 15, weight: .medium))
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
            
            Text("还没有\(status.rawValue)的挑战")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("点击右上角的 + 按钮添加你的第一个挑战")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 类别选择组件
struct CategorySelectionView: View {
    @Binding var selectedCategory: ChallengeCategory?
    @Binding var selectedSubcategory: ChallengeSubcategory?
    @Binding var rewardAmount: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // 类别选择
            VStack(alignment: .leading, spacing: 8) {
                Text("类别 *")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Menu {
                    ForEach(ChallengeCategory.allCases, id: \.self) { category in
                        Button(category.rawValue) {
                            selectedCategory = category
                            selectedSubcategory = nil // 重置子类别
                            rewardAmount = 0 // 重置金额，等待子类别选择
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCategory?.rawValue ?? "请选择类别")
                            .foregroundColor(selectedCategory == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // 子类别选择 (依赖类别选择)
            if let category = selectedCategory {
                VStack(alignment: .leading, spacing: 8) {
                    Text("子类别 *")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Menu {
                        ForEach(category.subcategories, id: \.self) { subcategory in
                            Button(subcategory.rawValue) {
                                selectedSubcategory = subcategory
                                rewardAmount = subcategory.defaultRewardAmount // 自动设置奖励金额
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedSubcategory?.rawValue ?? "请选择子类别")
                                .foregroundColor(selectedSubcategory == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            
            // 显示默认奖励金额
            if let subcategory = selectedSubcategory {
                HStack {
                    Text("默认奖励:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("¥\(Int(subcategory.defaultRewardAmount))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
        }
    }
}

struct BigTasksView_Previews: PreviewProvider {
    static var previews: some View {
        BigTasksView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(PersistenceController.preview)
    }
}
