import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FollowingListView: View {
    @State private var following: [(id: String, login: String, photoURL: String?)] = []
    @State private var isLoading = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if following.isEmpty {
                    Text("no_following".localized)
                        .foregroundColor(.gray)
                } else {
                    List(following, id: \.id) { user in
                        NavigationLink(destination: ProfileView(userId: user.id)) {
                            HStack {
                                if let photoURL = user.photoURL, let url = URL(string: photoURL) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        case .failure(_):
                                            Image(systemName: "person.crop.circle")
                                                .resizable()
                                                .foregroundColor(.blue)
                                        @unknown default:
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
                                
                                Text(user.login)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("following".localized)
            .navigationBarItems(trailing: Button("close".localized) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            fetchFollowing()
        }
    }
    
    private func fetchFollowing() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).collection("followings").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching following: \(error.localizedDescription)")
                isLoading = false
                return
            }
            let followingIds = snapshot?.documents.map { $0.documentID } ?? []
            let group = DispatchGroup()
            var tempFollowing: [(id: String, login: String, photoURL: String?)] = []
            for followingId in followingIds {
                group.enter()
                db.collection("users").document(followingId).getDocument { snapshot, error in
                    defer { group.leave() }
                    if let data = snapshot?.data() {
                        let login = data["login"] as? String ?? "Unknown"
                        let photoURL = data["photoURL"] as? String
                        tempFollowing.append((id: followingId, login: login, photoURL: photoURL))
                    }
                }
            }
            group.notify(queue: .main) {
                following = tempFollowing
                isLoading = false
            }
        }
    }
} 