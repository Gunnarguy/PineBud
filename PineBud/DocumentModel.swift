import Foundation
import SwiftUI

// MARK: - DocumentModel.swift
/// Represents a document in the RAG system
struct DocumentModel: Identifiable, Hashable {
    var id = UUID()
    var fileName: String
    var filePath: URL
    var mimeType: String
    var fileSize: Int64
    var dateAdded: Date
    var isProcessed: Bool = false
    var processingError: String? = nil
    var chunkCount: Int = 0
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DocumentModel, rhs: DocumentModel) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ChunkModel.swift
/// Represents a chunk of text from a document
struct ChunkModel: Identifiable, Codable {
    var id = UUID()
    var content: String
    var sourceDocument: String // File path or identifier
    var metadata: ChunkMetadata
    var contentHash: String
    var tokenCount: Int
    var pageNumber: Int?
    var isHeading: Bool?
    
    init(content: String, sourceDocument: String, metadata: ChunkMetadata, contentHash: String, tokenCount: Int, pageNumber: Int? = nil, isHeading: Bool? = false) {
        self.content = content
        self.sourceDocument = sourceDocument
        self.metadata = metadata
        self.contentHash = contentHash
        self.tokenCount = tokenCount
        self.pageNumber = pageNumber
        self.isHeading = isHeading
    }
}

/// Metadata for a chunk of text
struct ChunkMetadata: Codable {
    var source: String
    var chunkIndex: Int
    var totalChunks: Int
    var mimeType: String
    var dateProcessed: Date
    var position: ChunkPosition?
    var additionalMetadata: [String: String]?
    
    init(source: String, chunkIndex: Int, totalChunks: Int, mimeType: String,
         dateProcessed: Date = Date(), position: ChunkPosition? = nil, additionalMetadata: [String: String]? = nil) {
        self.source = source
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
        self.mimeType = mimeType
        self.dateProcessed = dateProcessed
        self.position = position
        self.additionalMetadata = additionalMetadata
    }
}

/// Position information for a chunk in a document
struct ChunkPosition: Codable {
    var page: Int?
    var rect: CGRect?
    var fontInfo: FontInfo?
    
    init(page: Int? = nil, rect: CGRect? = nil, fontInfo: FontInfo? = nil) {
        self.page = page
        self.rect = rect
        self.fontInfo = fontInfo
    }
}

/// Font information for text chunks
struct FontInfo: Codable {
    var size: CGFloat
    var isItalic: Bool
    var isBold: Bool
    var fontName: String?
    
    init(size: CGFloat, isItalic: Bool = false, isBold: Bool = false, fontName: String? = nil) {
        self.size = size
        self.isItalic = isItalic
        self.isBold = isBold
        self.fontName = fontName
    }
}

// MARK: - EmbeddingModel.swift
/// Represents a vector embedding for a chunk
struct EmbeddingModel: Identifiable, Codable {
    var id = UUID()
    var vectorId: String
    var vector: [Float]
    var chunkId: UUID
    var contentHash: String
    var metadata: [String: String]
    
    init(vectorId: String, vector: [Float], chunkId: UUID, contentHash: String, metadata: [String: String]) {
        self.vectorId = vectorId
        self.vector = vector
        self.chunkId = chunkId
        self.contentHash = contentHash
        self.metadata = metadata
    }
}

// MARK: - PineconeVector.swift
/// Represents a vector to be stored in Pinecone
struct PineconeVector: Codable {
    var id: String
    var values: [Float]
    var metadata: [String: String]
    
    init(id: String, values: [Float], metadata: [String: String]) {
        self.id = id
        self.values = values
        self.metadata = metadata
    }
}

// MARK: - SearchResultModel.swift
/// Represents a search result from the RAG system
struct SearchResultModel: Identifiable {
    var id = UUID()
    var content: String
    var sourceDocument: String
    var score: Float
    var metadata: [String: String]
    var isSelected: Bool = false
    
    init(content: String, sourceDocument: String, score: Float, metadata: [String: String]) {
        self.content = content
        self.sourceDocument = sourceDocument
        self.score = score
        self.metadata = metadata
    }
}

// MARK: - ChunkAnalytics.swift
/// Analytics data for text chunking process
struct ChunkAnalytics: Codable {
    var totalChunks: Int
    var totalTokens: Int
    var tokenDistribution: [Int]
    var chunkSizes: [Int]
    var mimeType: String
    var chunkStrategy: String
    var avgTokensPerChunk: Double
    var avgCharsPerChunk: Double
    var minTokens: Int
    var maxTokens: Int
    
    init(totalChunks: Int, totalTokens: Int, tokenDistribution: [Int], chunkSizes: [Int],
         mimeType: String, chunkStrategy: String, avgTokensPerChunk: Double, avgCharsPerChunk: Double,
         minTokens: Int, maxTokens: Int) {
        self.totalChunks = totalChunks
        self.totalTokens = totalTokens
        self.tokenDistribution = tokenDistribution
        self.chunkSizes = chunkSizes
        self.mimeType = mimeType
        self.chunkStrategy = chunkStrategy
        self.avgTokensPerChunk = avgTokensPerChunk
        self.avgCharsPerChunk = avgCharsPerChunk
        self.minTokens = minTokens
        self.maxTokens = maxTokens
    }
}

// MARK: - ProcessingLogEntry.swift
/// Represents a log entry in the processing log
struct ProcessingLogEntry: Identifiable {
    var id = UUID()
    var timestamp: Date
    var level: LogLevel
    var message: String
    var context: String?
    
    init(level: LogLevel, message: String, context: String? = nil) {
        self.timestamp = Date()
        self.level = level
        self.message = message
        self.context = context
    }
    
    enum LogLevel: String, CaseIterable {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case success = "SUCCESS"
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }
    }
}
