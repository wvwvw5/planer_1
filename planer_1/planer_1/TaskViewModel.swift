import Foundation
import FirebaseAuth
import FirebaseFirestore
import UserNotifications


class TaskViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var publicTasks: [TaskItem] = [] // Публичные задачи других пользователей
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var publicListener: ListenerRegistration?
    private var originalTasksListeners: [String: ListenerRegistration] = [:]

    init() {
        fetchTasks()
        listenPublicTasks()
    }

    deinit {
        listener?.remove()
        publicListener?.remove()
        for (_, listener) in originalTasksListeners {
            listener.remove()
        }
        originalTasksListeners.removeAll()
    }

    // MARK: - Realtime listener для своих задач
    private func listenTasks() {
        guard let currentUser = Auth.auth().currentUser else { return }
        listener?.remove()
        listener = db.collection("tasks")
            .whereField("userId", isEqualTo: currentUser.uid)
            .addSnapshotListener { snapshot, error in
                if let documents = snapshot?.documents {
                    self.tasks = documents.compactMap { doc in
                        var data = doc.data()
                        data["id"] = doc.documentID
                        return TaskItem(from: data)
                    }
                    
                    self.updateOriginalTasksListeners()
                }
            }
    }

    // MARK: - Realtime listener для публичных задач других пользователей
    func listenPublicTasks() {
        guard let currentUser = Auth.auth().currentUser else { return }
        publicListener?.remove()
        publicListener = db.collection("tasks")
            .whereField("isPrivate", isEqualTo: false)
            .whereField("userId", isNotEqualTo: currentUser.uid)
            .addSnapshotListener { snapshot, error in
                if let documents = snapshot?.documents {
                    self.publicTasks = documents.compactMap { doc in
                        var data = doc.data()
                        data["id"] = doc.documentID
                        return TaskItem(from: data)
                    }
                }
            }
    }

    // MARK: - Add Task
    func addTask(_ task: TaskItem) {
        guard let currentUser = Auth.auth().currentUser else { return }

        var taskWithUser = task
        taskWithUser.userId = currentUser.uid
        
        // Генерируем ID перед сохранением, если его нет
        if taskWithUser.id == nil {
             taskWithUser.id = UUID().uuidString
        }
        
        guard let taskId = taskWithUser.id else { return } // Безопасное развертывание

        tasks.append(taskWithUser) // Добавляем в локальный массив только после получения ID

        db.collection("tasks")
            .document(taskId)
            .setData(taskWithUser.dictionary) { error in
                if let error = error {
                    print("Ошибка при сохранении задачи: \(error.localizedDescription)")
                }
            }

        scheduleNotification(for: taskWithUser)
    }

    // MARK: - Delete Task
    func deleteTask(_ task: TaskItem) {
        guard let _ = Auth.auth().currentUser else { return }
        guard let taskId = task.id else { return } // Безопасное развертывание

        tasks.removeAll { $0.id == task.id }

        db.collection("tasks")
            .document(taskId)
            .delete { error in
                if let error = error {
                    print("Ошибка при удалении задачи из Firestore: \(error.localizedDescription)")
                }
            }
    }

    // MARK: - Toggle Completion
    func toggleCompletion(_ task: TaskItem) {
        guard let _ = Auth.auth().currentUser else { return }
        guard let taskId = task.id else { return } // Безопасное развертывание

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            if tasks[index].isCompleted {
                tasks[index].completedAt = Date()
            } else {
                tasks[index].completedAt = nil
            }

            db.collection("tasks")
                .document(taskId)
                .updateData([
                    "isCompleted": tasks[index].isCompleted,
                    "completedAt": tasks[index].completedAt != nil ? Timestamp(date: tasks[index].completedAt!) : NSNull()
                ]) { error in
                    if let error = error {
                        print("Ошибка при обновлении статуса задачи: \(error.localizedDescription)")
                    }
                }
        }

        scheduleNotification(for: task)
    }

    // MARK: - Update Task
    func updateTask(_ task: TaskItem) {
        guard let _ = Auth.auth().currentUser else { return }
        guard let taskId = task.id else { return } // Безопасное развертывание

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task // task.id здесь уже сравнивается с опциональным task.id в массиве
        db.collection("tasks")
                .document(taskId)
                .setData(task.dictionary) { error in
                    if let error = error {
                        print("Ошибка при обновлении задачи: \(error.localizedDescription)")
                    }
                }
        }

        scheduleNotification(for: task)
    }

    // MARK: - Handle Shared Task Link
    func handleSharedTask(taskId: String, userId: String) {
        guard let currentUser = Auth.auth().currentUser else {
            print("DEBUG: Невозможно обработать ссылку: пользователь не авторизован.")
            // Возможно, перенаправить на экран авторизации или показать сообщение
            return
        }
        
        // Проверяем, не является ли задача уже скопированной пользователем
        let existingCopiedTask = tasks.first { $0.originalTaskId == taskId && $0.originalUserId == userId }
        if existingCopiedTask != nil {
            print("DEBUG: Задача с ID \(taskId) от пользователя \(userId) уже скопирована.")
            // Показать сообщение пользователю
            // Например, через @Published var latestMessage: String?
             // self.latestMessage = "Задача уже добавлена в ваш список."
            return
        }
        
        // Загружаем оригинальную задачу из Firestore
        db.collection("tasks")
            .document(taskId)
            .getDocument { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("DEBUG: Ошибка загрузки задачи по ссылке: \(error.localizedDescription)")
                    // Показать сообщение пользователю об ошибке загрузки
                     // self.latestMessage = "Ошибка загрузки задачи."
                    return
                }
                
                guard let document = documentSnapshot, document.exists else {
                    print("DEBUG: Задача с ID \(taskId) от пользователя \(userId) не найдена.")
                    // Показать сообщение пользователю, что задача не найдена
                     // self.latestMessage = "Задача не найдена или удалена."
                    return
                }
                
                var originalData = document.data() ?? [:]
                originalData["id"] = document.documentID // Убедимся, что ID оригинала корректен
                
                // Создаем новую TaskItem из данных оригинала
                var newTask = TaskItem(from: originalData)
                    // Устанавливаем новые параметры для копии
                    newTask.id = UUID().uuidString // Генерируем новый ID для копии
                    newTask.userId = currentUser.uid // Назначаем текущего пользователя
                    newTask.isPrivate = true // Копия по умолчанию приватная
                    newTask.isCompleted = false // Сбрасываем статус выполнения
                    newTask.originalTaskId = taskId // Сохраняем ID оригинала
                    newTask.originalUserId = userId // Сохраняем ID автора оригинала
                    
                    // Сохраняем новую задачу в Firestore
                    self.db.collection("tasks")
                        .document(newTask.id ?? UUID().uuidString)
                        .setData(newTask.dictionary) { error in
                            if let error = error {
                                print("DEBUG: Ошибка сохранения скопированной задачи из ссылки: \(error.localizedDescription)")
                                // Показать сообщение пользователю об ошибке сохранения
                                // self.latestMessage = "Не удалось добавить задачу."
                            } else {
                                print("DEBUG: Задача \(newTask.title) успешно добавлена из ссылки.")
                                // Опционально: обновить локальный массив задач немедленно
                                 self.tasks.append(newTask) // Добавляем локально, listener тоже обновит
                                // Показать сообщение пользователю об успехе
                                // self.latestMessage = "Задача успешно добавлена!"
                            }
                }
            }
    }

    // MARK: - Helpers
    func sortedTasks(_ byDate: Bool) -> [TaskItem] {
        if byDate {
            return tasks.sorted { $0.dueDate < $1.dueDate }
        }
        return tasks
    }

    var activeTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted && !$0.isArchived }
    }

    var completedTasks: [TaskItem] {
        tasks.filter { $0.isCompleted && !$0.isArchived }
    }

    var archivedTasks: [TaskItem] {
        tasks.filter { $0.isArchived }
    }

    func scheduleNotification(for task: TaskItem) {
        guard task.reminderType != .none,
              let taskId = task.id else { return }
        let content = UNMutableNotificationContent()
        content.title = task.title
        
        // Вычисляем время до срока выполнения
        var triggerDate = task.dueDate
        var timeIntervalDescription = ""
        
        switch task.reminderType {
        case .tenMinutes:
            triggerDate = task.dueDate.addingTimeInterval(-10 * 60)
            timeIntervalDescription = "10 минут"
        case .oneHour:
            triggerDate = task.dueDate.addingTimeInterval(-60 * 60)
            timeIntervalDescription = "1 час"
        case .oneDay:
            triggerDate = task.dueDate.addingTimeInterval(-24 * 60 * 60)
            timeIntervalDescription = "1 день"
        default:
            break
        }
        
        content.body = "Осталось \(timeIntervalDescription) до срока выполнения"
        content.sound = .default
        
        if triggerDate < Date() {
            // Показываем уведомление сразу
            let immediateTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: taskId, content: content, trigger: immediateTrigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Ошибка немедленного уведомления: \(error.localizedDescription)")
                }
            }
            return
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate), repeats: false)
        let request = UNNotificationRequest(identifier: taskId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Ошибка планирования уведомления: \(error.localizedDescription)")
            }
        }
    }

    func fetchTasks() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Слушаем изменения в задачах пользователя
        listener = Firestore.firestore()
            .collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("DEBUG: Ошибка загрузки задач: \(error.localizedDescription)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    self.tasks = documents.compactMap { doc in
                        var data = doc.data()
                        data["id"] = doc.documentID
                        return TaskItem(from: data)
                    }
                    
                    // Обновляем слушателей оригинальных задач
                    self.updateOriginalTasksListeners()
                    
                    // Обновляем данные виджета
                    // TaskWidgetDataManager.shared.saveTasks(self.activeTasks)
                }
            }
    }
    
    private func updateOriginalTasksListeners() {
        let currentOriginalTaskIds = Set(tasks.compactMap { $0.originalTaskId })
        
        for (taskId, listener) in originalTasksListeners {
            if !currentOriginalTaskIds.contains(taskId) {
                listener.remove()
                originalTasksListeners.removeValue(forKey: taskId)
            }
        }
        
        for task in tasks {
            guard let originalTaskId = task.originalTaskId,
                  originalTasksListeners[originalTaskId] == nil else { continue }

            // Если слушатель для этого originalTaskId еще не создан
            let listener = Firestore.firestore()
                .collection("tasks")
                .document(originalTaskId) // Слушаем конкретный документ
                .addSnapshotListener { [weak self] documentSnapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        print("DEBUG: Ошибка обновления оригинальной задачи \(originalTaskId): \(error.localizedDescription)")
                        return
                    }

                    guard let document = documentSnapshot, document.exists else {
                        print("DEBUG: Оригинальная задача \(originalTaskId) была удалена.")
                        // Возможно, стоит как-то обработать удаление оригинала (например, удалить связанные копии)
                        return
                    }

                    let originalData = document.data() ?? [:]

                    // Находим все скопированные задачи пользователя, ссылающиеся на этот originalTaskId
                    let copiedTasksToUpdate = self.tasks.filter { $0.originalTaskId == originalTaskId }

                    // Обновляем каждую найденную скопированную задачу в Firestore
                    for copiedTask in copiedTasksToUpdate {
                        self.updateCopiedTask(copiedTask, with: originalData)
                    }
                }

            originalTasksListeners[originalTaskId] = listener
        }
    }
    
    private func updateCopiedTask(_ copiedTask: TaskItem, with originalData: [String: Any]) {
        guard let taskId = copiedTask.id else { return }
        
        var updatedData = originalData
        updatedData["id"] = taskId
        updatedData["userId"] = Auth.auth().currentUser?.uid
        updatedData["isPrivate"] = copiedTask.isPrivate
        updatedData["originalTaskId"] = copiedTask.originalTaskId
        updatedData["originalUserId"] = copiedTask.originalUserId
        updatedData["isCompleted"] = copiedTask.isCompleted
        
        Firestore.firestore()
            .collection("tasks")
            .document(taskId)
            .updateData(updatedData) { error in
                if let error = error {
                    print("DEBUG: Ошибка обновления скопированной задачи: \(error.localizedDescription)")
                } else {
                    print("DEBUG: Скопированная задача \(taskId) успешно обновлена из оригинала \(copiedTask.originalTaskId ?? "")")
                    if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                        var localTask = TaskItem(from: updatedData)
                            localTask.isCompleted = copiedTask.isCompleted
                            localTask.isPrivate = copiedTask.isPrivate
                            self.tasks[index] = localTask
                    }
                }
            }
    }

    // MARK: - Archive Task
    func archiveTask(_ task: TaskItem) {
        guard let _ = Auth.auth().currentUser else { return }
        guard let taskId = task.id else { return }

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isArchived = true
            tasks[index].archivedAt = Date()

            db.collection("tasks")
                .document(taskId)
                .updateData([
                    "isArchived": true,
                    "archivedAt": Timestamp(date: tasks[index].archivedAt!)
                ]) { error in
                    if let error = error {
                        print("Ошибка при архивации задачи: \(error.localizedDescription)")
                    }
                }
        }
    }

    // MARK: - Check and Delete Old Archived Tasks
    func checkAndDeleteOldArchivedTasks() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let oldArchivedTasks = tasks.filter { task in
            guard let archivedAt = task.archivedAt else { return false }
            return task.isArchived && archivedAt < thirtyDaysAgo
        }
        
        for task in oldArchivedTasks {
            deleteTask(task)
        }
    }

    // MARK: - Archive Check Timer
    private var archiveCheckTimer: Timer?
    
    func startArchiveCheckTimer() {
        archiveCheckTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.checkAndDeleteOldArchivedTasks()
        }
    }
    
    func stopArchiveCheckTimer() {
        archiveCheckTimer?.invalidate()
        archiveCheckTimer = nil
    }
}
