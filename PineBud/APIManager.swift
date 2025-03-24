// MARK: - APIManager.swift
import Foundation
import Combine
import SwiftUI

class APIError: Identifiable {
    let id = UUID()
    let message: String
    
    init(message: String) {
        self.message = message
    }
}

class APIManager: ObservableObject {
    @Published var isLoading = false
    @Published var currentError: APIError?
    
    private let openAIBaseURL = "https://api.openai.com/v1"
    private let pineconeBaseURL = "https://api.pinecone.io"
    
    private var openAIApiKey: String {
        KeychainHelper.shared.get(key: "openai_api_key") ?? ""
    }
    
    private var pineconeApiKey: String {
        KeychainHelper.shared.get(key: "pinecone_api_key") ?? ""
    }
    
    // MARK: - OpenAI Embeddings API
    
    func generateEmbeddings(for texts: [String]) async throws -> [[Double]] {
        guard !openAIApiKey.isEmpty else {
            throw NSError(domain: "com.universalrag", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not set"])
        }
        
        let url = URL(string: "\(openAIBaseURL)/embeddings")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(openAIApiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "input": texts,
            "model": "text-embedding-3-large",
            "dimensions": 3072
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw NSError(domain: "com.universalrag", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorResponse?.error.message ?? "Failed to generate embeddings"])
        }
        
        let embeddingsResponse = try JSONDecoder().decode(OpenAIEmbeddingsResponse.self, from: data)
        return embeddingsResponse.data.map { $0.embedding }
    }
    
    // MARK: - OpenAI Chat Completions API
    
    func generateCompletion(systemPrompt: String, userQuery: String) async throws -> String {
        guard !openAIApiKey.isEmpty else {
            throw NSError(domain: "com.universalrag", code: 401, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not set"])
        }
        
        let url = URL(string: "\(openAIBaseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(openAIApiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userQuery]
            ],
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw NSError(domain: "com.universalrag", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorResponse?.error.message ?? "Failed to generate completion"])
        }
        
