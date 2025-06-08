import SwiftUI

struct TaskDetailView: View {
    let task: TaskItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Заголовок
                Text(task.title)
                    .font(.title)
                    .bold()
                
                // Описание
                if !task.description.isEmpty {
                    Text("description".localized + ":")
                        .font(.headline)
                    Text(task.description)
                        .font(.body)
                }
                
                // Приоритет
                HStack {
                    Text("priority".localized + ":")
                        .font(.headline)
                    Text(task.priority.localized)
                        .foregroundColor(task.priority.color)
                }
                
                // Категория
                HStack {
                    Text("category".localized + ":")
                        .font(.headline)
                    Text(task.category.localized)
                }
                
                // Срок выполнения
                HStack {
                    Text("due_date".localized + ":")
                        .font(.headline)
                    Text(task.dueDateFormatted)
                }
                
                // Напоминание
                if task.reminderType != .none {
                    HStack {
                        Text("reminder".localized + ":")
                            .font(.headline)
                        Text(task.reminderType.rawValue)
                    }
                }
                
                // Статус
                HStack {
                    Text("status".localized + ":")
                        .font(.headline)
                    Text(task.isCompleted ? "completed".localized : "in_progress".localized)
                }
                
                // Дата завершения
                if let completedAt = task.completedAt {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("completed".localized + ":")
                            .font(.headline)
                        Text(completedAt, style: .date)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)
                }
                
                // Дата архивации
                if task.isArchived {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.gray)
                        Text("archived".localized)
                            .font(.headline)
                        if let archivedAt = task.archivedAt {
                            Text("(\(archivedAt, style: .date))")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Приватность
                HStack {
                    Text("visibility".localized + ":")
                        .font(.headline)
                    Text(task.isPrivate ? "private".localized : "public".localized)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitle("task_details".localized, displayMode: .inline)
        .navigationBarItems(trailing: Button("close".localized) {
            presentationMode.wrappedValue.dismiss()
        })
    }
} 