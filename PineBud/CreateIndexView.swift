// MARK: - CreateIndexView.swift
import SwiftUI

struct CreateIndexView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var apiManager: APIManager
    
    let onIndexCreated: (String?) -> Void
    
    @State private var indexName = ""
    @State private var dimension = 3072
    @State private var metric: String
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showAdvancedOptions = false
    
    let availableMetrics = ["cosine", "euclidean", "dotproduct"]
    
    init(onIndexCreated: @escaping (String?) -> Void) {
        self.onIndexCreated = onIndexCreated
        // Initialize with a default value that is guaranteed to be in the availableMetrics array
        _metric = State(initialValue: "cosine")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Index Information")) {
                    TextField("Index Name", text: $indexName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                        Picker("Distance Metric", selection: $metric) {
                            ForEach(availableMetrics, id: \.self) { metricName in
                                Text(metricName.capitalized).tag(metricName)
                            }
                        }
                        .id("metric-picker")  // Add stable ID to picker
                        .pickerStyle(DefaultPickerStyle())
                        
                        Stepper("Dimension: \(dimension)", value: $dimension, in: 1...4096, step: 64)
                        
                        Text("Default for text-embedding-3-large is 3072")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(footer: Text("The index will be created with serverless configuration in AWS us-east-1 region.")) {
                    Button(action: createIndex) {
                        if isCreating {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 5)
                                Text("Creating Index...")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Index")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(indexName.isEmpty || isCreating)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Index")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .disabled(isCreating)
        }
    }
    
    private func createIndex() {
        guard !indexName.isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                let success = try await apiManager.createPineconeIndex(
                    name: indexName,
                    dimension: dimension,
                    metric: metric
                )
                
                DispatchQueue.main.async {
                    self.isCreating = false
                    
                    if success {
                        self.onIndexCreated(self.indexName)
                        self.presentationMode.wrappedValue.dismiss()
                    } else {
                        self.errorMessage = "Failed to create index. It might still be initializing. Please try again later."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCreating = false
                    self.errorMessage = "Error creating index: \(error.localizedDescription)"
                }
            }
        }
    }
}
