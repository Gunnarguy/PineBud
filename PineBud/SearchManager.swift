// MARK: - SearchManager.swift
import Foundation
import Combine
import SwiftUI

@MainActor final class SearchManager: ObservableObject, Sendable {
    @Published var isSearching = false
    @Published var searchResults: SearchResults?
    @Published var searchError: Error?
    @Published var searchHistory: [String] = []
    
    private var apiManager: APIManager?
    private var settingsManager: SettingsManager?
    private let searchHistoryKey = "search_history"
    private let maxHistoryItems = 20
    
    init() {
        // Load search history
        if let history = UserDefaults.standard.stringArray(forKey: searchHistoryKey) {
            searchHistory = history
        }
    }
    
    func configure(apiManager: APIManager, settingsManager: SettingsManager) {
        self.apiManager = apiManager
        self.settingsManager = settingsManager
    }
    
    func executeSearch(query: String) async throws -> SearchResults {
        guard let apiManager = apiManager, let settingsManager = settingsManager else {
            throw NSError(domain: "com.universalrag", code: 500,
                         userInfo: [NSLocalizedDescriptionKey: "Search manager not properly configured"])
        }
        
        guard let indexName = settingsManager.activeIndex else {
            throw NSError(domain: "com.universalrag", code: 400,
                         userInfo: [NSLocalizedDescriptionKey: "No active index selected"])
        }
        
        // Generate embedding for query
        let queryEmbedding = try await apiManager.generateEmbeddings(for: [query]).first!
        
        // Query Pinecone
        let namespace = settingsManager.activeNamespace
        print("Querying Pinecone index: \(indexName), namespace: \(namespace ?? "default")")
        let matches = try await apiManager.queryVectors(
            indexName: indexName,
            vector: queryEmbedding,
            namespace: namespace,
            topK: 10
        )
        
        // Prepare context from matches
        let context = matches.map { match in
            let source = match.metadata["source"] as? String ?? "Unknown"
            let text = match.metadata["text"] as? String ?? "No content available"
            return "Source: \(source)\n\(text)"
        }.joined(separator: "\n\n")
        
        // Generate answer using LLM
        let systemPrompt = """
        You are a helpful assistant that answers questions based on the retrieved context below.
        Only use information from the provided context to answer. If the context doesn't contain
        the necessary information, say that you don't have enough information to answer.
        
        CONTEXT:
        \(context)
        """
        
        let answer = try await apiManager.generateCompletion(
            systemPrompt: systemPrompt,
            userQuery: query
        )
        
        // Create search results
        let results = SearchResults(
            query: query,
            answer: answer,
            sources: matches.map { match in
                SourceResult(
                    id: match.id,
                    source: match.metadata["source"] as? String ?? "Unknown",
                    text: match.metadata["text"] as? String ?? "No content available",
                    score: match.score
                )
            }
        )
        
        // Add to search history
        addToSearchHistory(query)
        
        return results
    }
    
    func performSearch(query: String) {
        guard !query.isEmpty else { return }
        
        isSearching = true
        searchError = nil
        
        Task {
            do {
                let results = try await executeSearch(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.searchError = error
                    self.isSearching = false
                }
            }
        }
    }
    
    @MainActor
    private func addToSearchHistory(_ query: String) {
        // Remove if already exists to avoid duplicates
        searchHistory.removeAll(where: { $0 == query })
        
        // Add to beginning
        searchHistory.insert(query, at: 0)
        
        // Trim if needed
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(searchHistory, forKey: searchHistoryKey)
    }
    
    func clearSearchHistory() {
        searchHistory = []
        UserDefaults.standard.removeObject(forKey: searchHistoryKey)
    }
    
    func clearCurrentSearch() {
        searchResults = nil
        searchError = nil
    }
}
