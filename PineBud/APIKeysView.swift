// MARK: - APIKeysView.swift
import SwiftUI

struct APIKeysView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var settingsManager: SettingsManager
    
    @Binding var openAIKey: String
    @Binding var pineconeKey: String
    
    @State private var isEditingOpenAI = false
    @State private var isEditingPinecone = false
    @State private var showingSaveConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("OpenAI API Key"), footer: Text("Required for embeddings and completions")) {
                    if isEditingOpenAI {
                        SecureField("sk-...", text: $openAIKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button("Done Editing") {
                            isEditingOpenAI = false
                        }
                    } else {
                        HStack {
                            Text(maskAPIKey(openAIKey))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                isEditingOpenAI = true
                            }) {
                                Text("Edit")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Link("Get OpenAI API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                }
                
                Section(header: Text("Pinecone API Key"), footer: Text("Required for vector database operations")) {
                    if isEditingPinecone {
                        SecureField("...", text: $pineconeKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button("Done Editing") {
                            isEditingPinecone = false
                        }
                    } else {
                        HStack {
                            Text(maskAPIKey(pineconeKey))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                isEditingPinecone = true
                            }) {
                                Text("Edit")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Link("Get Pinecone API Key", destination: URL(string: "https://app.pinecone.io/")!)
                }
                
                Section {
                    Button(action: {
                        saveAPIKeys()
                        showingSaveConfirmation = true
                    }) {
                        Text("Save API Keys")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("API Keys")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingSaveConfirmation) {
                Alert(
                    title: Text("API Keys Saved"),
                    message: Text("Your API keys have been securely stored."),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    private func maskAPIKey(_ key: String) -> String {
        if key.isEmpty {
            return "Not set"
        }
        
        if key.count <= 8 {
            return String(repeating: "•", count: 12)
        }
        
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        let maskedPart = String(repeating: "•", count: 8)
        
        return "\(prefix)\(maskedPart)\(suffix)"
    }
    
    private func saveAPIKeys() {
        if !openAIKey.isEmpty {
            settingsManager.openAIApiKey = openAIKey
        }
        
        if !pineconeKey.isEmpty {
            settingsManager.pineconeApiKey = pineconeKey
        }
    }
}
