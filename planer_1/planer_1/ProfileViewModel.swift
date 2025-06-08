import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class ProfileViewModel: ObservableObject {
    @Published var userTasks: [TaskItem] = []
    @Published var userData: (login: String, email: String, photoURL: String?)? = nil
    @Published var isSubscribed = false
    @Published var isLoadingSubscription = false
    @Published var followerCount = 0
    @Published var followingCount = 0
    @Published var isLoadingTasks = true
    
    // Состояния для копирования задач
    @Published var showingCopySuccess = false
    @Published var showingCopyError = false
    @Published var copyErrorMessage = ""
    @Published var selectedTask: TaskItem? // Выбранная задача для копирования
    
    var userId: String
    var currentUserId: String? = Auth.auth().currentUser?.uid
    
    private var userListener: ListenerRegistration?
    
    init(userId: String) {
        self.userId = userId
        // fetchUserData() // Заменяем на слушатель
        startUserListener()
        fetchFollowerCount(for: userId)
        fetchFollowingCount(for: userId)
        checkSubscription()
        fetchUserTasks()
    }
    
    deinit {
        userListener?.remove()
    }
    
    // MARK: - Start User Data Listener
    private func startUserListener() {
        let db = Firestore.firestore()
        userListener = db.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("DEBUG: Error fetching user data in ProfileView: \(error.localizedDescription)")
                self.userData = nil // Очищаем данные при ошибке
                return
            }
            
            if let data = snapshot?.data(),
               let login = data["login"] as? String,
               let email = data["email"] as? String {
                let photoURL = data["photoURL"] as? String
                print("DEBUG: Fetched photoURL: \(String(describing: photoURL))")
                self.userData = (
                    login: login,
                    email: email,
                    photoURL: photoURL
                )
            } else {
                self.userData = nil // Очищаем данные, если документ не существует
            }
        }
    }

    // MARK: - Fetch Follower Count
    private func fetchFollowerCount(for userId: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("subscribers").addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self else { return }
            self.followerCount = snapshot?.documents.count ?? 0
            print("DEBUG: Follower count for \(userId): \(self.followerCount)")
        }
    }

    // MARK: - Fetch Following Count
    private func fetchFollowingCount(for userId: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("followings").addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self else { return }
            self.followingCount = snapshot?.documents.count ?? 0
            print("DEBUG: Following count for \(userId): \(self.followingCount)")
        }
    }

    private func checkSubscription() {
        guard let currentUserId = currentUserId, currentUserId != userId else { return }
        isLoadingSubscription = true
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("subscribers").document(currentUserId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoadingSubscription = false
            if let error = error {
                print("DEBUG: Ошибка проверки подписки: \(error.localizedDescription)")
                self.isSubscribed = false
                return
            }
            self.isSubscribed = snapshot?.exists ?? false
            print("DEBUG: Subscription status for user \(self.userId) by \(currentUserId): \(self.isSubscribed)")
        }
    }

    public func subscribe() {
        guard let currentUserId = currentUserId else { return }
        isLoadingSubscription = true
        let db = Firestore.firestore()
        
        // Добавляем запись в subscribers у целевого пользователя
        db.collection("users").document(userId).collection("subscribers").document(currentUserId).setData([ "date": Timestamp(date: Date()) ]) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("DEBUG: Ошибка добавления подписчика: \(error.localizedDescription)")
                self.isLoadingSubscription = false
                return
            }
            print("DEBUG: Пользователь \(currentUserId) успешно подписан на \(self.userId)")
            // Добавляем запись в followings у текущего пользователя
            db.collection("users").document(currentUserId).collection("followings").document(self.userId).setData([ "date": Timestamp(date: Date()) ]) { [weak self] error in
                guard let self = self else { return }
                self.isLoadingSubscription = false
                if let error = error {
                    print("DEBUG: Ошибка добавления подписки: \(error.localizedDescription)")
                    return
                }
                print("DEBUG: Пользователь \(currentUserId) успешно добавил подписку на \(self.userId)")
                self.isSubscribed = true
            }
        }
    }

    public func unsubscribe() {
        guard let currentUserId = currentUserId else { return }
        isLoadingSubscription = true
        let db = Firestore.firestore()
        
        // Удаляем запись из subscribers у целевого пользователя
        db.collection("users").document(userId).collection("subscribers").document(currentUserId).delete { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("DEBUG: Ошибка удаления подписчика: \(error.localizedDescription)")
                self.isLoadingSubscription = false
                return
            }
            print("DEBUG: Пользователь \(currentUserId) успешно отписан от \(self.userId)")
            // Удаляем запись из followings у текущего пользователя
            db.collection("users").document(currentUserId).collection("followings").document(self.userId).delete { [weak self] error in
                guard let self = self else { return }
                self.isLoadingSubscription = false
                if let error = error {
                    print("DEBUG: Ошибка удаления подписки: \(error.localizedDescription)")
                    return
                }
                print("DEBUG: Пользователь \(currentUserId) успешно удалил подписку на \(self.userId)")
                self.isSubscribed = false
            }
        }
    }

    private func fetchUserTasks() {
        print("DEBUG: Начало загрузки задач для пользователя: \(userId)")
        isLoadingTasks = true // Начинаем загрузку
        let db = Firestore.firestore()
        db.collection("tasks")
            .whereField("userId", isEqualTo: userId)
            .whereField("isPrivate", isEqualTo: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoadingTasks = false // Завершаем загрузку после получения данных
                
                if let error = error {
                    print("DEBUG: Ошибка загрузки задач пользователя: \(error.localizedDescription)")
                    // Возможно, стоит отобразить ошибку пользователю
                    return
                }
                
                if let documents = snapshot?.documents {
                    print("DEBUG: Получено \(documents.count) документов из Firestore для пользователя \(self.userId)")
                    self.userTasks = documents.compactMap { doc in
                        var data = doc.data()
                        data["id"] = doc.documentID
                        return TaskItem(from: data)
                    }
                    print("DEBUG: Успешно распарсено \(self.userTasks.count) задач для пользователя \(self.userId)")
                } else {
                    print("DEBUG: Документы из Firestore не получены или snapshot == nil для пользователя \(self.userId)")
                    self.userTasks = []
                }
            }
    }

    public func checkAndCopyTask() {
        guard let task = selectedTask,
              let currentUserId = currentUserId else { return }
        
        let db = Firestore.firestore()
        
        // Проверяем, существует ли уже такая задача
        db.collection("tasks")
            .whereField("userId", isEqualTo: currentUserId)
            .whereField("originalTaskId", isEqualTo: task.id) // Assuming task.id is the original taskId
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("DEBUG: Ошибка проверки существования задачи: \(error.localizedDescription)")
                    self.copyErrorMessage = "Ошибка при проверке задачи"
                    self.showingCopyError = true
                    return
                }
                
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    print("DEBUG: Задача уже существует")
                    self.copyErrorMessage = "Такая задача уже добавлена в ваш список"
                    self.showingCopyError = true
                    return
                }
                
                // Если задачи нет, копируем её
                self.copyTask()
            }
    }

    // MARK: - Copy Task
    private func copyTask() {
        guard let task = selectedTask,
              let currentUserId = currentUserId else { return }
        
        let db = Firestore.firestore()
        var taskData = task.dictionary
        taskData["userId"] = currentUserId // ID текущего пользователя
        taskData["id"] = UUID().uuidString // Новый ID для копии
        taskData["isPrivate"] = true // По умолчанию делаем приватной
        if let taskId = task.id {
            taskData["originalTaskId"] = taskId // Сохраняем ID оригинальной задачи
        }
        taskData["originalUserId"] = userId // Сохраняем ID автора оригинальной задачи
        
        db.collection("tasks").document(taskData["id"] as! String).setData(taskData) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("DEBUG: Ошибка копирования задачи: \(error.localizedDescription)")
                self.copyErrorMessage = "Ошибка при копировании задачи"
                self.showingCopyError = true
                return
            }
            print("DEBUG: Задача успешно скопирована")
            self.showingCopySuccess = true
        }
    }

    public func fetchUserData() {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("DEBUG: Error fetching user data: \(error.localizedDescription)")
                self.userData = nil
                return
            }
            
            if let data = snapshot?.data(),
               let login = data["login"] as? String,
               let email = data["email"] as? String {
                let photoURL = data["photoURL"] as? String
                print("DEBUG: Fetched photoURL: \(String(describing: photoURL))")
                self.userData = (
                    login: login,
                    email: email,
                    photoURL: photoURL
                )
            } else {
                self.userData = nil
            }
        }
    }

    func loadProfileImage(from photoURL: String, completion: ((UIImage?) -> Void)? = nil) {
        guard let url = URL(string: photoURL) else {
            completion?(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("DEBUG: Ошибка загрузки фото профиля: \(error.localizedDescription)")
                completion?(nil)
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion?(image)
                }
            } else {
                completion?(nil)
            }
        }.resume()
    }
    
    func updateProfileImage(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(false, "Ошибка подготовки изображения")
            return
        }
        
        print("DEBUG: Начинаем загрузку фото профиля")
        
        // Сначала получаем информацию о текущем фото
        Firestore.firestore().collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("DEBUG: Ошибка получения данных пользователя: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            // Если есть старое фото, удаляем его
            if let oldFileName = document?.data()?["photoFileName"] as? String {
                let oldStorageRef = Storage.storage().reference().child("profile_images/\(oldFileName)")
                oldStorageRef.delete { error in
                    if let error = error {
                        print("DEBUG: Ошибка удаления старого фото: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Старое фото успешно удалено")
                    }
                }
            }
            
            // Генерируем уникальное имя файла для нового фото
            let timestamp = Int(Date().timeIntervalSince1970)
            let randomString = String(format: "%08x", arc4random())
            let fileName = "\(userId)_\(timestamp)_\(randomString).jpg"
            
            let storage = Storage.storage()
            let storageRef = storage.reference().child("profile_images/\(fileName)")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            // Загружаем новое фото
            storageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("DEBUG: Ошибка загрузки фото: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                
                // Получаем URL загруженного фото
                storageRef.downloadURL { url, error in
                    if let error = error {
                        print("DEBUG: Ошибка получения URL фото: \(error.localizedDescription)")
                        completion(false, error.localizedDescription)
                        return
                    }
                    
                    guard let photoURL = url else {
                        completion(false, "Не удалось получить URL фото")
                        return
                    }
                    
                    let photoURLString = photoURL.absoluteString
                    print("DEBUG: Получен URL фото: \(photoURLString)")
                    
                    // Обновляем URL фото в Firestore
                    Firestore.firestore().collection("users").document(userId).updateData([
                        "photoURL": photoURLString,
                        "photoFileName": fileName
                    ]) { error in
                        if let error = error {
                            print("DEBUG: Ошибка сохранения URL в Firestore: \(error.localizedDescription)")
                            completion(false, error.localizedDescription)
                            return
                        }
                        
                        // Обновляем данные пользователя
                        self.fetchUserData()
                        completion(true, nil)
                    }
                }
            }
        }
    }
} 