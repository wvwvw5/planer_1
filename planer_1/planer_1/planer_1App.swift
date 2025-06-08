import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    // Показываем уведомления даже если приложение открыто
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("willPresent notification: \(notification.request.content.title)")
        completionHandler([.banner, .sound, .list])
    }
    
    // Handle notification taps
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let _ = response.notification.request.content.userInfo
        print("DEBUG: Notification tapped.")
        // Handle tap action here (optional)
        completionHandler()
    }
}

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var taskViewModel: TaskViewModel
    
    var body: some View {
        if authViewModel.userSession != nil {
            MainTabView()
                .environmentObject(authViewModel)
                .environmentObject(languageManager)
                .environmentObject(taskViewModel)
        } else {
            AuthView()
                .environmentObject(authViewModel)
        }
    }
}

@main
struct planer_1App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var auth = AuthViewModel()
    @StateObject var taskViewModel = TaskViewModel() // Инициализируем TaskViewModel
    @AppStorage("appTheme") var appTheme: String = "theme_system" // Читаем тему
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var categoryManager = CategoryManager.shared

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Ошибка запроса разрешения на уведомления: \(error.localizedDescription)")
            }
            print("Разрешение на уведомления: \(granted)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(taskViewModel)
                .environmentObject(languageManager)
                .environmentObject(categoryManager)
                .preferredColorScheme(getPreferredColorScheme())
        }
    }
    
    // MARK: - Deep Link Handling
    func handleDeepLink(_ url: URL) {
        print("DEBUG: Получена Deep Link: \(url)")
        guard url.scheme == "planerapp" else {
            print("DEBUG: Неизвестная схема URL: \(url.scheme ?? "")")
            return
        }
        guard url.host == "task" else {
             print("DEBUG: Неизвестный хост URL: \(url.host ?? "")")
            return
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems
        
        guard let taskId = queryItems?.first(where: { $0.name == "taskId" })?.value,
              let userId = queryItems?.first(where: { $0.name == "userId" })?.value else {
            print("DEBUG: Deep Link содержит неверные параметры.")
            return
        }
        
        print("DEBUG: Deep Link параметры - Task ID: \(taskId), User ID: \(userId)")
        
        // Теперь у нас есть taskId и userId. Нужно загрузить задачу и предложить пользователю ее добавить.
        taskViewModel.handleSharedTask(taskId: taskId, userId: userId)
    }
    
    func getPreferredColorScheme() -> ColorScheme? {
        switch appTheme {
        case "theme_light":
            return .light
        case "theme_dark":
            return .dark
        default:
            return nil // system
        }
    }
}

extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
    static let didLogin = Notification.Name("didLogin")
}