        let completionResponse = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        return completionResponse.choices.first?.message.content ?? "No response generated"
    }
    
    // MARK: - Pinecone Index Management
    
    func listPineconeIndexes() async throws -> [String] {
        guard !pineconeApiKey.isEmpty else {
            throw NSError(domain: "com.universalrag", code: 401, userInfo: [NSLocalizedDescriptionKey: "Pinecone API key not set"])
        }
        
        let url = URL(string: "\(pineconeBaseURL)/indexes")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(pineconeApiKey)", forHTTPHeaderField: "Api-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "com.universalrag", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to list Pinecone indexes"])
        }
        
        let indexesResponse = try JSONDecoder().decode(PineconeListIndexesResponse.self, from: data)
        return indexesResponse.indexes.map { $0.name }
    }
    
    func createPineconeIndex(name: String, dimension: Int, metric: String) async throws -> Bool {
        guard !pineconeApiKey.isEmpty else {
            throw NSError(domain: "com.universalrag", code: 401, userInfo: [NSLocalizedDescriptionKey: "Pinecone API key not set"])
        }
        
        let url = URL(string: "\(pineconeBaseURL)/indexes")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(pineconeApiKey)", forHTTPHeaderField: "Api-Key")
        
        let requestBody: [String: Any] = [
            "name": name,
            "dimension": dimension,
            "metric": metric,
            "spec": [
                "serverless": [
                    "cloud": "aws",
                    "region": "us-east-1"
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else {
            throw NSError(domain: "com.universalrag", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create Pinecone index"])
        }
        
        // Wait for index to be ready
        return try await waitForIndexReady(name: name)
    }
    
    func waitForIndexReady(name: String) async throws -> Bool {
        for _ in 0..<30 { // Try for up to 30 * 2 seconds = 1 minute
            let status = try await getIndexStatus(name: name)
            if status == "Ready" {
                return true
            }
            try await Task.sleep(nanoseconds: 2_000_000_000) // Sleep for 2 seconds
        }
        return false
    }
    
    func getIndexStatus(name: String) async throws -> String {
        guard !pineconeApiKey.isEmpty else {
            throw NSError(domain: "com.universalrag", code: 401, userInfo: [NSLocalizedDescriptionKey: "Pinecone API key not set"])
        }
        
        let url = URL(string: "\(pineconeBaseURL)/indexes/\(name)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(pineconeApiKey)", forHTTPHeaderField: "Api-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "com.universalrag", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get index status"])
        }
        
        let indexResponse = try JSONDecoder().decode(PineconeIndexResponse.self, from: data)
        return indexResponse.status.state
    }
    
    func getNamespaces(indexName: String) async throws -> [String] {
        guard !pineconeApiKey.isEmpty else {
            throw NSError(domain: "com.universalrag", code: 401, userInfo: [NSLocalizedDescriptionKey: "Pinecone API key not set"])
        }
        
        let host = try await getIndexHost(name: indexName)
        let url = URL(string: "https://\(host)/describe_index_stats")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(pineconeApiKey)", forHTTPHeaderField: "Api-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "com.universalrag", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get namespaces"])
        }
        
        let statsResponse = try JSONDecoder().decode(PineconeStatsResponse.self, from: data)
        return Array(statsResponse.namespaces.keys)
    }
    
    func getIndexHost(name: String) async throws -> String {
        guard !pineconeApiKey.isEmpty else {
            throw NSError(domain: "com.universalrag", code: 401, userInfo: [NSLocalizedDescriptionKey: "Pinecone API key not set"])
        }
        
        let url = URL(string: "\(pineconeBaseURL)/indexes/\(name)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(pineconeApiKey)", forHTTPHeaderField: "Api-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "com.universalrag", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get index host"])
        }
        
        let indexResponse = try JSONDecoder().decode(PineconeIndexResponse.self, from: data)
        return indexResponse.host
    }
    
    // MARK: - Pinecone Vector Operations
    
    func upsertVectors(indexName: String, vectors: [PineconeVector], namespace: String?) async throws -> Int {
        guard !pineconeApiKey.isEmpty else {
            throw NSError(domain: "com.universalrag", code: 401, userInfo: [NSLocalizedDescriptionKey: "Pinecone API key not set"])
        }
        
        let host = try await getIndexHost(name: indexName)
        let url = URL(string: "https://\(host)/vectors/upsert")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(pineconeApiKey)", forHTTPHeaderField: "Api-Key")
        
        // Need to batch vectors to avoid timeout or payload size issues
        let maxBatchSize = 100
        var totalUpserted = 0
        
        for i in stride(from: 0, to: vectors.count, by: maxBatchSize) {
            let end = min(i + maxBatchSize, vectors.count)
            let batch = Array(vectors[i..<end])
            
            let vectorDicts = batch.map { $0.toDictionary() }
            
            var requestBody: [String: Any] = [
                "vectors": vectorDicts
            ]
            
            if let namespace = namespace, !namespace.isEmpty {
                requestBody["namespace"] = namespace
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "com.universalrag", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upsert vectors"])
            }
            
            let upsertResponse = try JSONDecoder().decode(PineconeUpsertResponse.self, from: data)
            totalUpserted += upsertResponse.upsertedCount
        }
        
        return totalUpserted
    }
    
    func queryVectors(indexName: String, vector: [Double], namespace: String?, topK: Int = 10) async throws -> [PineconeMatch] {
        guard !pineconeApiKey.isEmpty else {
            throw NSError(domain: "com.universalrag", code: 401, userInfo: [NSLocalizedDescriptionKey: "Pinecone API key not set"])
        }
        
        let host = try await getIndexHost(name: indexName)
        let url = URL(string: "https://\(host)/query")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("\(pineconeApiKey)", forHTTPHeaderField: "Api-Key")
        
        var requestBody: [String: Any] = [
            "vector": vector,
            "topK": topK,
            "includeMetadata": true
        ]
        
        if let namespace = namespace, !namespace.isEmpty {
            requestBody["namespace"] = namespace
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "com.universalrag", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to query vectors"])
        }
        
        let queryResponse = try JSONDecoder().decode(PineconeQueryResponse.self, from: data)
        return queryResponse.matches
    }
}
