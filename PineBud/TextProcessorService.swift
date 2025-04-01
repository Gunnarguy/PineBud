import Foundation
import NaturalLanguage

/// Service for processing text: chunking, tokenization, and analysis
class TextProcessorService {
    
    private let logger = Logger.shared
    
    // Tokenizer for counting tokens
    private let tokenizer: NLTokenizer
    
    init() {
        tokenizer = NLTokenizer(unit: .word)
    }
    
    /// Count tokens in a text string
    /// - Parameter text: The text to count tokens in
    /// - Returns: The token count
    func countTokens(in text: String) -> Int {
        tokenizer.string = text
        var tokenCount = 0
        
        // Use Range<String.Index> for enumerateTokens
        let stringRange = text.startIndex..<text.endIndex
        tokenizer.enumerateTokens(in: stringRange) { _, _ in
            tokenCount += 1
            return true
        }
        
        return tokenCount
    }
    
    /// Split text into chunks based on MIME type
    /// - Parameters:
    ///   - text: The text to split
    ///   - metadata: Metadata for the chunks
    ///   - mimeType: The MIME type of the original document
    /// - Returns: A tuple containing chunks and analytics
    func chunkText(text: String, metadata: [String: String], mimeType: String) -> ([ChunkModel], ChunkAnalytics) {
        guard !text.isEmpty else {
            return ([], ChunkAnalytics(
                totalChunks: 0,
                totalTokens: 0,
                tokenDistribution: [],
                chunkSizes: [],
                mimeType: mimeType,
                chunkStrategy: "None",
                avgTokensPerChunk: 0,
                avgCharsPerChunk: 0,
                minTokens: 0,
                maxTokens: 0
            ))
        }
        
        // Get the appropriate chunking strategy based on MIME type
        let (chunkSize, chunkOverlap, separators) = getChunkParametersForMimeType(mimeType)
        
        let chunkingStrategy = "RecursiveTextSplitter"
        var chunks: [ChunkModel] = []
        
        // Split the text into chunks
        let textChunks = splitTextRecursively(
            text: text,
            chunkSize: chunkSize,
            chunkOverlap: chunkOverlap,
            separators: separators
        )
        
        // Initialize analytics variables
        var tokenDistribution: [Int] = []
        var chunkSizes: [Int] = []
        var totalTokens = 0
        
        // Process each chunk and gather analytics
        for (index, chunkText) in textChunks.enumerated() {
            let tokenCount = countTokens(in: chunkText)
            totalTokens += tokenCount
            tokenDistribution.append(tokenCount)
            chunkSizes.append(chunkText.count)
            
            // Create a content hash
            let contentHash = generateContentHash(for: chunkText)
            
            // Create chunk metadata
            let chunkMetadata = ChunkMetadata(
                source: metadata["source"] ?? "Unknown",
                chunkIndex: index,
                totalChunks: textChunks.count,
                mimeType: mimeType,
                dateProcessed: Date()
            )
            
            // Create chunk model
            let chunk = ChunkModel(
                content: chunkText,
                sourceDocument: metadata["source"] ?? "Unknown",
                metadata: chunkMetadata,
                contentHash: contentHash,
                tokenCount: tokenCount
            )
            
            chunks.append(chunk)
        }
        
        // Calculate analytics
        let avgTokensPerChunk = totalTokens > 0 && !chunks.isEmpty ? Double(totalTokens) / Double(chunks.count) : 0
        let avgCharsPerChunk = !chunkSizes.isEmpty ? Double(chunkSizes.reduce(0, +)) / Double(chunkSizes.count) : 0
        let minTokens = tokenDistribution.min() ?? 0
        let maxTokens = tokenDistribution.max() ?? 0
        
        let analytics = ChunkAnalytics(
            totalChunks: chunks.count,
            totalTokens: totalTokens,
            tokenDistribution: tokenDistribution,
            chunkSizes: chunkSizes,
            mimeType: mimeType,
            chunkStrategy: chunkingStrategy,
            avgTokensPerChunk: avgTokensPerChunk,
            avgCharsPerChunk: avgCharsPerChunk,
            minTokens: minTokens,
            maxTokens: maxTokens
        )
        
        return (chunks, analytics)
    }
    
