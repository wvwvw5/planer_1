import Foundation
import SwiftUI
import FirebaseFirestore
import CoreLocation

enum TaskPriority: String, CaseIterable, Codable {
    case high = "priority_high"
    case medium = "priority_medium"
    case low = "priority_low"

    var icon: String {
        switch self {
        case .high: return "🔥"
        case .medium: return "⚡"
        case .low: return "✅"
        }
    }

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    var localized: String {
        return self.rawValue.localized
    }
}

enum TaskCategory: Codable, Identifiable, Hashable {
    case all
    case study
    case work
    case personal
    case health
    case shopping
    case custom(String)
    
    var id: String {
        switch self {
        case .all: return "all"
        case .study: return "study"
        case .work: return "work"
        case .personal: return "personal"
        case .health: return "health"
        case .shopping: return "shopping"
        case .custom(let value): return "custom_\(value)"
        }
    }
    
    var displayName: String {
        switch self {
        case .all: return "category_all"
        case .study: return "category_study"
        case .work: return "category_work"
        case .personal: return "category_personal"
        case .health: return "category_health"
        case .shopping: return "category_shopping"
        case .custom(let value): return value
        }
    }
    
    var localized: String {
        return displayName.localized
    }
    
    static var standardCategories: [TaskCategory] {
        [.study, .work, .personal, .health, .shopping]
    }
    
    static var allCategories: [TaskCategory] {
        var categories: [TaskCategory] = [.all]
        categories.append(contentsOf: standardCategories)
        categories.append(contentsOf: CategoryManager.shared.customCategories.map { .custom($0) })
        return categories
    }
}

enum ReminderType: String, Codable, CaseIterable, Identifiable {
    case none = "reminder_none"
    case tenMinutes = "reminder_ten_minutes"
    case oneHour = "reminder_one_hour"
    case oneDay = "reminder_one_day"
    var id: String { self.rawValue }
    
    var localized: String {
        return self.rawValue.localized
    }
}

struct TaskItem: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String = ""
    var dueDate: Date
    var priority: TaskPriority
    var category: TaskCategory
    var isCompleted: Bool = false
    var userId: String = ""
    var location: Location?
    var isPrivate: Bool = true
    var reminderType: ReminderType
    var originalTaskId: String?
    var originalUserId: String?
    var isArchived: Bool
    var archivedAt: Date?
    var completedAt: Date?

    struct Location: Codable, Identifiable {
        var id = UUID()
        var latitude: Double
        var longitude: Double
        var address: String
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    var dueDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id as Any,
            "title": title,
            "description": description,
            "dueDate": Timestamp(date: dueDate),
            "priority": priority.rawValue,
            "category": category.id,
            "isCompleted": isCompleted,
            "userId": userId,
            "isPrivate": isPrivate,
            "reminderType": reminderType.rawValue,
            "originalTaskId": originalTaskId as Any,
            "originalUserId": originalUserId as Any,
            "isArchived": isArchived
        ]
        
        if let location = location {
            dict["location"] = [
                "latitude": location.latitude,
                "longitude": location.longitude,
                "address": location.address
            ]
        }
        
        if let archivedAt = archivedAt {
            dict["archivedAt"] = Timestamp(date: archivedAt)
        }
        
        if let completedAt = completedAt {
            dict["completedAt"] = Timestamp(date: completedAt)
        }
        
        return dict
    }

    init(id: String? = nil,
         title: String,
         description: String = "",
         dueDate: Date,
         priority: TaskPriority = .medium,
         category: TaskCategory = .study,
         isCompleted: Bool = false,
         isPrivate: Bool = false,
         userId: String,
         location: Location? = nil,
         reminderType: ReminderType = .none,
         originalTaskId: String? = nil,
         originalUserId: String? = nil,
         isArchived: Bool = false,
         archivedAt: Date? = nil,
         completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
        self.category = category
        self.isCompleted = isCompleted
        self.isPrivate = isPrivate
        self.userId = userId
        self.location = location
        self.reminderType = reminderType
        self.originalTaskId = originalTaskId
        self.originalUserId = originalUserId
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.completedAt = completedAt
    }

    init(from data: [String: Any]) {
        self.id = data["id"] as? String
        self.title = data["title"] as? String ?? ""
        self.description = data["description"] as? String ?? ""
        self.dueDate = (data["dueDate"] as? Timestamp)?.dateValue() ?? Date()
        self.priority = TaskPriority(rawValue: data["priority"] as? String ?? "medium") ?? .medium
        
        // Преобразование строки категории в TaskCategory
        if let categoryString = data["category"] as? String {
            if categoryString.hasPrefix("custom_") {
                let customValue = String(categoryString.dropFirst(7))
                self.category = .custom(customValue)
            } else {
                switch categoryString {
                case "study": self.category = .study
                case "work": self.category = .work
                case "personal": self.category = .personal
                case "health": self.category = .health
                case "shopping": self.category = .shopping
                default: self.category = .study
                }
            }
        } else {
            self.category = .study
        }

        self.isCompleted = data["isCompleted"] as? Bool ?? false
        self.userId = data["userId"] as? String ?? ""
        self.isPrivate = data["isPrivate"] as? Bool ?? true
        self.reminderType = ReminderType(rawValue: data["reminderType"] as? String ?? "none") ?? .none
        self.originalTaskId = data["originalTaskId"] as? String
        self.originalUserId = data["originalUserId"] as? String
        self.isArchived = data["isArchived"] as? Bool ?? false
        self.archivedAt = (data["archivedAt"] as? Timestamp)?.dateValue()
        self.completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
        
        if let locationData = data["location"] as? [String: Any] {
            self.location = Location(
                latitude: locationData["latitude"] as? Double ?? 0,
                longitude: locationData["longitude"] as? Double ?? 0,
                address: locationData["address"] as? String ?? ""
            )
        } else {
            self.location = nil
        }
    }

    var shareContent: String {
        var content = """
        📋 \(title)
        📝 \(description)
        🗓 \(dueDateFormatted)
        🔷 \("priority".localized): \(priority.localized)
        """
        
        if let location = location {
            content += "\n📍 \(location.address)"
        }
        
        content += "\n\(isCompleted ? "completed".localized : "in_progress".localized)"
        return content
    }

    /// Добавлено для работы с ContentView (редактирование)
    static var empty: TaskItem {
        TaskItem(
            title: "",
            description: "",
            dueDate: Date(),
            priority: .medium,
            category: .study,
            isCompleted: false,
            isPrivate: false,
            userId: "",
            location: nil,
            reminderType: .none,
            isArchived: false,
            archivedAt: nil,
            completedAt: nil
        )
    }
}
