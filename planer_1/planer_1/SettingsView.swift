import SwiftUI
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showingImagePicker = false
    @State private var showingPasswordChange = false
    @State private var showingLanguagePicker = false
    @State private var showingLogoutAlert = false
    @State private var showingPasswordChangeSuccess = false
    @State private var showingPhotoUpdateSuccess = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var uploadTask: StorageUploadTask?
    
    // Добавляем state переменные для логина и почты
    @State private var userLogin: String = "Загрузка..."
    @State private var userEmail: String = ""
    
    let languages = ["Русский", "English"]
    let themes = ["theme_light", "theme_dark"]
    
    @AppStorage("appTheme") var appTheme: String = "theme_light"
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    // Секция профиля
                    Section(header: Text("profile".localized)) {
                        HStack {
                            if let profileImage = authViewModel.profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(userLogin)
                                    .font(.headline)
                                Text(userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                        .onAppear {
                            fetchUserData()
                        }
                        
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            Label("change_profile_photo".localized, systemImage: "photo")
                        }
                        
                        Button(action: {
                            showingPasswordChange = true
                        }) {
                            Label("change_password".localized, systemImage: "lock")
                        }
                    }
                    
                    // Секция приложения
                    Section(header: Text("app".localized)) {
                        // Выбор языка
                        HStack {
                            Label("language".localized, systemImage: "globe")
                            Spacer()
                            Menu {
                                ForEach(languages, id: \.self) { language in
                                    Button(action: {
                                        languageManager.setLanguage(language == "Русский" ? "ru" : "en")
                                    }) {
                                        HStack {
                                            Text(language)
                                            if (language == "Русский" && languageManager.currentLanguage == "ru") ||
                                               (language == "English" && languageManager.currentLanguage == "en") {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Text(languageManager.currentLanguage == "ru" ? "Русский" : "English")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Выбор темы
                        HStack {
                            Label("theme".localized, systemImage: "paintbrush")
                            Spacer()
                            Menu {
                                Button(action: {
                                    appTheme = "theme_light"
                                }) {
                                    HStack {
                                        Text("theme_light".localized)
                                        if appTheme == "theme_light" {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                
                                Button(action: {
                                    appTheme = "theme_dark"
                                }) {
                                    HStack {
                                        Text("theme_dark".localized)
                                        if appTheme == "theme_dark" {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            } label: {
                                Text(appTheme == "theme_light" ? "theme_light".localized : "theme_dark".localized)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Управление категориями
                        NavigationLink(destination: CategoriesView()) {
                            Label("categories".localized, systemImage: "folder")
                        }
                    }
                    
                    // Секция аккаунта
                    Section {
                        Button(action: {
                            authViewModel.signOut()
                        }) {
                            HStack {
                                Label("logout".localized, systemImage: "arrow.right.square")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
                
                if isUploading {
                    VStack(spacing: 16) {
                        ProgressView(value: uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .padding()
                        Text("photo_uploading".localized)
                        Button("cancel".localized) {
                            uploadTask?.cancel()
                            isUploading = false
                        }
                        .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationTitle("settings".localized)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $authViewModel.profileImage, onImageSelected: { image in
                    if let image = image {
                        uploadProfileImage(image)
                    }
                })
            }
            .sheet(isPresented: $showingPasswordChange) {
                ChangePasswordView(showingPasswordChangeSuccess: $showingPasswordChangeSuccess)
            }
            .alert(isPresented: $showingLogoutAlert) {
                Alert(
                    title: Text("logout".localized),
                    message: Text("logout_confirm".localized),
                    primaryButton: .destructive(Text("logout".localized)) {
                        authViewModel.signOut()
                    },
                    secondaryButton: .cancel(Text("cancel".localized))
                )
            }
            .alert(isPresented: $showingPasswordChangeSuccess) {
                Alert(
                    title: Text("success".localized),
                    message: Text("password_changed".localized),
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
        }
    }
    
    private func fetchUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        print("DEBUG: SettingsView - Fetching user data for uid: \(uid)")
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("DEBUG: SettingsView - Error fetching user data: \(error.localizedDescription)")
                self.userLogin = "no_data".localized
                self.userEmail = ""
                return
            }
            
            if let data = snapshot?.data() {
                self.userLogin = data["login"] as? String ?? "Без логина"
                self.userEmail = data["email"] as? String ?? ""
                let photoURL = data["photoURL"] as? String
                print("DEBUG: SettingsView - Fetched user data - login: \(self.userLogin), email: \(self.userEmail), photoURL: \(photoURL ?? "nil")")
                
                // Обновляем фото профиля через AuthViewModel
                if let photoURL = photoURL {
                    self.authViewModel.loadProfileImage(from: photoURL)
                } else {
                    self.authViewModel.profileImage = nil
                }
            } else {
                print("DEBUG: SettingsView - No data found for user")
                self.userLogin = "no_data".localized
                self.userEmail = ""
                self.authViewModel.profileImage = nil
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        
        print("DEBUG: Начинаем загрузку фото профиля")
        
        // Сначала получаем информацию о текущем фото
        Firestore.firestore().collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("DEBUG: Ошибка получения данных пользователя: \(error.localizedDescription)")
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
            
            self.isUploading = true
            self.uploadProgress = 0.0
            
            let uploadTask = storageRef.putData(imageData, metadata: metadata)
            self.uploadTask = uploadTask
            
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    self.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    print("DEBUG: Прогресс загрузки: \(self.uploadProgress * 100)%")
                }
            }
            
            uploadTask.observe(.success) { _ in
                print("DEBUG: Фото успешно загружено в Storage")
                self.isUploading = false
                
                storageRef.downloadURL { result in
                    switch result {
                    case .success(let photoURL):
                        let photoURLString = photoURL.absoluteString
                        print("DEBUG: Получен URL фото: \(photoURLString)")
                        
                        // Обновляем URL фото в Firestore
                        let db = Firestore.firestore()
                        db.collection("users").document(userId).updateData([
                            "photoURL": photoURLString,
                            "photoFileName": fileName
                        ]) { error in
                            if let error = error {
                                print("DEBUG: Ошибка сохранения URL в Firestore: \(error.localizedDescription)")
                                return
                            }
                            
                            // Обновляем фото в AuthViewModel
                            DispatchQueue.main.async {
                                UserDefaults.standard.removeObject(forKey: "profileImage")
                                self.authViewModel.profileImage = image
                                self.showingPhotoUpdateSuccess = true
                                // Принудительно загружаем новое фото
                                self.authViewModel.loadProfileImage(from: photoURLString)
                                // Обновляем данные пользователя
                                self.authViewModel.fetchUserData()
                            }
                        }
                    case .failure(let error):
                        print("DEBUG: Ошибка получения URL фото: \(error.localizedDescription)")
                    }
                }
            }
            
            uploadTask.observe(.failure) { snapshot in
                self.isUploading = false
                if let error = snapshot.error {
                    print("DEBUG: Ошибка загрузки фото: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct ChangePasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var showingPasswordChangeSuccess: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("change_password".localized)) {
                    SecureField("current_password".localized, text: $currentPassword)
                    SecureField("new_password".localized, text: $newPassword)
                    SecureField("confirm_new_password".localized, text: $confirmPassword)
                }
                
                Section {
                    Button("save".localized) {
                        if newPassword != confirmPassword {
                            alertMessage = "passwords_do_not_match".localized
                            showingAlert = true
                            return
                        }
                        if newPassword.count < 6 {
                            alertMessage = "password_too_short".localized
                            showingAlert = true
                            return
                        }
                        authViewModel.changePassword(currentPassword: currentPassword, newPassword: newPassword) { success, error in
                            if success {
                                presentationMode.wrappedValue.dismiss()
                                showingPasswordChangeSuccess = true
                            } else {
                                alertMessage = error ?? "password_change_error".localized
                                showingAlert = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("change_password".localized)
            .navigationBarItems(trailing: Button("cancel".localized) {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("error".localized), message: Text(alertMessage), dismissButton: .default(Text("ok".localized)))
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    var onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onImageSelected(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 
