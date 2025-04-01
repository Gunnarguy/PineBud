import Foundation

/// Service for interacting with Pinecone vector database
class PineconeService {
    
    private let logger = Logger.shared
    private let apiKey: String
    private let baseURL = "https://api.pinecone.io"
    private var indexHost: String?
    private var currentIndex: String?
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Set the current index
    /// - Parameter indexName: Name of the index
    func setCurrentIndex(_ indexName: String) async throws {
        self.currentIndex = indexName
        try await getIndexHost(for: indexName)
    }
    
    /// Get the host URL for a Pinecone index
    /// - Parameter indexName: Name of the index
    /// - Returns: Host URL
    private func getIndexHost(for indexName: String) async throws {
        let endpoint = "\(baseURL)/indexes/\(indexName)"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PineconeError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                logger.log(level: .error, message: "Pinecone API error: \(errorMessage?.message ?? "Unknown error")")
                throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.message)
            }
            
            let indexInfo = try JSONDecoder().decode(IndexDescribeResponse.self, from: data)
            self.indexHost = indexInfo.host
            logger.log(level: .info, message: "Index host set to: \(indexInfo.host)")
        } catch {
            logger.log(level: .error, message: "Failed to get index host: \(error.localizedDescription)")
            throw PineconeError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
    
    /// List all available Pinecone indexes
    /// - Returns: Array of index names
    func listIndexes() async throws -> [String] {
        let endpoint = "\(baseURL)/indexes"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PineconeError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                logger.log(level: .error, message: "Pinecone API error: \(errorMessage?.message ?? "Unknown error")")
                throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.message)
            }
            
            let indexList = try JSONDecoder().decode(IndexListResponse.self, from: data)
            return indexList.indexes.map { $0.name }
        } catch {
            logger.log(level: .error, message: "Failed to list indexes: \(error.localizedDescription)")
            throw PineconeError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
    
    /// Create a new Pinecone index
    /// - Parameters:
    ///   - name: Name of the index
    ///   - dimension: Dimension of the vectors
    /// - Returns: Response from the Pinecone API
    func createIndex(name: String, dimension: Int) async throws -> IndexCreateResponse {
        let endpoint = "\(baseURL)/indexes"
        
        let body: [String: Any] = [
            "name": name,
            "dimension": dimension,
            "metric": "cosine",
            "spec": [
                "serverless": [
                    "cloud": "aws",
                    "region": Configuration.pineconeEnvironment
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw PineconeError.invalidRequestData
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PineconeError.invalidResponse
            }
            
            if httpResponse.statusCode != 201 && httpResponse.statusCode != 200 {
                let errorMessage = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                logger.log(level: .error, message: "Pinecone API error: \(errorMessage?.message ?? "Unknown error")")
                throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.message)
            }
            
            return try JSONDecoder().decode(IndexCreateResponse.self, from: data)
        } catch {
            logger.log(level: .error, message: "Failed to create index: \(error.localizedDescription)")
            throw PineconeError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
    
    /// Check if an index is ready for use
    /// - Parameter name: Name of the index
    /// - Returns: True if the index is ready
    func isIndexReady(name: String) async throws -> Bool {
        let endpoint = "\(baseURL)/indexes/\(name)"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PineconeError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: "Index not found")
            }
            
            let indexInfo = try JSONDecoder().decode(IndexDescribeResponse.self, from: data)
            return indexInfo.status.state == "Ready"
        } catch {
            logger.log(level: .error, message: "Failed to check index status: \(error.localizedDescription)")
            throw PineconeError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
    
    /// Wait for an index to become ready
    /// - Parameters:
    ///   - name: Name of the index
    ///   - timeout: Timeout in seconds
    ///   - pollInterval: Polling interval in seconds
    /// - Returns: True if the index became ready within the timeout
    func waitForIndexReady(name: String, timeout: Int = 60, pollInterval: Int = 2) async throws -> Bool {
        let startTime = Date().timeIntervalSince1970
        
        while Date().timeIntervalSince1970 - startTime < Double(timeout) {
            do {
                let isReady = try await isIndexReady(name: name)
                if isReady {
                    return true
                }
            } catch {
                // Continue polling even if there's an error
                logger.log(level: .warning, message: "Error checking index status: \(error.localizedDescription)")
            }
            
            try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
        }
        
        return false
    }
    
    /// List namespaces for the current index
    /// - Returns: Array of namespace names
    func listNamespaces() async throws -> [String] {
        guard let indexHost = indexHost, let _ = currentIndex else { // Replaced currentIndex with _
            throw PineconeError.noIndexSelected
        }
        
        let endpoint = "https://\(indexHost)/describe_index_stats"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PineconeError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                logger.log(level: .error, message: "Pinecone API error: \(errorMessage?.message ?? "Unknown error")")
                throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.message)
            }
            
            let indexStats = try JSONDecoder().decode(IndexStatsResponse.self, from: data)
            return Array(indexStats.namespaces.keys)
        } catch {
            logger.log(level: .error, message: "Failed to list namespaces: \(error.localizedDescription)")
            throw PineconeError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
    
    /// Upsert vectors to the current index
    /// - Parameters:
    ///   - vectors: Array of vectors to upsert
    ///   - namespace: Namespace to upsert to
    /// - Returns: Upsert response from Pinecone
    func upsertVectors(_ vectors: [PineconeVector], namespace: String? = nil) async throws -> UpsertResponse {
        guard let indexHost = indexHost else {
            throw PineconeError.noIndexSelected
        }
        
        let endpoint = "https://\(indexHost)/vectors/upsert"
        
        var body: [String: Any] = [
            "vectors": vectors.map { vector in
                [
                    "id": vector.id,
                    "values": vector.values,
                    "metadata": vector.metadata
                ]
            }
        ]
        
        if let namespace = namespace {
            body["namespace"] = namespace
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw PineconeError.invalidRequestData
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PineconeError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                logger.log(level: .error, message: "Pinecone API error: \(errorMessage?.message ?? "Unknown error")")
                throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.message)
            }
            
            return try JSONDecoder().decode(UpsertResponse.self, from: data)
        } catch {
            logger.log(level: .error, message: "Failed to upsert vectors: \(error.localizedDescription)")
            throw PineconeError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
    
    /// Query the current index
    /// - Parameters:
    ///   - vector: Query vector
    ///   - topK: Number of results to return
    ///   - namespace: Namespace to query
    /// - Returns: Query response from Pinecone
    func query(vector: [Float], topK: Int = 10, namespace: String? = nil) async throws -> QueryResponse {
        guard let indexHost = indexHost else {
            throw PineconeError.noIndexSelected
        }
        
        let endpoint = "https://\(indexHost)/query"
        
        var body: [String: Any] = [
            "vector": vector,
            "topK": topK,
            "includeMetadata": true
        ]
        
        if let namespace = namespace {
            body["namespace"] = namespace
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw PineconeError.invalidRequestData
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PineconeError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data)
                logger.log(level: .error, message: "Pinecone API error: \(errorMessage?.message ?? "Unknown error")")
                throw PineconeError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.message)
            }
            
            return try JSONDecoder().decode(QueryResponse.self, from: data)
        } catch {
            logger.log(level: .error, message: "Failed to query: \(error.localizedDescription)")
            throw PineconeError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
}

