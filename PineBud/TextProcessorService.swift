// MARK: - DocumentModels.swift
import Foundation

struct DocumentMetadata: Codable {
    let id: String
    var url: URL
    let fileName: String
    let fileSize: Int64
    let dateAdded: Date
    let textContent: String
    var isIndexed: Bool
    var chunks: [TextChunk]
    
    private enum CodingKeys: String, CodingKey {
        case id, fileName, fileSize, dateAdded, textContent, isIndexed, chunks
    }
    
    init(id: String, url: URL, fileName: String, fileSize: Int64, dateAdded: Date, textContent: String, isIndexed: Bool, chunks: [TextChunk]) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.dateAdded = dateAdded
        self.textContent = textContent
        self.isIndexed = isIndexed
        self.chunks = chunks
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        textContent = try container.decode(String.self, forKey: .textContent)
        isIndexed = try container.decode(Bool.self, forKey: .isIndexed)
        chunks = try container.decode([TextChunk].self, forKey: .chunks)
        
        // URL is set separately after decoding
        url = URL(fileURLWithPath: "")
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(textContent, forKey: .textContent)
        try container.encode(isIndexed, forKey: .isIndexed)
        try container.encode(chunks, forKey: .chunks)
    }
}

struct DocumentItem: Identifiable {
    var id: String { metadata.id }
    var metadata: DocumentMetadata
}

struct TextChunk: Codable, Identifiable {
    let id: String
    let content: String
    let metadata: [String: String]
    var contentHash: String?
    var embedding: [Double]?
    
    init(id: String, content: String, metadata: [String: String], contentHash: String? = nil, embedding: [Double]? = nil) {
        self.id = id
        self.content = content
        self.metadata = metadata
        self.contentHash = contentHash
        self.embedding = embedding
    }
}
