// MARK: - IndexesView.swift
import SwiftUI

struct IndexesView: View {
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var indexes: [String] = []
    @State private var namespaces: [String] = []
    @State private var isLoading = false
    @State private var showCreateIndexSheet = false
    @State private var showCreateNamespaceSheet = false
    
    var body: some View {
        VStack {
            // Index and namespace selection
            VStack(spacing: 16) {
                // Index selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Index:")
                        .font(.headline)
                    
                    Picker("Select Index", selection: $settingsManager.activeIndex.toUnwrapped(defaultValue: "")) {
                        Text("No Index Selected").tag("")
                        
                        ForEach(indexes, id: \.self) { index in
                            Text(index).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: settingsManager.activeIndex) { newValue in
                        if let indexName = newValue, !indexName.isEmpty {
                            settingsManager.setActiveIndex(indexName)
                            loadNamespaces(for: indexName)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                
                // Namespace selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Namespace:")
                        .font(.headline)
                    
                    Picker("Select Namespace", selection: $settingsManager.activeNamespace.toUnwrapped(defaultValue: "")) {
                        Text("Default Namespace").tag("")
                        
                        ForEach(namespaces, id: \.self) { namespace in
                            Text(namespace).tag(namespace)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: settingsManager.activeNamespace) { newValue in
                        settingsManager.setActiveNamespace(newValue)
                    }
                    .disabled(settingsManager.activeIndex == nil || settingsManager.activeIndex?.isEmpty == true)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .padding()
            
            Divider()
            
            // Index and namespace lists
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text("Loading...")
                        .font(.headline)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Indexes section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Available Indexes")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if indexes.isEmpty {
                                Text("No indexes found")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(indexes, id: \.self) { index in
                                    IndexRow(
                                        name: index,
                                        isActive: settingsManager.activeIndex == index
                                    ) {
                                        settingsManager.setActiveIndex(index)
                                        loadNamespaces(for: index)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Namespaces section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Available Namespaces")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if namespaces.isEmpty {
                                Text(settingsManager.activeIndex == nil ? "Select an index first" : "No namespaces found")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                NamespaceRow(
                                    name: "Default Namespace",
                                    isActive: settingsManager.activeNamespace == nil || settingsManager.activeNamespace?.isEmpty == true
                                ) {
                                    settingsManager.setActiveNamespace(nil)
                                }
                                
                                ForEach(namespaces, id: \.self) { namespace in
                                    NamespaceRow(
                                        name: namespace,
                                        isActive: settingsManager.activeNamespace == namespace
                                    ) {
                                        settingsManager.setActiveNamespace(namespace)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top)
                }
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    showCreateIndexSheet = true
                }) {
                    Label("Create Index", systemImage: "plus.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                Button(action: {
                    showCreateNamespaceSheet = true
                }) {
                    Label("Create Namespace", systemImage: "plus.rectangle.on.folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || settingsManager.activeIndex == nil || settingsManager.activeIndex?.isEmpty == true)
            }
            .padding()
        }
        .navigationTitle("Indexes")
        .onAppear {
            loadIndexes()
        }
        .sheet(isPresented: $showCreateIndexSheet) {
            CreateIndexView(onIndexCreated: { indexName in
                loadIndexes()
                if let name = indexName {
                    settingsManager.setActiveIndex(name)
                    loadNamespaces(for: name)
                }
            })
        }
        .sheet(isPresented: $showCreateNamespaceSheet) {
            CreateNamespaceView(onNamespaceCreated: { namespaceName in
                if let indexName = settingsManager.activeIndex, !indexName.isEmpty {
                    loadNamespaces(for: indexName)
                }
                if let name = namespaceName {
                    settingsManager.setActiveNamespace(name)
                }
            })
        }
        .refreshable {
            loadIndexes()
        }
    }
    
    private func loadIndexes() {
        isLoading = true
        
        Task {
            do {
                let loadedIndexes = try await apiManager.listPineconeIndexes()
                
                DispatchQueue.main.async {
                    self.indexes = loadedIndexes
                    self.isLoading = false
                    
                    // Load namespaces for active index
                    if let activeIndex = settingsManager.activeIndex, !activeIndex.isEmpty {
                        self.loadNamespaces(for: activeIndex)
                    }
                }
            } catch {
                print("Error loading indexes: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.indexes = []
                    self.isLoading = false
                    apiManager.currentError = APIError(message: "Error loading indexes: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadNamespaces(for indexName: String) {
        isLoading = true
        
        Task {
            do {
                let loadedNamespaces = try await apiManager.getNamespaces(indexName: indexName)
                
                DispatchQueue.main.async {
                    self.namespaces = loadedNamespaces
                    self.isLoading = false
                }
            } catch {
                print("Error loading namespaces: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.namespaces = []
                    self.isLoading = false
                    apiManager.currentError = APIError(message: "Error loading namespaces: \(error.localizedDescription)")
                }
            }
        }
    }
}







