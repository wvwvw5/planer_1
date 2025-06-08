import SwiftUI

struct EditTaskView: View {
    @Binding var task: TaskItem
    var onSave: (TaskItem) -> Void
    var onCancel: () -> Void
    @State private var showingLocationPicker = false
    @State private var reminderType: ReminderType = .none
    @State private var category: TaskCategory
    @EnvironmentObject var categoryManager: CategoryManager
    
    init(task: Binding<TaskItem>, onSave: @escaping (TaskItem) -> Void, onCancel: @escaping () -> Void) {
        self._task = task
        self.onSave = onSave
        self.onCancel = onCancel
        self._reminderType = State(initialValue: task.wrappedValue.reminderType)
        self._category = State(initialValue: task.wrappedValue.category)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("basic_info".localized)) {
                    TextField("task_title".localized, text: $task.title)
                    TextField("task_description".localized, text: $task.description)
                    DatePicker("due_date".localized, selection: $task.dueDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("priority".localized)) {
                    Picker("priority".localized, selection: $task.priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.localized).tag(priority)
                    }
                }
                }
                
                Section(header: Text("category".localized)) {
                    Picker("category".localized, selection: $category) {
                        ForEach(TaskCategory.standardCategories, id: \.self) { category in
                            Text(category.localized).tag(category)
                        }
                        ForEach(CategoryManager.shared.customCategories, id: \.self) { custom in
                            Text(custom).tag(TaskCategory.custom(custom))
                        }
                    }
                }
                
                Section(header: Text("visibility".localized)) {
                    Toggle("private_task".localized, isOn: $task.isPrivate)
                }
                
                Section(header: Text("location".localized)) {
                    if let location = task.location {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(location.address)
                                    .font(.subheadline)
                                Text("\(location.latitude), \(location.longitude)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button(action: {
                                task.location = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                            Text(task.location == nil ? "add_location".localized : "edit_location".localized)
                    }
                }
                }
                
                Section(header: Text("reminder".localized)) {
                    Picker("notification".localized, selection: $reminderType) {
                        ForEach(ReminderType.allCases) { type in
                            Text(type.rawValue.localized).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("edit_task".localized)
            .navigationBarItems(
                leading: Button("cancel".localized) {
                        onCancel()
                },
                trailing: Button("save".localized) {
                    var updatedTask = task
                    updatedTask.reminderType = reminderType
                    updatedTask.category = category
                    onSave(updatedTask)
                }
                .disabled(task.title.isEmpty)
            )
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $task.location)
            }
            .onAppear {
                reminderType = task.reminderType
            }
        }
    }
}
