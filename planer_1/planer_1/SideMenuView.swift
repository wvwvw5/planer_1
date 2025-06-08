import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SideMenuView: View {
    var onProfileTap: () -> Void
    var onLogout: () -> Void
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = true
    // --- Для отображения логина и email ---
    @State private var login: String = "loading".localized
    @State private var email: String = ""
    @State private var photoURL: String? = nil
    @State private var isLoadingUser = true
    @State private var showUserSearch = false
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAnalytics = false
    @Binding var showMenu: Bool
    @State private var showingFollowingList = false
    @State private var showingFollowersList = false
    var onSettingsTap: () -> Void
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showProfile = false
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var profileViewModel: ProfileViewModel?

    var body: some View {
        let screenHeight = UIScreen.main.bounds.height
        VStack(alignment: .leading, spacing: 20) {
            // Кнопка Профиль
            Button(action: {
                showProfile = true
            }) {
                HStack(spacing: 12) {
                    if let profileImage = authViewModel.profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authViewModel.currentUser?.login ?? "-")
                            .font(.headline)
                        Text(authViewModel.currentUser?.email ?? "-")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        HStack(spacing: 8) {
                            Text("followers_count".localized + ": \(profileViewModel?.followerCount ?? 0)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("following_count".localized + ": \(profileViewModel?.followingCount ?? 0)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                if let userId = authViewModel.currentUser?.id {
                    ProfileView(userId: userId)
                        .environmentObject(authViewModel)
                }
            }

            // Кнопка Поиск пользователей
            Button(action: {
                showUserSearch = true
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                    Text("find_user_by_login".localized)
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showUserSearch) {
                UserSearchView()
            }

            // Кнопка Подписчики
            Button(action: {
                showFollowers = true
            }) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.blue)
                    Text("followers".localized)
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showFollowers) {
                FollowersListView()
            }

            // Кнопка Подписки
            Button(action: {
                showFollowing = true
            }) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.blue)
                    Text("following".localized)
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showFollowing) {
                FollowingListView()
            }

            Spacer()

            // Кнопка 'Выйти' (всегда внизу)
            Button(action: {
                do {
                    try Auth.auth().signOut()
                    isLoggedIn = false
                } catch {
                    // обработка ошибки выхода
                }
            }) {
                HStack {
                    Image(systemName: "arrow.right.square.fill")
                    Text("logout".localized)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
            
            // Кнопка настроек внизу
            Button(action: {
                onSettingsTap()
            }) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                    Text("settings".localized)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.top, screenHeight * 0.08)
        .padding(.bottom, screenHeight * 0.08)
        .padding(.horizontal)
        .frame(maxHeight: .infinity)
        .background(Color(.systemBackground))
        .ignoresSafeArea(.all, edges: .vertical)
        .onAppear {
            fetchUserData()
            if let userId = authViewModel.currentUser?.id {
                profileViewModel = ProfileViewModel(userId: userId)
            }
        }
        .onChange(of: photoURL) { newValue in
            print("DEBUG: PhotoURL changed in SideMenuView: \(newValue ?? "nil")")
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsView()
        }
    }
    // --- Загрузка логина и email из Firestore ---
    private func fetchUserData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        print("DEBUG: Fetching user data for uid: \(uid)")
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("DEBUG: Error fetching user data: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data() {
                login = data["login"] as? String ?? "Без логина"
                email = data["email"] as? String ?? ""
                photoURL = data["photoURL"] as? String
                print("DEBUG: Fetched user data - login: \(login), email: \(email), photoURL: \(photoURL ?? "nil")")
            } else {
                print("DEBUG: No data found for user")
            }
            isLoadingUser = false
        }
    }
}

// Минимальный UserSearchView
struct UserSearchView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var searchLogin = ""
    @State private var foundUser: (id: String, login: String, photoURL: String?)? = nil
    @State private var searchError: String? = nil
    @State private var showProfile = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("auth_login_field".localized, text: $searchLogin)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("find_user".localized) {
                    searchUserByLogin()
                }
                if let error = searchError {
                    Text(error).foregroundColor(.red)
                }
                if let found = foundUser {
                    Button(action: { showProfile = true }) {
                        HStack {
                            if let urlString = found.photoURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .foregroundColor(.blue)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.blue)
                            }
                            Text(found.login)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("find_user".localized)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
            })
            .sheet(isPresented: $showProfile) {
                if let userId = foundUser?.id {
                    ProfileView(userId: userId)
                }
            }
        }
    }

    private func searchUserByLogin() {
        guard !searchLogin.isEmpty else {
            searchError = "enter_login".localized
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").whereField("login", isEqualTo: searchLogin).getDocuments { snapshot, error in
            if let error = error {
                searchError = error.localizedDescription
                return
            }
            
            if let doc = snapshot?.documents.first,
               let login = doc.data()["login"] as? String {
                let photoURL = doc.data()["photoURL"] as? String
                foundUser = (id: doc.documentID, login: login, photoURL: photoURL)
            } else {
                searchError = "user_not_found".localized
            }
        }
    }
}

