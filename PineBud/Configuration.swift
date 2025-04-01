import Foundation

/// Configuration settings for the SwiftRAG application
struct Configuration {
    // OpenAI Configuration
    static let openAIAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    static let embeddingModel = "text-embedding-3-large"
    static let embeddingDimension = 3072
    static let completionModel = "gpt-4o"
    
    // Pinecone Configuration
    static let pineconeAPIKey = ProcessInfo.processInfo.environment["PINECONE_API_KEY"] ?? ""
    static let pineconeEnvironment = "us-east-1" // Default region
    
    // Document Processing Settings
    static let defaultChunkSize = 1024
    static let defaultChunkOverlap = 256
    
    // Maximum number of Pinecone indexes a user can create
    static let maxIndexes = 5
    
    // MIME Types supported for document processing
    static let acceptedMimeTypes: Set<String> = [
        // Document formats
        "application/pdf", "text/plain",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/msword",
        
        // Web formats
        "text/html", "text/css",
        
        // Data formats
        "text/markdown", "application/json", "application/xml",
        "text/csv", "text/tsv", "text/rtf", "application/rtf",
        
        // Code formats
        "application/x-python", "text/x-python",
        "application/javascript", "text/javascript",
        
        // Image formats (for OCR)
        "image/png", "image/jpeg", "image/gif", "image/tiff", "image/bmp"
    ]
    
    // Check if a MIME type is supported
    static func isMimeTypeSupported(_ mimeType: String) -> Bool {
        return acceptedMimeTypes.contains(mimeType)
    }
    
    // Get API keys from secure storage
    static func getOpenAIAPIKey() -> String {
        // In a real app, this would retrieve from KeyChain
        return openAIAPIKey
    }
    
    static func getPineconeAPIKey() -> String {
        // In a real app, this would retrieve from KeyChain
        return pineconeAPIKey
    }
    
    // Save API keys to secure storage
    static func saveOpenAIAPIKey(_ key: String) {
        // In a real app, this would save to KeyChain
        // For demonstration, we're just printing a confirmation
        print("OpenAI API key saved")
    }
    
    static func savePineconeAPIKey(_ key: String) {
        // In a real app, this would save to KeyChain
        // For demonstration, we're just printing a confirmation
        print("Pinecone API key saved")
    }
}
