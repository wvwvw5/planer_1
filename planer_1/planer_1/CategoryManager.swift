import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    @Published var customCategories: [String] = []
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    private var userId: String? { Auth.auth().currentUser?.uid }
    
    private init() {
        listenCategories()
    }
    
    func listenCategories() {
        guard let userId = userId else { return }
        listener?.remove()
        listener = db.collection("users").document(userId).collection("customCategories").addSnapshotListener { snapshot, error in
            if let documents = snapshot?.documents {
                self.customCategories = documents.compactMap { $0["name"] as? String }
            }
        }
    }
    
    func addCategory(_ name: String) {
        guard let userId = userId else { return }
        let ref = db.collection("users").document(userId).collection("customCategories").document(name)
        ref.setData(["name": name])
    }
    
    func removeCategory(_ name: String) {
        guard let userId = userId else { return }
        let ref = db.collection("users").document(userId).collection("customCategories").document(name)
        ref.delete()
    }
    
    func categoryExists(_ name: String) -> Bool {
        customCategories.contains(name)
    }
} 