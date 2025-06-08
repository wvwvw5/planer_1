import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @StateObject private var viewModel = TaskViewModel()
    @State private var isShowingAddTask = false
    @State private var selectedTask: TaskItem?
    @State private var isEditing = false
    @State private var showingProfile = false
    @State private var showingSideMenu = false
    @State private var menuDragOffset: CGFloat = 0
    @State private var showingSettings = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        ZStack {
            NavigationView {
                TaskListView()
//                    .navigationTitle("Задачи")
                    .navigationBarItems(
                        leading: Button(action: {
                            withAnimation { showingSideMenu = true }
                        }) {
                            Image(systemName: "line.horizontal.3")
                        },
                        trailing: Button(action: {
                            selectedTask = nil
                            isEditing = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    )
                    .sheet(isPresented: $isEditing) {
                        if let selected = selectedTask {
                    EditTaskView(
                                task: Binding(
                                    get: { selected },
                                    set: { selectedTask = $0 }
                                ),
                        onSave: { updatedTask in
                                    viewModel.updateTask(updatedTask)
                                    isEditing = false
                        },
                        onCancel: {
                                    isEditing = false
                        }
                    )
                        } else {
                            AddTaskView { newTask in
                                viewModel.addTask(newTask)
                                isEditing = false
                        }
                    }
                    }
                    .sheet(isPresented: $showingProfile) {
                        if let userId = Auth.auth().currentUser?.uid {
                            ProfileView(userId: userId)
                }
            }
                    // Свайп вправо для открытия меню
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.width > 60 && !showingSideMenu && value.startLocation.x < 40 {
                                    withAnimation { showingSideMenu = true }
                                }
                            }
                    )
            }
            // Затемнение фона при открытом меню
            if showingSideMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                        .onTapGesture {
                        withAnimation { showingSideMenu = false }
                    }
            }
            // Само меню
            if showingSideMenu {
                HStack(spacing: 0) {
                    SideMenuView(
                        onProfileTap: {
                            showingProfile = true
                            showingSideMenu = false
                        },
                        onLogout: {
                            try? Auth.auth().signOut()
                        },
                        showMenu: $showingSideMenu,
                        onSettingsTap: { showingSettings = true }
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.85)
                    .background(Color(.systemBackground))
                    .offset(x: menuDragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.width < 0 {
                                    menuDragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                if value.translation.width < -60 {
                                withAnimation {
                                        showingSideMenu = false
                                }
                                }
                                menuDragOffset = 0
                            }
                    )
                    Spacer()
                            }
                .transition(.move(edge: .leading))
                .zIndex(1)
    }
        }
        .animation(.easeInOut, value: showingSideMenu)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authViewModel)
                .environmentObject(languageManager)
        }
    }
}
