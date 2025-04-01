import Foundation

/// Service for generating embeddings from text
class EmbeddingService {
    
    private let logger = Logger.shared
    private let openAIService: OpenAIService
    
    init(openAIService: OpenAIService) {
        self.openAIService = openAIService
    }
    
    /// Generate embeddings for a list of text chunks
    /// - Parameter chunks: Array of ChunkModel objects
    /// - Returns: Array of EmbeddingModel objects
    func generateEmbeddings(for chunks: [ChunkModel]) async throws -> [EmbeddingModel] {
        let texts = chunks.map { $0.content }
        let embeddings = try await openAIService.createEmbeddings(texts: texts)
        
        guard embeddings.count == chunks.count else {
            logger.log(level: .error, message: "Embedding count mismatch: \(embeddings.count) embeddings for \(chunks.count) chunks")
            throw EmbeddingError.countMismatch
        }
        
        var embeddingModels: [EmbeddingModel] = []
        
        for (index, vector) in embeddings.enumerated() {
            let chunk = chunks[index]
            let vectorId = "\(chunk.contentHash)_\(index)"
            
            let metadata: [String: String] = [
                "text": chunk.content,
                "source": chunk.sourceDocument,
                "hash": chunk.contentHash
            ]
            
            let embeddingModel = EmbeddingModel(
                vectorId: vectorId,
                vector: vector,
                chunkId: chunk.id,
                contentHash: chunk.contentHash,
                metadata: metadata
            )
            
            embeddingModels.append(embeddingModel)
        }
        
        return embeddingModels
    }
    
    /// Generate a single embedding for a query text
    /// - Parameter query: The query text
    /// - Returns: A vector embedding
    func generateQueryEmbedding(for query: String) async throws -> [Float] {
        let embeddings = try await openAIService.createEmbeddings(texts: [query])
        
        guard let embedding = embeddings.first else {
            logger.log(level: .error, message: "Failed to generate embedding for query")
            throw EmbeddingError.generationFailed
        }
        
        return embedding
    }
    
    /// Calculate cosine similarity between two vectors
    /// - Parameters:
    ///   - a: First vector
    ///   - b: Second vector
    /// - Returns: Cosine similarity score
    func cosineSimilarity(a: [Float], b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else {
            return 0
        }
        
        let dotProduct = zip(a, b).map { $0 * $1 }.reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0, magnitudeB > 0 else {
            return 0
        }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    /// Convert embeddings to Pinecone format
    /// - Parameter embeddings: Array of EmbeddingModel objects
    /// - Returns: Array of PineconeVector objects
    func convertToPineconeVectors(from embeddings: [EmbeddingModel]) -> [PineconeVector] {
        return embeddings.map { embedding in
            PineconeVector(
                id: embedding.vectorId,
                values: embedding.vector,
                metadata: embedding.metadata
            )
        }
    }
    
    /// Local search when Pinecone is not available (for small datasets)
    /// - Parameters:
    ///   - queryEmbedding: Query vector embedding
    ///   - embeddings: Array of EmbeddingModel objects
    ///   - topK: Number of results to return
    /// - Returns: Array of search results with similarities
    func localSearch(queryEmbedding: [Float], embeddings: [EmbeddingModel], topK: Int) -> [(EmbeddingModel, Float)] {
        let similarities = embeddings.map { embedding in
            (embedding, cosineSimilarity(a: queryEmbedding, b: embedding.vector))
        }
        
        return similarities
            .sorted { $0.1 > $1.1 } // Sort by similarity (descending)
            .prefix(topK) // Take only top K results
            .map { ($0.0, $0.1) }
    }
}

enum EmbeddingError: Error {
    case generationFailed
    case countMismatch
    case dimensionMismatch
    case apiError(String)
}
