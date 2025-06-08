import SwiftUI

struct TaskListView: View {
    @StateObject private var viewModel = TaskViewModel()
    @EnvironmentObject var categoryManager: CategoryManager
    @State private var showingCompleted = false
    @State private var selectedTask: TaskItem?
    @State private var isEditing = false
    @State private var showingMenu = false
    @State private var shareContent: String?
    @State private var isSharePresented = false
    @State private var showingAddTask = false
    @State private var selectedCategory: TaskCategory?
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var showArchived = false
    
    var filteredTasks: [TaskItem] {
        let tasks = showingCompleted ? viewModel.completedTasks : viewModel.activeTasks
        let filtered: [TaskItem]
        if let category = selectedCategory, category != .all {
            filtered = tasks.filter { $0.category == category }
        } else {
            filtered = tasks
        }
        return filtered.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("tasks".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                // Переключатель Текущие/Архив
                Picker("", selection: $showingCompleted) {
                    Text("current_tasks".localized).tag(false)
                    Text("archive_tasks".localized).tag(true)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Фильтр по категориям через выпадающий список
                Picker("task_category".localized, selection: $selectedCategory) {
                    ForEach(TaskCategory.allCategories, id: \.self) { category in
                        Text(category.displayName.localized)
                            .tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                .padding(.bottom)
                
                // Кнопка для добавления новой пользовательской категории
                //                Button(action: {
                //                    showingAddCategory = true
                //                }) {
                //                    Text("add_category".localized)
                //                        .foregroundColor(.blue)
                //                }
                //                .padding(.bottom)
                //                .alert("new_category".localized, isPresented: $showingAddCategory) {
                //                    TextField("category_name".localized, text: $newCategoryName)
                //                    Button("cancel".localized, role: .cancel) {
                //                        newCategoryName = ""
                //                    }
                //                    Button("add".localized) {
                //                        if !newCategoryName.isEmpty {
                //                            //TaskCategory.addCustomCategory(newCategoryName)
                //                            // Вместо этого используем CategoryManager
                //                            CategoryManager.shared.addCategory(newCategoryName)
                //                            newCategoryName = ""
                //                        }
                //                    }
                //                } message: {
                //                    Text("enter_new_category".localized)
                //                }
                
//                Toggle(isOn: $showArchived) {
//                    Text(showArchived ? "task_archived".localized : "status_active".localized)
//                }
                
                List {
                    ForEach(filteredTasks) { task in
                        TaskRow(
                            task: task,
                            onToggleCompletion: { _ in
                                viewModel.toggleCompletion(task)
                        }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteTask(task)
                            } label: {
                                Label("delete".localized, systemImage: "trash")
                            }
                            
                            Button {
                                selectedTask = task
                            isEditing = true
                            } label: {
                                Label("edit".localized, systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationBarItems(trailing:
                Button(action: {
                    showingAddTask = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            )
        }
        .sheet(isPresented: $isEditing) {
            if let selected = selectedTask {
                    EditTaskView(
                    task: Binding(
                        get: { selected },
                        set: { selectedTask = $0 }
                    ),
                        onSave: { updatedTask in
                        viewModel.updateTask(updatedTask)
                            isEditing = false
                        },
                        onCancel: {
                            isEditing = false
                        }
                    )
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView { newTask in
                viewModel.addTask(newTask)
                }
            }
            .sheet(isPresented: $isSharePresented) {
                if let content = shareContent {
                    ShareSheet(items: [content])
            }
        }
    }

    private func shareTask(_ task: TaskItem) {
        shareContent = task.shareContent
        isSharePresented = true
    }
}
