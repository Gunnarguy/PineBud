// MARK: - SettingsManager.swift
import Foundation
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    @Published var isFirstLaunch: Bool
    @Published var activeIndex: String?
    @Published var activeNamespace: String?
    
    var areAPIKeysSet: Bool {
        return !openAIApiKey.isEmpty && !pineconeApiKey.isEmpty
    }
    
    var openAIApiKey: String {
        get {
            return KeychainHelper.shared.get(key: "openai_api_key") ?? ""
        }
        set {
            KeychainHelper.shared.save(key: "openai_api_key", value: newValue)
            objectWillChange.send()
        }
    }
    
    var pineconeApiKey: String {
        get {
            return KeychainHelper.shared.get(key: "pinecone_api_key") ?? ""
        }
        set {
            KeychainHelper.shared.save(key: "pinecone_api_key", value: newValue)
            objectWillChange.send()
        }
    }
    
    var embeddingDimension: Int {
        get {
            return UserDefaults.standard.integer(forKey: "embedding_dimension") != 0 ? UserDefaults.standard.integer(forKey: "embedding_dimension") : 3072
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "embedding_dimension")
            objectWillChange.send()
        }
    }
    
    var chunkSize: Int {
        get {
            return UserDefaults.standard.integer(forKey: "chunk_size") != 0 ? UserDefaults.standard.integer(forKey: "chunk_size") : 1024
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "chunk_size")
            objectWillChange.send()
        }
    }
    
    var chunkOverlap: Int {
        get {
            return UserDefaults.standard.integer(forKey: "chunk_overlap") != 0 ? UserDefaults.standard.integer(forKey: "chunk_overlap") : 256
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "chunk_overlap")
            objectWillChange.send()
        }
    }
    
    // Whether to process images with OCR
    var enableOCR: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "enable_ocr")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "enable_ocr")
            objectWillChange.send()
        }
    }
    
    // Model settings
    var embeddingModel: String {
        get {
            return UserDefaults.standard.string(forKey: "embedding_model") ?? "text-embedding-3-large"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "embedding_model")
            objectWillChange.send()
        }
    }
    
    var completionModel: String {
        get {
            return UserDefaults.standard.string(forKey: "completion_model") ?? "gpt-4o"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "completion_model")
            objectWillChange.send()
        }
    }
    
    init() {
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: "has_launched_before")
        self.activeIndex = UserDefaults.standard.string(forKey: "active_index")
        self.activeNamespace = UserDefaults.standard.string(forKey: "active_namespace")
        
        // Set default values if first launch
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "has_launched_before")
            UserDefaults.standard.set(3072, forKey: "embedding_dimension")
            UserDefaults.standard.set(1024, forKey: "chunk_size")
            UserDefaults.standard.set(256, forKey: "chunk_overlap")
            UserDefaults.standard.set(true, forKey: "enable_ocr")
            UserDefaults.standard.set("text-embedding-3-large", forKey: "embedding_model")
            UserDefaults.standard.set("gpt-4o", forKey: "completion_model")
        }
    }
    
    func setActiveIndex(_ indexName: String) {
        self.activeIndex = indexName
        UserDefaults.standard.set(indexName, forKey: "active_index")
        objectWillChange.send()
    }
    
    func setActiveNamespace(_ namespace: String?) {
        self.activeNamespace = namespace
        UserDefaults.standard.set(namespace, forKey: "active_namespace")
        objectWillChange.send()
    }
    
    func resetFirstLaunch() {
        isFirstLaunch = true
        UserDefaults.standard.set(false, forKey: "has_launched_before")
        objectWillChange.send()
    }
    
    func clearAPIKeys() {
        openAIApiKey = ""
        pineconeApiKey = ""
    }
    
    func resetToDefaults() {
        UserDefaults.standard.set(3072, forKey: "embedding_dimension")
        UserDefaults.standard.set(1024, forKey: "chunk_size")
        UserDefaults.standard.set(256, forKey: "chunk_overlap")
        UserDefaults.standard.set(true, forKey: "enable_ocr")
        UserDefaults.standard.set("text-embedding-3-large", forKey: "embedding_model")
        UserDefaults.standard.set("gpt-4o", forKey: "completion_model")
        objectWillChange.send()
    }
}
