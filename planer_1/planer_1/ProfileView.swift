import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode
    let userId: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentUserId: String? = Auth.auth().currentUser?.uid
    @State private var showingSettings = false
    @State private var showingPhotoUpdateSuccess = false
    @State private var showUserSearch = false
    @State private var showFollowers = false
    @State private var showFollowing = false

    @StateObject private var viewModel: ProfileViewModel
    @State private var showingTaskActionSheet = false
    @State private var showingTaskDetail = false

    init(userId: String) {
        self.userId = userId
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(userId: userId))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Блок кнопок профиля и действий
                VStack(spacing: 12) {
                    // Кнопка-профиль (визуально выделена, не открывает ничего)
                    Button(action: {}) {
                        HStack(spacing: 12) {
                            if let photoURLString = viewModel.userData?.photoURL, let url = URL(string: photoURLString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure(_):
                                        Image(systemName: "person.crop.circle").resizable().foregroundColor(.blue)
                                    @unknown default:
                                        Image(systemName: "person.crop.circle").resizable().foregroundColor(.blue)
                                    }
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .frame(width: 64, height: 64)
                                    .foregroundColor(.blue)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.userData?.login ?? "-")
                                    .font(.headline)
                                Text(viewModel.userData?.email ?? "-")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                HStack(spacing: 8) {
                                    Text("followers_count".localized + ": \(viewModel.followerCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("following_count".localized + ": \(viewModel.followingCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    .disabled(true)

                    // Кнопка поиска пользователей
                    Button(action: { showUserSearch = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.blue)
                            Text("find_user_by_login".localized)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    // Кнопка подписчики
                    Button(action: { showFollowers = true }) {
                        HStack {
                            Image(systemName: "person.2.fill").foregroundColor(.blue)
                            Text("followers".localized)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    // Кнопка подписки
                    Button(action: { showFollowing = true }) {
                        HStack {
                            Image(systemName: "person.3.fill").foregroundColor(.blue)
                            Text("following".localized)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }

                Text("public_tasks".localized)
                    .font(.headline)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Отображение загрузки или списка задач
                Group {
                    if viewModel.isLoadingTasks && viewModel.userTasks.isEmpty {
                        ProgressView("loading_tasks".localized)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if viewModel.userTasks.isEmpty {
                        Text("no_public_tasks".localized)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        LazyVStack(alignment: .leading) {
                            ForEach(viewModel.userTasks.filter { !$0.isPrivate }) { task in // Используем userTasks из ViewModel
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.headline)
                                    if !task.description.isEmpty {
                                        Text(task.description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(task.dueDateFormatted)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle()) // Делаем всю область кликабельной
                                .onTapGesture {
                                    viewModel.selectedTask = task // Обновляем selectedTask в ViewModel
                                    showingTaskActionSheet = true
                                }
                                Divider()
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("profile".localized)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSettings) {
                ProfileSettingsView(userId: userId, showingPhotoUpdateSuccess: $showingPhotoUpdateSuccess, viewModel: viewModel)
            }
            .sheet(isPresented: $showingTaskDetail) {
                if let task = viewModel.selectedTask { // Используем selectedTask из ViewModel
                    NavigationView {
                        TaskDetailView(task: task)
                    }
                }
            }
            .sheet(isPresented: $showUserSearch) {
                UserSearchView()
            }
            .sheet(isPresented: $showFollowers) {
                FollowersListView()
            }
            .sheet(isPresented: $showFollowing) {
                FollowingListView()
            }
            .actionSheet(isPresented: $showingTaskActionSheet) {
                ActionSheet(
                    title: Text("choose_action".localized),
                    buttons: [
                        .default(Text("view".localized)) {
                            showingTaskDetail = true
                        },
                        .default(Text("add_to_my_tasks".localized)) {
                            viewModel.checkAndCopyTask()
                        },
                        .cancel()
                    ]
                )
            }
            .alert(isPresented: $viewModel.showingCopySuccess) {
                Alert(
                    title: Text("success".localized),
                    message: Text("task_added_success".localized),
                    dismissButton: .default(Text("ok".localized))
                )
            }
            .alert(isPresented: $viewModel.showingCopyError) {
                Alert(
                    title: Text("error".localized),
                    message: Text(viewModel.copyErrorMessage),
                    dismissButton: .default(Text("ok".localized))
                )
            }
            .alert(isPresented: $showingPhotoUpdateSuccess) {
                Alert(
                    title: Text("success".localized),
                    message: Text("profile_photo_updated".localized),
                    dismissButton: .default(Text("ok".localized))
                )
            }
            .onAppear { // Убираем вызовы функций, они теперь в init ViewModel
//                print("DEBUG: ProfileView onAppear вызван для пользователя: \(userId)")
//                fetchUserData()
//                fetchFollowerCount(for: userId)
//                fetchFollowingCount(for: userId)
//                checkSubscription()
//                fetchUserTasks()
            }
        }
    }
}

struct ProfileSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var login = ""
    @State private var email = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var showAlert = false
    @State private var alertMessage = ""
    var userId: String
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var uploadTask: StorageUploadTask?
    @Binding var showingPhotoUpdateSuccess: Bool
    var viewModel: ProfileViewModel
    @State private var hasChanges = false

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Фото профиля")) {
                        HStack {
                            Spacer()
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                        .padding(.vertical)
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Text("Изменить фото")
                        }
                    }

                    Section(header: Text("Основная информация")) {
                        TextField("Логин", text: $login)
                            .onChange(of: login) { _ in hasChanges = true }
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: email) { _ in hasChanges = true }
                    }

                    Section(header: Text("Изменить пароль")) {
                        SecureField("Текущий пароль", text: $currentPassword)
                            .onChange(of: currentPassword) { _ in hasChanges = true }
                        SecureField("Новый пароль", text: $newPassword)
                            .onChange(of: newPassword) { _ in hasChanges = true }
                        SecureField("Подтвердите пароль", text: $confirmPassword)
                            .onChange(of: confirmPassword) { _ in hasChanges = true }
                    }

                    Section {
                        Button("Сохранить изменения") {
                            saveChanges()
                        }
                        .disabled(!hasChanges)
                    }
                }
                if isUploading {
                    VStack(spacing: 16) {
                        ProgressView(value: uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .padding()
                        Text("Загрузка фото...")
                        Button("Отмена") {
                            uploadTask?.cancel()
                            isUploading = false
                        }
                        .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationTitle("Настройки")
            .navigationBarItems(trailing: Button("Готово") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                loadUserData()
            }
            .onChange(of: selectedItem) { newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            profileImage = image
                            hasChanges = true
                        }
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Уведомление"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func loadUserData() {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("DEBUG: ProfileSettingsView - Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data() {
                self.login = data["login"] as? String ?? "Без логина"
                self.email = data["email"] as? String ?? ""
                
                // Загружаем фото профиля через AuthViewModel
                if let photoURL = data["photoURL"] as? String {
                    self.viewModel.loadProfileImage(from: photoURL) { image in
                        DispatchQueue.main.async {
                            self.profileImage = image
                        }
                    }
                }
            }
        }
    }

    private func saveChanges() {
        print("DEBUG: saveChanges вызван")
        guard !login.isEmpty else {
            alertMessage = "Логин не может быть пустым"
            showAlert = true
            return
        }

        guard !email.isEmpty else {
            alertMessage = "Email не может быть пустым"
            showAlert = true
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)

        // Обновляем данные в Firestore
        userRef.updateData([
            "login": login,
            "email": email
        ]) { error in
            if let error = error {
                alertMessage = "Ошибка обновления данных: \(error.localizedDescription)"
                showAlert = true
                return
            }
        }

        // Обновляем пароль, если он был изменен
        if !newPassword.isEmpty {
            guard newPassword == confirmPassword else {
                alertMessage = "Пароли не совпадают"
                showAlert = true
                return
            }

            guard let user = Auth.auth().currentUser else { return }

            // Сначала переаутентифицируем пользователя
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            user.reauthenticate(with: credential) { _, error in
                if let error = error {
                    alertMessage = "Ошибка аутентификации: \(error.localizedDescription)"
                    showAlert = true
                    return
                }

                // Затем меняем пароль
                user.updatePassword(to: newPassword) { error in
                    if let error = error {
                        alertMessage = "Ошибка смены пароля: \(error.localizedDescription)"
                        showAlert = true
                        return
                    }
                }
            }
        }

        // Обновляем фото профиля, если оно было изменено
        if let image = profileImage {
            print("DEBUG: Обнаружено измененное фото. Начинаем загрузку.")
            self.viewModel.updateProfileImage(image) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.showingPhotoUpdateSuccess = true
                        self.hasChanges = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.alertMessage = error ?? "Ошибка обновления фото"
                        self.showAlert = true
                    }
                }
            }
        } else {
            // Если фото не было изменено, просто обновляем остальные данные
            alertMessage = "Изменения сохранены"
            showAlert = true
            hasChanges = false
        }
    }
} 