    /// Get the appropriate chunking parameters based on MIME type
    /// - Parameter mimeType: The MIME type of the document
    /// - Returns: A tuple containing chunk size, overlap, and separators
    private func getChunkParametersForMimeType(_ mimeType: String) -> (Int, Int, [String]) {
        switch mimeType {
        case "application/pdf":
            return (1200, 200, ["\n\n", "\n", ". ", " ", ""])
        case "text/plain", "text/markdown", "text/rtf", "application/rtf", "text/csv", "text/tsv":
            return (800, 150, ["\n\n", "\n", ". ", " ", ""])
        case "application/x-python", "text/x-python", "application/javascript", "text/javascript", "text/css":
            return (500, 50, ["\n\n", "\n", ". ", " ", ""])
        case "text/html":
            return (1000, 200, ["\n\n", "\n", ". ", " ", ""])
        default:
            return (Configuration.defaultChunkSize, Configuration.defaultChunkOverlap, ["\n\n", "\n", ". ", " ", ""])
        }
    }
    
    /// Split text recursively using multiple separators
    /// - Parameters:
    ///   - text: The text to split
    ///   - chunkSize: Maximum size of each chunk
    ///   - chunkOverlap: Overlap between chunks
    ///   - separators: Array of separators to try in order
    /// - Returns: Array of text chunks
    private func splitTextRecursively(text: String, chunkSize: Int, chunkOverlap: Int, separators: [String]) -> [String] {
        // Base case: if we're at the last separator or text is smaller than chunk size
        if separators.isEmpty || text.count <= chunkSize {
            return [text]
        }
        
        let separator = separators[0]
        let components = text.components(separatedBy: separator)
        
        // If splitting with this separator doesn't help, try the next one
        if components.count <= 1 {
            return splitTextRecursively(
                text: text,
                chunkSize: chunkSize,
                chunkOverlap: chunkOverlap,
                separators: Array(separators.dropFirst())
            )
        }
        
        var chunks: [String] = []
        var currentChunk = ""
        
        for component in components {
            let potentialChunk = currentChunk.isEmpty ? component : currentChunk + separator + component
            
            if potentialChunk.count <= chunkSize {
                currentChunk = potentialChunk
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                }
                
                // If the component itself is larger than the chunk size, recursively split it
                if component.count > chunkSize {
                    let subChunks = splitTextRecursively(
                        text: component,
                        chunkSize: chunkSize,
                        chunkOverlap: chunkOverlap,
                        separators: Array(separators.dropFirst())
                    )
                    chunks.append(contentsOf: subChunks)
                    currentChunk = ""
                } else {
                    currentChunk = component
                }
            }
        }
        
        // Add the last chunk if it's not empty
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        // Apply overlap if needed
        if chunkOverlap > 0 && chunks.count > 1 {
            var overlapChunks: [String] = []
            
            for i in 0..<chunks.count {
                if i == 0 {
                    overlapChunks.append(chunks[i])
                } else {
                    let previousChunk = chunks[i-1]
                    let currentChunk = chunks[i]
                    
                    // Calculate overlap from previous chunk
                    var overlapText = ""
                    if previousChunk.count > chunkOverlap {
                        let startIndex = previousChunk.index(previousChunk.endIndex, offsetBy: -chunkOverlap)
                        overlapText = String(previousChunk[startIndex...])
                    } else {
                        overlapText = previousChunk
                    }
                    
                    overlapChunks.append(overlapText + separator + currentChunk)
                }
            }
            
            return overlapChunks
        }
        