// MARK: - Response Models

struct IndexListResponse: Codable {
    let indexes: [IndexInfo]
}

struct IndexInfo: Codable {
    let name: String
    let dimension: Int?
    let metric: String?
    let host: String?
    let spec: IndexSpec?
}

struct IndexSpec: Codable {
    let serverless: ServerlessSpec?
}

struct ServerlessSpec: Codable {
    let cloud: String?
    let region: String?
}

struct IndexCreateResponse: Codable {
    let name: String
    let dimension: Int
    let metric: String
    let host: String?
    let status: IndexStatus?
}

struct IndexDescribeResponse: Codable {
    let name: String
    let dimension: Int
    let metric: String
    let host: String
    let status: IndexStatus
}

struct IndexStatus: Codable {
    let state: String
    let ready: Bool
}

struct IndexStatsResponse: Codable {
    let namespaces: [String: NamespaceStats]
    let dimension: Int
    let totalVectorCount: Int
    
    enum CodingKeys: String, CodingKey {
        case namespaces
        case dimension
        case totalVectorCount = "totalVectorCount"
    }
}

struct NamespaceStats: Codable {
    let vectorCount: Int
}

struct UpsertResponse: Codable {
    let upsertedCount: Int
}

struct QueryResponse: Codable {
    let matches: [QueryMatch]
    let namespace: String?
}

struct QueryMatch: Codable {
    let id: String
    let score: Float
    let metadata: [String: String]?
}

struct PineconeErrorResponse: Codable {
    let message: String?
    let code: Int?
}

enum PineconeError: Error {
    case invalidRequestData
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)
    case noIndexSelected
}
