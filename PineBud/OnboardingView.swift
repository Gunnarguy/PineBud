// MARK: - OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var currentStep = 0
    @State private var openAIKey = ""
    @State private var pineconeKey = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            ZStack {
                Color.blue.opacity(0.1)
                    .frame(height: 200)
                    .cornerRadius(16)
                
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Universal RAG System")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your AI-Powered Document Search")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Progress indicator
            ProgressView(value: Double(currentStep + 1), total: 3)
                .padding(.horizontal)
            
            Spacer(minLength: 30)
            
            // Current step content
            VStack(alignment: .leading, spacing: 15) {
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    apiKeysStep
                case 2:
                    setupCompleteStep
                default:
                    EmptyView()
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .multilineTextAlignment(.center)
            }
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .disabled(isLoading)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .padding(.horizontal)
                }
                
                Button(currentStep == 2 ? "Get Started" : "Next") {
                    withAnimation {
                        nextButtonTapped()
                    }
                }
                .disabled(isLoading || (currentStep == 1 && (openAIKey.isEmpty || pineconeKey.isEmpty)))
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
    }
    
    // STEP 1: Welcome
    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Welcome to Universal RAG")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This app enables you to process documents, generate embeddings, and perform semantic search using OpenAI and Pinecone.")
                .multilineTextAlignment(.leading)
            
            Text("You'll need API keys from OpenAI and Pinecone to get started.")
                .multilineTextAlignment(.leading)
                .padding(.top)
            
            HStack {
                Link("Get OpenAI API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .buttonStyle(.bordered)
                
                Link("Get Pinecone API Key", destination: URL(string: "https://app.pinecone.io/")!)
                    .buttonStyle(.bordered)
            }
            .padding(.top)
        }
    }
    
    // STEP 2: API Keys
    private var apiKeysStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("API Keys")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enter your API keys to connect with OpenAI and Pinecone.")
                .multilineTextAlignment(.leading)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("OpenAI API Key")
                    .fontWeight(.medium)
                
                SecureField("sk-...", text: $openAIKey)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("Pinecone API Key")
                    .fontWeight(.medium)
                    .padding(.top, 5)
                
                SecureField("...", text: $pineconeKey)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(.top)
        }
    }
    
    // STEP 3: Setup Complete
    private var setupCompleteStep: some View {
        VStack(alignment: .center, spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.green)
            
            Text("Setup Complete!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your Universal RAG system is ready to use. You can now add documents, create indexes, and perform semantic searches.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                    Text("First, create a Pinecone index")
                }
                
                HStack {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                    Text("Add and process your documents")
                }
                
                HStack {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                    Text("Index the documents")
                }
                
                HStack {
                    Image(systemName: "4.circle.fill")
                        .foregroundColor(.blue)
                    Text("Search with natural language")
                }
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func nextButtonTapped() {
        switch currentStep {
        case 0:
            // Move to API keys step
            currentStep += 1
        case 1:
            // Validate API keys
            validateAPIKeys()
        case 2:
            // Complete onboarding
            completeOnboarding()
        default:
            break
        }
    }
    
    private func validateAPIKeys() {
        isLoading = true
        errorMessage = nil
        
        // Store API keys
        settingsManager.openAIApiKey = openAIKey
        settingsManager.pineconeApiKey = pineconeKey
        
        // Test API connections
        Task {
            do {
                // Test OpenAI API
                let openAITest = try await apiManager.generateEmbeddings(for: ["Test"])
                guard !openAITest.isEmpty else {
                    throw NSError(domain: "com.universalrag", code: 400, userInfo: [NSLocalizedDescriptionKey: "OpenAI API returned empty response"])
                }
                
                // Test Pinecone API
                _ = try await apiManager.listPineconeIndexes()
                
                // Success, move to next step
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.currentStep += 1
                }
            } catch {
                // Show error message
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Error validating API keys: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func completeOnboarding() {
        settingsManager.isFirstLaunch = false
    }
}
