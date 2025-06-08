import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var categoryManager: CategoryManager
    @State private var newCategoryName = ""
    @State private var showingAddCategory = false
    @State private var editingCategory: String?
    @State private var editedName = ""
    
    var body: some View {
        List {
            Section(header: Text("standard_categories".localized)) {
                ForEach(TaskCategory.standardCategories, id: \.self) { category in
                    HStack {
                        Text(category.displayName.localized)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Section(header: Text("custom_categories".localized)) {
                ForEach(categoryManager.customCategories, id: \.self) { category in
                    HStack {
                        if editingCategory == category {
                            TextField("category_name".localized, text: $editedName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    if !editedName.isEmpty {
                                        categoryManager.removeCategory(category)
                                        categoryManager.addCategory(editedName)
                                        editingCategory = nil
                                    }
                                }
                        } else {
                            Text(category)
                            Spacer()
                            Button(action: {
                                editingCategory = category
                                editedName = category
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        categoryManager.removeCategory(categoryManager.customCategories[index])
                    }
                }
            }
        }
        .navigationTitle("categories".localized)
        .navigationBarItems(trailing: Button(action: {
            showingAddCategory = true
        }) {
            Image(systemName: "plus")
        })
        .alert("new_category".localized, isPresented: $showingAddCategory) {
            TextField("category_name".localized, text: $newCategoryName)
            Button("cancel".localized, role: .cancel) {
                newCategoryName = ""
            }
            Button("add".localized) {
                if !newCategoryName.isEmpty {
                    categoryManager.addCategory(newCategoryName)
                    newCategoryName = ""
                }
            }
        } message: {
            Text("enter_new_category".localized)
        }
    }
} 