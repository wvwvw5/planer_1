import SwiftUI
import CoreLocation

struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var categoryManager: CategoryManager
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var priority = TaskPriority.medium
    @State private var location: TaskItem.Location?
    @State private var showingLocationPicker = false
    @State private var isPrivate = true
    @State private var reminderType: ReminderType = .none
    @State private var category: TaskCategory = .study

    var onSave: (TaskItem) -> Void

    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                prioritySection
                categorySection
                locationSection
                visibilitySection
                reminderSection
            }
            .navigationTitle("add_task".localized)
            .navigationBarItems(
                leading: Button("cancel".localized) {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("save".localized) {
                    let task = TaskItem(
                        id: UUID().uuidString,
                        title: title,
                        description: description,
                        dueDate: dueDate,
                        priority: priority,
                        category: category,
                        isCompleted: false,
                        isPrivate: isPrivate,
                        userId: "", // Временно пустая строка, userId будет установлен при сохранении в TaskViewModel
                        location: location,
                        reminderType: reminderType,
                        originalTaskId: nil,
                        originalUserId: nil,
                        isArchived: false,
                        archivedAt: nil
                    )
                    onSave(task)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(title.isEmpty)
            )
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $location)
            }
        }
    }
    
    private var basicInfoSection: some View {
        Section(header: Text("basic_info".localized)) {
            TextField("task_title".localized, text: $title)
            TextEditor(text: $description)
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if description.isEmpty {
                            Text("task_description".localized)
                                .foregroundColor(.gray)
                                .padding(.leading, 4)
                                .padding(.top, 8)
                        }
                    },
                    alignment: .topLeading
                )
            DatePicker("due_date".localized, selection: $dueDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
        }
    }
    
    private var prioritySection: some View {
        Section(header: Text("priority".localized)) {
            Picker("priority".localized, selection: $priority) {
                Text("priority_low".localized).tag(TaskPriority.low)
                Text("priority_medium".localized).tag(TaskPriority.medium)
                Text("priority_high".localized).tag(TaskPriority.high)
                }
            }
    }
    
    private var categorySection: some View {
        Section(header: Text("category".localized)) {
            Picker("category".localized, selection: $category) {
                Text("category_all".localized).tag(TaskCategory.all)
                ForEach(TaskCategory.standardCategories, id: \.self) { category in
                    Text(category.displayName.localized).tag(category)
                }
                ForEach(CategoryManager.shared.customCategories, id: \.self) { custom in
                    Text(custom).tag(TaskCategory.custom(custom))
                }
            }
        }
    }
    
    private var locationSection: some View {
        Section(header: Text("location".localized)) {
            if let location = location {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    Text(location.address)
                }
            }
            
            Button(action: {
                showingLocationPicker = true
            }) {
                Text(location == nil ? "add_location".localized : "edit_location".localized)
            }
        }
    }
    
    private var visibilitySection: some View {
        Section(header: Text("visibility".localized)) {
            Toggle("private_task".localized, isOn: $isPrivate)
                    }
                }

    private var reminderSection: some View {
        Section(header: Text("reminder".localized)) {
            Picker("notification".localized, selection: $reminderType) {
                ForEach(ReminderType.allCases) { type in
                    Text(type.rawValue.localized).tag(type)
                    }
                }
            .pickerStyle(.menu)
        }
    }
}