        return chunks
    }
    
    /// Generate a content hash for a text chunk
    /// - Parameter text: The text to hash
    /// - Returns: A hash string
    private func generateContentHash(for text: String) -> String {
        let data = Data(text.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Tokenize text and return information about the tokens
    /// - Parameter text: The text to tokenize
    /// - Returns: Array of tokens with ranges
    func tokenizeText(_ text: String) -> [(token: String, range: NSRange)] {
        tokenizer.string = text
        var tokens: [(token: String, range: NSRange)] = []
        
        // Use Range<String.Index> for enumerateTokens
        let stringRange = text.startIndex..<text.endIndex
        tokenizer.enumerateTokens(in: stringRange) { tokenRange, _ in
            // Convert Range<String.Index> back to NSRange if needed for the return type
            let nsRange = NSRange(tokenRange, in: text)
            let token = String(text[tokenRange])
            tokens.append((token, nsRange))
            return true // Continue enumeration
        } // End of enumerateTokens closure
        
        return tokens // Return the collected tokens
    } // End of tokenizeText function
}

// MARK: - SHA256 Implementation
struct SHA256 {
    
    private static func rotate(_ value: UInt32, by: UInt32) -> UInt32 {
        return ((value >> by) | (value << (32 - by)))
    }
    
    static func hash(data: Data) -> [UInt8] {
        // Implementation of SHA-256 algorithm
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]
        
        // Initialize variables
        var h0: UInt32 = 0x6a09e667
        var h1: UInt32 = 0xbb67ae85
        var h2: UInt32 = 0x3c6ef372
        var h3: UInt32 = 0xa54ff53a
        var h4: UInt32 = 0x510e527f
        var h5: UInt32 = 0x9b05688c
        var h6: UInt32 = 0x1f83d9ab
        var h7: UInt32 = 0x5be0cd19
        
        // Prepare message
        var message = data
        let byteLength = data.count
        let bitLength = UInt64(byteLength * 8)
        
        // Append the bit '1' to the message
        message.append(0x80)
        
        // Append 0 ≤ k < 512 bits '0', such that the resulting message length in bits
        // is congruent to 448 (mod 512)
        let zeroPadding = (56 - (message.count % 64)) % 64
        message.append(contentsOf: [UInt8](repeating: 0, count: zeroPadding))
        
        // Append bit length of message as 64-bit big-endian integer
        for i in (0...7).reversed() {
            message.append(UInt8((bitLength >> UInt64(i * 8)) & 0xff))
        }
        
        // Process the message in successive 512-bit chunks
        for chunkStart in stride(from: 0, to: message.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            
            // Break chunk into sixteen 32-bit big-endian words
            for i in 0..<16 {
                let start = chunkStart + i * 4
                w[i] = UInt32(message[start]) << 24 |
                       UInt32(message[start + 1]) << 16 |
                       UInt32(message[start + 2]) << 8 |
                       UInt32(message[start + 3])
            }
            
            // Extend the sixteen 32-bit words into sixty-four 32-bit words
            for i in 16..<64 {
                let s0 = rotate(w[i-15], by: 7) ^ rotate(w[i-15], by: 18) ^ (w[i-15] >> 3)
                let s1 = rotate(w[i-2], by: 17) ^ rotate(w[i-2], by: 19) ^ (w[i-2] >> 10)
                w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
            }
            
            // Initialize working variables
            var a = h0
            var b = h1
            var c = h2
            var d = h3
            var e = h4
            var f = h5
            var g = h6
            var h = h7
            
            // Main loop
            for i in 0..<64 {
                let S1 = rotate(e, by: 6) ^ rotate(e, by: 11) ^ rotate(e, by: 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = h &+ S1 &+ ch &+ k[i] &+ w[i]
                let S0 = rotate(a, by: 2) ^ rotate(a, by: 13) ^ rotate(a, by: 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = S0 &+ maj
                
                h = g
                g = f
                f = e
                e = d &+ temp1
                d = c
                c = b
                b = a
                a = temp1 &+ temp2
            }
            
            // Add the compressed chunk to the current hash value
            h0 = h0 &+ a
            h1 = h1 &+ b
            h2 = h2 &+ c
            h3 = h3 &+ d
            h4 = h4 &+ e
            h5 = h5 &+ f
            h6 = h6 &+ g
            h7 = h7 &+ h
        }
        
        // Produce the final hash value (big-endian)
        return [
            UInt8(h0 >> 24), UInt8(h0 >> 16), UInt8(h0 >> 8), UInt8(h0),
            UInt8(h1 >> 24), UInt8(h1 >> 16), UInt8(h1 >> 8), UInt8(h1),
            UInt8(h2 >> 24), UInt8(h2 >> 16), UInt8(h2 >> 8), UInt8(h2),
            UInt8(h3 >> 24), UInt8(h3 >> 16), UInt8(h3 >> 8), UInt8(h3),
            UInt8(h4 >> 24), UInt8(h4 >> 16), UInt8(h4 >> 8), UInt8(h4),
            UInt8(h5 >> 24), UInt8(h5 >> 16), UInt8(h5 >> 8), UInt8(h5),
            UInt8(h6 >> 24), UInt8(h6 >> 16), UInt8(h6 >> 8), UInt8(h6),
            UInt8(h7 >> 24), UInt8(h7 >> 16), UInt8(h7 >> 8), UInt8(h7)
        ]
    }
}
