import SwiftUI
import CoreData

struct ExpensesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataManager: PersistenceController
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
        animation: .default)
    private var expenses: FetchedResults<Expense>
    
    @State private var showingAddExpense = false
    @State private var selectedCategory: ExpenseCategory? = nil
    @State private var editingExpense: Expense?
    
    var filteredExpenses: [Expense] {
        if let selectedCategory = selectedCategory {
            return expenses.filter { expense in
                ExpenseCategory(rawValue: expense.category ?? "") == selectedCategory
            }
        } else {
            return Array(expenses)
        }
    }
    
    var totalExpense: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 总消费卡片
                ExpenseSummaryCard(totalExpense: totalExpense, selectedCategory: selectedCategory)
                
                // 类别筛选器
                CategoryFilterScrollView(selectedCategory: $selectedCategory)
                
                if filteredExpenses.isEmpty {
                    ExpenseEmptyStateView(selectedCategory: selectedCategory)
                } else {
                    List {
                        ForEach(filteredExpenses, id: \.id) { expense in
                            ExpenseRow(expense: expense, onDelete: deleteExpense)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingExpense = expense
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("消费记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddExpense = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
            }
            .sheet(item: $editingExpense) { expense in
                EditExpenseView(expense: expense)
            }
        }
    }
    
    private func deleteExpenses(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredExpenses[$0] }.forEach(viewContext.delete)
            dataManager.save()
        }
    }

    private func deleteExpense(_ expense: Expense) {
        withAnimation {
            viewContext.delete(expense)
            dataManager.save()
        }
    }
}

struct ExpenseSummaryCard: View {
    let totalExpense: Double
    let selectedCategory: ExpenseCategory?
    
    var body: some View {
        VStack(spacing: 8) {
            if let category = selectedCategory {
                Text("\(category.rawValue)消费")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else {
                Text("总消费")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Text("¥\(totalExpense, specifier: "%.2f")")
                .font(.largeTitle)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct CategoryFilterScrollView: View {
    @Binding var selectedCategory: ExpenseCategory?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 按钮
                CategoryFilterButton(
                    title: "全部",
                    icon: "list.bullet",
                    color: .blue,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                
                // 各类别按钮
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    CategoryFilterButton(
                        title: category.rawValue,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryFilterButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExpenseRow: View {
    @ObservedObject var expense: Expense
    var onDelete: (Expense) -> Void

    var expenseCategory: ExpenseCategory {
        ExpenseCategory(rawValue: expense.category ?? "") ?? .other
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 类别图标
            Image(systemName: expenseCategory.icon)
                .font(.title2)
                .foregroundColor(expenseCategory.color)
                .frame(width: 30)
            
            // 消费内容
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title ?? "未知消费")
                    .font(.headline)
                
                HStack {
                    Text(expenseCategory.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(expenseCategory.color.opacity(0.2))
                        .foregroundColor(expenseCategory.color)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    if let date = expense.date {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 金额
            Text("¥\(expense.amount, specifier: "%.2f")")
                .font(.headline)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(expense)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

struct AddExpenseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController
    
    @State private var title = ""
    @State private var amount = 0.0
    @State private var selectedCategory = ExpenseCategory.other
    @State private var date = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("消费信息")) {
                    TextField("消费内容", text: $title)
                    
                    HStack {
                        Text("金额")
                        Spacer()
                        TextField("金额", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元")
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("消费类别", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    DatePicker("消费日期", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("添加消费记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveExpense()
                    }
                    .disabled(title.isEmpty || amount <= 0)
                }
            }
        }
    }
    
    private func saveExpense() {
        let newExpense = Expense(context: viewContext)
        newExpense.id = UUID()
        newExpense.title = title
        newExpense.amount = amount
        newExpense.category = selectedCategory.rawValue
        newExpense.date = date
        
        dataManager.save()
        dismiss()
    }
}


struct ExpenseEmptyStateView: View {
    let selectedCategory: ExpenseCategory?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            if let category = selectedCategory {
                Text("还没有\(category.rawValue)消费记录")
                    .font(.title2)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Text("还没有消费记录")
                    .font(.title2)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text("点击右上角的 + 按钮添加你的第一笔消费记录")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 编辑消费视图
struct EditExpenseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: PersistenceController

    @ObservedObject var expense: Expense

    @State private var title: String
    @State private var selectedCategory: ExpenseCategory
    @State private var amount: Double
    @State private var date: Date
    @State private var showingDeleteAlert = false
    @State private var isEditingAmount = false

    init(expense: Expense) {
        self.expense = expense
        self._title = State(initialValue: expense.title ?? "")
        self._selectedCategory = State(initialValue: ExpenseCategory(rawValue: expense.category ?? "") ?? .other)
        self._amount = State(initialValue: expense.amount)
        self._date = State(initialValue: expense.date ?? Date())
    }

    var body: some View {
        NavigationView {
            Form {
                Section("消费信息") {
                    TextField("消费标题", text: $title)

                    Picker("类别", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon).foregroundColor(category.color)
                                Text(category.rawValue)
                            }.tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    HStack {
                        Text("金额")
                        Spacer()
                        if isEditingAmount {
                            TextField("输入金额", value: $amount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .onSubmit {
                                    isEditingAmount = false
                                }
                        } else {
                            Button(action: {
                                isEditingAmount = true
                            }) {
                                Text("¥\(amount, specifier: "%.2f")")
                                    .foregroundColor(.red)
                                    .font(.system(size: 17, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        Text("元").foregroundColor(.secondary)
                    }

                    DatePicker("消费日期", selection: $date, displayedComponents: .date)
                }

                Section {
                    Button("保存修改") {
                        saveChanges()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }

                Section {
                    Button("删除消费", role: .destructive) {
                        showingDeleteAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .alert("确认删除", isPresented: $showingDeleteAlert) {
                        Button("取消", role: .cancel) { }
                        Button("删除", role: .destructive) {
                            deleteExpense()
                        }
                    } message: {
                        Text("确定要删除这条消费记录吗？此操作无法撤销。")
                    }
                }
            }
            .navigationTitle("编辑消费")
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        expense.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.category = selectedCategory.rawValue
        expense.amount = amount
        expense.date = date

        do {
            try viewContext.save()
            print("✅ 消费编辑保存成功")
        } catch {
            print("❌ 保存消费编辑失败: \(error)")
        }
    }

    private func deleteExpense() {
        viewContext.delete(expense)
        do {
            try viewContext.save()
            print("✅ 消费删除成功")
        } catch {
            print("❌ 删除消费失败: \(error)")
        }
        dismiss()
    }
}

struct ExpensesView_Previews: PreviewProvider {
    static var previews: some View {
        ExpensesView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(PersistenceController.preview)
    }
}
