// MARK: - APIModels.swift
import Foundation

// OpenAI API Models
struct OpenAIErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let message: String
        let type: String
    }
    
    let error: ErrorDetail
}

struct OpenAIEmbeddingsResponse: Codable {
    struct EmbeddingData: Codable {
        let embedding: [Double]
        let index: Int
    }
    
    let data: [EmbeddingData]
    let model: String
    let usage: [String: Int]
}

struct OpenAIChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        
        let message: Message
        let finish_reason: String
        let index: Int
    }
    
    let id: String
    let choices: [Choice]
}

// Pinecone API Models
struct PineconeListIndexesResponse: Codable {
    struct IndexInfo: Codable {
        let name: String
    }
    
    let indexes: [IndexInfo]
}

struct PineconeIndexResponse: Codable {
    struct Status: Codable {
        let state: String
    }
    
    let name: String
    let dimension: Int
    let metric: String
    let host: String
    let status: Status
}

struct PineconeStatsResponse: Codable {
    struct NamespaceStats: Codable {
        let vectorCount: Int
        
        enum CodingKeys: String, CodingKey {
            case vectorCount = "vectorCount"
        }
    }
    
    let namespaces: [String: NamespaceStats]
    let dimension: Int
    let totalVectorCount: Int
    
    enum CodingKeys: String, CodingKey {
        case namespaces
        case dimension
        case totalVectorCount = "totalVectorCount"
    }
}

struct PineconeVector {
    let id: String
    let values: [Double]
    let metadata: [String: Any]
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "values": values,
            "metadata": metadata
        ]
    }
}

struct PineconeMatch: Codable {
    let id: String
    let score: Double
    let metadata: [String: Any]
    
    private enum CodingKeys: String, CodingKey {
        case id, score, metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        score = try container.decode(Double.self, forKey: .score)
        
        // Decode metadata as [String: Any]
        let metadataContainer = try container.decode([String: AnyCodable].self, forKey: .metadata)
        var decodedMetadata = [String: Any]()
        for (key, value) in metadataContainer {
            decodedMetadata[key] = value.value
        }
        metadata = decodedMetadata
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(score, forKey: .score)
        
        // Encode metadata as [String: AnyCodable]
        var encodableMetadata = [String: AnyCodable]()
        for (key, value) in metadata {
            encodableMetadata[key] = AnyCodable(value)
        }
        try container.encode(encodableMetadata, forKey: .metadata)
    }
}

struct PineconeUpsertResponse: Codable {
    let upsertedCount: Int
}

struct PineconeQueryResponse: Codable {
    let matches: [PineconeMatch]
    let namespace: String?
}

// Helper for encoding/decoding Any values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self.value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value")
            throw EncodingError.invalidValue(value, context)
        }
    }
}


