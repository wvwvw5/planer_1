import SwiftUI
import FirebaseAuth
import ActivityKit

struct TaskRow: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var taskViewModel: TaskViewModel
    let task: TaskItem
    var onToggleCompletion: (TaskItem) -> Void

    @State private var isSharing = false
    @State private var shareUrl: URL?
    @State private var itemToShare: ShareItem? = nil

    private var priorityColor: Color {
        switch task.priority {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }

    var body: some View {
        HStack {
            Button(action: {
                onToggleCompletion(task)
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(BorderlessButtonStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                if !task.description.isEmpty {
                    Text(task.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                        .lineLimit(2)
                }
                if let location = task.location {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                        Text(location.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                HStack {
                    Text(task.category.localized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text(task.priority.localized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text(task.dueDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if task.isArchived {
                        HStack {
                            Image(systemName: "archivebox.fill")
                                .foregroundColor(.gray)
                            Text("archived".localized)
                                .font(.caption)
                                .foregroundColor(.gray)
                            if let archivedAt = task.archivedAt {
                                Text("(\(archivedAt, style: .date))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                if let completedAt = task.completedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("completed".localized + ":")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(completedAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            Spacer()

            Button(action: {
                if let taskId = task.id {
                    let userId = task.userId
                    let urlString = "planerapp://task?taskId=\(taskId)&userId=\(userId)"
                    if let url = URL(string: urlString) {
                        itemToShare = ShareItem(url: url)
                    } else {
                        print("DEBUG: Не удалось создать URL для шаринга: \(urlString)")
                    }
                } else {
                    print("DEBUG: Невозможно расшарить задачу без ID.")
                }
            }) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())

        .sheet(item: $itemToShare) { shareItem in
             ShareSheet(items: [shareItem.url])
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
