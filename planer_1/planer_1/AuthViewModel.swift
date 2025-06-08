import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import FirebaseStorage

class AuthViewModel: ObservableObject {
    @Published var errorMessage: String = ""
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var profileImage: UIImage?

    init() {
        userSession = Auth.auth().currentUser
        fetchUserData()
        loadProfileImage()
    }

    func login(email: String, password: String) {
        errorMessage = ""
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = self.parseError(error)
                } else if let user = result?.user {
                    self.userSession = user
                    self.isLoggedIn = true
                    self.fetchUserData()
                }
            }
        }
    }

    func register(email: String, password: String, login: String) {
        errorMessage = ""
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = self.parseError(error)
                } else if let user = result?.user {
                    // Сохраняем профиль пользователя
                    let profile = ["email": email, "login": login]
                    Firestore.firestore().collection("users").document(user.uid).setData(profile)
                    self.userSession = user
                    self.isLoggedIn = true
                    self.fetchUserData()
                }
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            isLoggedIn = false
        } catch {
            self.errorMessage = "auth_logout_error".localized
        }
    }

    private func parseError(_ error: Error) -> String {
        let err = error as NSError
        switch err.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return "auth_invalid_email".localized
        case AuthErrorCode.userNotFound.rawValue:
            return "auth_user_not_found".localized
        case AuthErrorCode.wrongPassword.rawValue:
            return "auth_wrong_password".localized
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "auth_email_in_use".localized
        case AuthErrorCode.weakPassword.rawValue:
            return "auth_weak_password".localized
        default:
            return err.localizedDescription
        }
    }

    func signIn(withEmail email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            self.userSession = result?.user
            self.fetchUserData()
        }
    }
    
    func createUser(withEmail email: String, password: String, fullname: String, login: String) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            guard let firebaseUser = result?.user else { return }
            
            let user = User(id: firebaseUser.uid,
                          fullname: fullname,
                          email: email,
                          login: login)
            
            // Сохраняем данные пользователя в Firestore
            Firestore.firestore().collection("users").document(firebaseUser.uid).setData([
                "fullname": fullname,
                "email": email,
                "login": login
            ])
            
            self.userSession = firebaseUser
            self.currentUser = user
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
            self.profileImage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func loadProfileImage() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Сначала пробуем загрузить из кэша
        if let cachedImageData = UserDefaults.standard.data(forKey: "profileImage"),
           let cachedImage = UIImage(data: cachedImageData) {
            self.profileImage = cachedImage
        }
        
        // Затем обновляем из Firebase
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] document, error in
            if let error = error {
                print("DEBUG: Ошибка загрузки данных пользователя: \(error.localizedDescription)")
                return
            }
            
            if let photoURLString = document?.data()?["photoURL"] as? String,
               let photoURL = URL(string: photoURLString) {
                URLSession.shared.dataTask(with: photoURL) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self?.profileImage = image
                            UserDefaults.standard.set(data, forKey: "profileImage")
                        }
                    }
                }.resume()
            }
        }
    }
    
    func loadProfileImage(from photoURL: String) {
        guard let url = URL(string: photoURL) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImage = image
                    UserDefaults.standard.set(data, forKey: "profileImage")
                }
            }
        }.resume()
    }
    
    func fetchUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Загружаем данные пользователя из Firestore
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] document, error in
            if let error = error {
                print("DEBUG: Ошибка загрузки данных пользователя: \(error.localizedDescription)")
                return
            }
            
            if let document = document, document.exists {
                let data = document.data()
                if let fullname = data?["fullname"] as? String,
                   let email = data?["email"] as? String,
                   let login = data?["login"] as? String {
                    self?.currentUser = User(id: uid, fullname: fullname, email: email, login: login)
                }
                
                // Загружаем фото профиля
                self?.loadProfileImage()
            }
        }
    }
    
    func updateProfileImage(_ image: UIImage) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Сначала получаем информацию о текущем фото
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
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
            let fileName = "\(uid)_\(timestamp)_\(randomString).jpg"
            
            let storageRef = Storage.storage().reference().child("profile_images/\(fileName)")
            
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
            
            // Сохраняем фото в Storage
            storageRef.putData(imageData, metadata: nil) { [weak self] metadata, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("DEBUG: Ошибка загрузки фото: \(error.localizedDescription)")
                    return
                }
                
                // Получаем URL загруженного фото
                storageRef.downloadURL { [weak self] url, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("DEBUG: Ошибка получения URL фото: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let downloadURL = url else { return }
                    
                    // Обновляем URL фото в Firestore
                    Firestore.firestore().collection("users").document(uid).updateData([
                        "photoURL": downloadURL.absoluteString,
                        "photoFileName": fileName
                    ]) { error in
                        if let error = error {
                            print("DEBUG: Ошибка обновления URL фото: \(error.localizedDescription)")
                            return
                        }
                        
                        // Обновляем локальное фото
                        DispatchQueue.main.async {
                            UserDefaults.standard.removeObject(forKey: "profileImage")
                            self.profileImage = image
                        }
                        // Принудительно загружаем новое фото из Firebase
                        if let url = url {
                            self.loadProfileImage(from: url.absoluteString)
                        }
                    }
                }
            }
        }
    }
    
    func changePassword(currentPassword: String, newPassword: String, completion: @escaping (Bool, String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false, "auth_not_authorized".localized)
            return
        }
        
        // Сначала переавторизуем пользователя
        let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: currentPassword)
        
        user.reauthenticate(with: credential) { result, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            // Затем меняем пароль
            user.updatePassword(to: newPassword) { error in
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                completion(true, nil)
            }
        }
    }
    
    func updateUserProfile(fullname: String, completion: @escaping (Bool, String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false, "auth_not_authorized".localized)
            return
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = fullname
        
        changeRequest.commitChanges { error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            self.currentUser?.fullname = fullname
            completion(true, nil)
        }
    }
}
