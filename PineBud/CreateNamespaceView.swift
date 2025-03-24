// MARK: - CreateNamespaceView.swift
import SwiftUI

struct CreateNamespaceView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    let onNamespaceCreated: (String?) -> Void
    
    @State private var namespaceName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Namespace Information")) {
                    TextField("Namespace Name", text: $namespaceName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(footer: Text("Namespaces help organize vectors within an index. No API call is needed to create a namespace; it will be created automatically when vectors are first upserted to that namespace.")) {
                    Button(action: createNamespace) {
                        Text("Create Namespace")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(namespaceName.isEmpty || isCreating)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Namespace")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .disabled(isCreating)
        }
    }
    
    private func createNamespace() {
        guard !namespaceName.isEmpty, let indexName = settingsManager.activeIndex, !indexName.isEmpty else {
            errorMessage = "Index not selected or namespace name is empty"
            return
        }
        
        // Validate namespace name length
        if namespaceName.count > 64 {
            errorMessage = "Namespace name cannot exceed 64 characters"
            return
        }
        
        onNamespaceCreated(namespaceName)
        presentationMode.wrappedValue.dismiss()
    }
}
