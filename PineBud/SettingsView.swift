// MARK: - SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var searchManager: SearchManager
    
    @State private var showingDeleteConfirmation = false
    @State private var showingAPIKeySheet = false
    @State private var showResetConfirmation = false
    @State private var openAIKey = ""
    @State private var pineconeKey = ""
    @State private var chunkSize = 1024
    @State private var chunkOverlap = 256
    @State private var embeddingDimension = 3072
    @State private var enableOCR = true
    
    var body: some View {
        NavigationView {
            Form {
                // API Keys
                Section(header: Text("API Keys")) {
                    Button(action: {
                        // Load current keys into state variables
                        openAIKey = settingsManager.openAIApiKey
                        pineconeKey = settingsManager.pineconeApiKey
                        showingAPIKeySheet = true
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.blue)
                            Text("Manage API Keys")
                        }
                    }
                }
                
                // Chunking Settings
                Section(header: Text("Text Processing")) {
                    Stepper("Chunk Size: \(chunkSize)", value: $chunkSize, in: 256...4096, step: 128)
                        .onChange(of: chunkSize) { oldValue, newValue in
                            settingsManager.chunkSize = newValue
                        }
                    
                    Text("Larger chunks contain more context but use more tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Stepper("Chunk Overlap: \(chunkOverlap)", value: $chunkOverlap, in: 0...1024, step: 64)
                        .onChange(of: chunkOverlap) { oldValue, newValue in
                            settingsManager.chunkOverlap = newValue
                        }
                    
                    Text("Overlap helps maintain context between chunks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Toggle("Enable OCR for Images", isOn: $enableOCR)
                        .onChange(of: enableOCR) { oldValue, newValue in
                            settingsManager.enableOCR = newValue
                        }
                }
                
                // Embedding Settings
                Section(header: Text("Embedding Settings")) {
                    Stepper("Embedding Dimension: \(embeddingDimension)", value: $embeddingDimension, in: 512...4096, step: 64)
                        .onChange(of: embeddingDimension) { oldValue, newValue in
                            settingsManager.embeddingDimension = newValue
                        }
                    
                    Text("Default for text-embedding-3-large is 3072")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Active Resources
                Section(header: Text("Active Resources")) {
                    HStack {
                        Text("Active Index")
                        Spacer()
                        Text(settingsManager.activeIndex ?? "None")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Active Namespace")
                        Spacer()
                        Text(settingsManager.activeNamespace ?? "Default")
                            .foregroundColor(.secondary)
                    }
                }
                
                // App Info
                Section(header: Text("App Information")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("7.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Documents")
                        Spacer()
                        Text("\(documentManager.documents.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Actions
                Section {
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            Text("Reset to Default Settings")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Clear All Documents")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button(action: {
                        searchManager.clearSearchHistory()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Clear Search History")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Load current settings
                chunkSize = settingsManager.chunkSize
                chunkOverlap = settingsManager.chunkOverlap
                embeddingDimension = settingsManager.embeddingDimension
                enableOCR = settingsManager.enableOCR
            }
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Clear All Documents"),
                    message: Text("Are you sure you want to delete all documents? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete All")) {
                        deleteAllDocuments()
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showResetConfirmation) {
                Alert(
                    title: Text("Reset Settings"),
                    message: Text("Are you sure you want to reset all settings to their default values?"),
                    primaryButton: .destructive(Text("Reset")) {
                        settingsManager.resetToDefaults()
                        // Reload settings after reset
                        chunkSize = settingsManager.chunkSize
                        chunkOverlap = settingsManager.chunkOverlap
                        embeddingDimension = settingsManager.embeddingDimension
                        enableOCR = settingsManager.enableOCR
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeysView(openAIKey: $openAIKey, pineconeKey: $pineconeKey)
            }
        }
    }
    
    private func deleteAllDocuments() {
        // Implementation would iterate through all documents and delete them
        // This is a placeholder for the actual implementation
        print("Delete all documents")
    }
}
