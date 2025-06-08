import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    var fullname: String
    var email: String
    var login: String
    
    var initials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: fullname) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        
        return fullname.components(separatedBy: " ")
            .map { $0.prefix(1) }
            .joined()
    }
} 