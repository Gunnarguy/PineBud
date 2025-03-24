// MARK: - DocumentManager.swift
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UTType {
    static let doc: UTType = UTType(mimeType: "application/msword")!
    static let docx: UTType = UTType(mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")!
}

import PDFKit
import Vision
import VisionKit
import NaturalLanguage
import UniformTypeIdentifiers
import CommonCrypto

class DocumentManager: ObservableObject {
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var documents: [DocumentItem] = []
    
    private let fileManager = FileManager.default
    private var processingQueue = DispatchQueue(label: "com.universalrag.processing", qos: .userInitiated, attributes: .concurrent)
    
    // Supported MIME types
    let supportedTypes: [UTType] = [
        .pdf,
        .plainText,
        .rtf,
        .html,
        .jpeg,
        .png,
        .tiff,
        UTType.doc,
        UTType.docx,
        .xml
    ]
    
    var supportedContentTypes: [UTType] {
        supportedTypes
    }
    
    // Directory to store processed documents
    var documentsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("UniversalRAG", isDirectory: true)
    }
    
    init() {
        // Create documents directory if it doesn't exist
        do {
            if !fileManager.fileExists(atPath: documentsDirectory.path) {
                try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Load saved documents
            loadSavedDocuments()
        } catch {
            print("Error setting up document directory: \(error.localizedDescription)")
        }
    }
    
    func loadSavedDocuments() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            
            let metadataURLs = fileURLs.filter { $0.lastPathComponent.hasSuffix(".metadata.json") }
            
            documents = metadataURLs.compactMap { url in
                let originalFileName = url.lastPathComponent.replacingOccurrences(of: ".metadata.json", with: "")
                let originalFileURL = documentsDirectory.appendingPathComponent(originalFileName)
                
                guard fileManager.fileExists(atPath: originalFileURL.path) else { return nil }
                
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    var metadata = try decoder.decode(DocumentMetadata.self, from: data)
                    metadata.url = originalFileURL
                    
                    return DocumentItem(metadata: metadata)
                } catch {
                    print("Error loading document metadata: \(error.localizedDescription)")
                    return nil
                }
            }
        } catch {
            print("Error loading saved documents: \(error.localizedDescription)")
        }
    }
    
    func processDocuments(urls: [URL]) async throws {
        guard !urls.isEmpty else { return }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingProgress = 0.0
        }
        
        var newDocuments: [DocumentItem] = []
        var processedCount = 0
        
        for url in urls {
            do {
                // Create a copy of the file in our documents directory
                let newURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                
                if url.startAccessingSecurityScopedResource() {
                    try fileManager.copyItem(at: url, to: newURL)
                    url.stopAccessingSecurityScopedResource()
                }
                
                // Extract text from document
                let text = try await self.extractText(from: newURL)
                
                // Create document metadata
                let metadata = DocumentMetadata(
                    id: UUID().uuidString,
                    url: newURL,
                    fileName: url.lastPathComponent,
                    fileSize: try fileManager.attributesOfItem(atPath: newURL.path)[.size] as? Int64 ?? 0,
                    dateAdded: Date(),
                    textContent: text,
                    isIndexed: false,
                    chunks: []
                )
                
                // Save metadata
                try saveDocumentMetadata(metadata)
                
                // Create document item
                let documentItem = DocumentItem(metadata: metadata)
                newDocuments.append(documentItem)
                
                // Update progress
                processedCount += 1
                let progress = Double(processedCount) / Double(urls.count)
                DispatchQueue.main.async {
                    self.processingProgress = progress
                }
            } catch {
                print("Error processing document \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Update documents list
        DispatchQueue.main.async {
            self.documents.append(contentsOf: newDocuments)
            self.isProcessing = false
            self.processingProgress = 1.0
        }
    }
    
    func extractText(from url: URL) async throws -> String {
        let fileType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
        
        if fileType == .pdf {
            return try await extractTextFromPDF(url: url)
        } else if fileType == .jpeg || fileType == .png || fileType == .tiff {
            return try await extractTextFromImage(url: url)
        } else if fileType == .html {
            return try extractTextFromHTML(url: url)
        } else if fileType == UTType.doc || fileType == UTType.docx {
            return try extractTextFromOfficeDocument(url: url)
        } else { // Plain text, RTF, and others
            return try extractTextFromTextFile(url: url)
        }
    }
    
    private func extractTextFromPDF(url: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw NSError(domain: "com.universalrag", code: 400, userInfo: [NSLocalizedDescriptionKey: "Could not open PDF"])
        }
        
        var extractedText = ""
        let settings = SettingsManager()
        let enableOCR = settings.enableOCR
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            
            let pageText = page.string ?? ""
            extractedText.append(pageText)
            
            // If page has little text and OCR is enabled, try OCR
            if enableOCR && pageText.count < 100 {
                let pageImage = page.thumbnail(of: CGSize(width: 1024, height: 1024), for: .cropBox)
                do {
                    let ocrText = try await performOCR(on: pageImage)
                    if ocrText.count > pageText.count {
                        extractedText.append("\n\n\(ocrText)")
                    }
                } catch {
                    print("OCR failed for page \(i): \(error.localizedDescription)")
                }
            }
            
            extractedText.append("\n\n")
        }
        
        return extractedText
    }
    
    private func extractTextFromImage(url: URL) async throws -> String {
        guard let image = UIImage(contentsOfFile: url.path) else {
            throw NSError(domain: "com.universalrag", code: 400, userInfo: [NSLocalizedDescriptionKey: "Could not load image"])
        }
        
        let settings = SettingsManager()
        if (!settings.enableOCR) {
            return "[Image content - OCR disabled]"
        }
        
        // Check if the image is valid before proceeding with OCR
        if image.size == CGSize.zero {
            return "[Invalid image content]"
        }
        
        return try await performOCR(on: image)
    }
    
    private func extractTextFromHTML(url: URL) throws -> String {
        let htmlString = try String(contentsOf: url, encoding: .utf8)
        
        // Basic HTML to text conversion
        var text = htmlString
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&[^;]+;", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }
    
    private func extractTextFromTextFile(url: URL) throws -> String {
        // Try different encodings
        let encodings: [String.Encoding] = [.utf8, .ascii, .isoLatin1, .utf16, .windowsCP1252]
        
        for encoding in encodings {
            do {
                return try String(contentsOf: url, encoding: encoding)
            } catch {}
        }
        
        // If all encodings fail, use a fallback
        guard let data = try? Data(contentsOf: url) else {
            return "[Could not read file contents]"
        }
        
        return String(decoding: data, as: UTF8.self)
    }
    
    private func extractTextFromOfficeDocument(url: URL) throws -> String {
        // In a real app, you would use a library for processing Office documents
        // Here we'll use a placeholder implementation
        return "[Office document content would be extracted here]"
    }
    
    private func performOCR(on image: UIImage?) async throws -> String {
        guard let unwrappedImage = image, let cgImage = unwrappedImage.cgImage else {
            throw NSError(domain: "com.universalrag", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: " ")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func saveDocumentMetadata(_ metadata: DocumentMetadata) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        
        let metadataURL = documentsDirectory.appendingPathComponent("\(metadata.fileName).metadata.json")
        try data.write(to: metadataURL)
    }
    
    func deleteDocument(_ document: DocumentItem) throws {
        // Delete the document file
        try fileManager.removeItem(at: document.metadata.url)
        
        // Delete the metadata file
        let metadataURL = documentsDirectory.appendingPathComponent("\(document.metadata.fileName).metadata.json")
        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }
        
        // Update the documents array
        DispatchQueue.main.async {
            self.documents.removeAll { $0.id == document.id }
        }
    }
    
    func chunkDocument(_ document: DocumentItem, chunkSize: Int, chunkOverlap: Int) -> [TextChunk] {
        let text = document.metadata.textContent
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var chunks: [TextChunk] = []
        var currentChunkStart = text.startIndex
        var wordCount = 0
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            wordCount += 1
            
            // If we've reached the chunk size, create a chunk
            if wordCount >= chunkSize {
                let chunkText = String(text[currentChunkStart..<tokenRange.upperBound])
                
                // Generate a hash for the chunk content
                let contentHash = generateHash(for: chunkText)
                
                let chunk = TextChunk(
                    id: UUID().uuidString,
                    content: chunkText,
                    metadata: [
                        "source": document.metadata.fileName,
                        "chunk_id": String(chunks.count),
                        "document_id": document.id
                    ],
                    contentHash: contentHash
                )
                
                chunks.append(chunk)
                
                // Calculate new starting point with overlap
                var newStartTokenCount = 0
                var newStart = currentChunkStart
                
                tokenizer.enumerateTokens(in: currentChunkStart..<tokenRange.upperBound) { innerRange, _ in
                    newStartTokenCount += 1
                    if newStartTokenCount > (chunkSize - chunkOverlap) {
                        newStart = innerRange.lowerBound
                        return false
                    }
                    return true
                }
                
                currentChunkStart = newStart
                wordCount = 0
            }
            
            return true
        }
        
        // Add the final chunk if there's text remaining
        if currentChunkStart < text.endIndex {
            let chunkText = String(text[currentChunkStart..<text.endIndex])
            let contentHash = generateHash(for: chunkText)
            
            let chunk = TextChunk(
                id: UUID().uuidString,
                content: chunkText,
                metadata: [
                    "source": document.metadata.fileName,
                    "chunk_id": String(chunks.count),
                    "document_id": document.id
                ],
                contentHash: contentHash
            )
            
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    func generateHash(for text: String) -> String {
        guard let data = text.data(using: .utf8) else { return UUID().uuidString }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = data.withUnsafeBytes {
            CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    func updateDocumentChunks(_ document: DocumentItem, chunks: [TextChunk]) throws {
        var metadata = document.metadata
        metadata.chunks = chunks
        
        try saveDocumentMetadata(metadata)
        
        // Update document in memory
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index].metadata = metadata
        }
    }
    
    func markDocumentAsIndexed(_ document: DocumentItem) throws {
        var metadata = document.metadata
        metadata.isIndexed = true
        
        try saveDocumentMetadata(metadata)
        
        // Update document in memory
        if let index = documents.firstIndex(where: { $0.id == document.id }) {
            documents[index].metadata = metadata
        }
    }
}
