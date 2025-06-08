import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FollowersListView: View {
    @State private var followers: [(id: String, login: String, photoURL: String?)] = []
    @State private var isLoading = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if followers.isEmpty {
                    Text("no_followers".localized)
                        .foregroundColor(.gray)
                } else {
                    List(followers, id: \.id) { follower in
                        NavigationLink(destination: ProfileView(userId: follower.id)) {
                            HStack {
                                if let photoURL = follower.photoURL, let url = URL(string: photoURL) {
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
                                
                                Text(follower.login)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("followers".localized)
            .navigationBarItems(trailing: Button("close".localized) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            fetchFollowers()
        }
    }
    
    private func fetchFollowers() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        db.collection("users").document(currentUserId).collection("subscribers").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching followers: \(error.localizedDescription)")
                isLoading = false
                return
            }
            let followerIds = snapshot?.documents.map { $0.documentID } ?? []
            let group = DispatchGroup()
            var tempFollowers: [(id: String, login: String, photoURL: String?)] = []
            for followerId in followerIds {
                group.enter()
                db.collection("users").document(followerId).getDocument { snapshot, error in
                    defer { group.leave() }
                    if let data = snapshot?.data() {
                        let login = data["login"] as? String ?? "Unknown"
                        let photoURL = data["photoURL"] as? String
                        tempFollowers.append((id: followerId, login: login, photoURL: photoURL))
                    }
                }
            }
            group.notify(queue: .main) {
                followers = tempFollowers
                isLoading = false
            }
        }
    }
} 