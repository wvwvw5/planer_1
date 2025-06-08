import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Image(systemName: "checkmark.square")
                    Text("tasks_tab".localized)
                }
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("analytics_tab".localized)
                }
            ProfileView(userId: Auth.auth().currentUser?.uid ?? "")
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("profile_tab".localized)
                }
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("settings_tab".localized)
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageManager())
} 