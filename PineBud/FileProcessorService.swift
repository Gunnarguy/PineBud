import Foundation
import UIKit
import PDFKit
import Vision
import NaturalLanguage
import MobileCoreServices
import UniformTypeIdentifiers

/// Service for processing different file types and extracting text content
class FileProcessorService {
    
    private let logger = Logger.shared
    
    /// Process a file and extract text content based on its MIME type
    /// - Parameter url: URL to the file
    /// - Returns: A tuple containing the extracted text and MIME type
    func processFile(at url: URL) async throws -> (String?, String?) {
        // Determine the MIME type
        let mimeType = determineMimeType(for: url)
        
        guard let mime = mimeType, Configuration.isMimeTypeSupported(mime) else {
            logger.log(level: .warning, message: "Unsupported MIME type: \(mimeType ?? "unknown")")
            return (nil, mimeType)
        }
        
        // Process based on MIME type
        return try await (extractText(from: url, mimeType: mime), mime)
    }
    
    /// Determine the MIME type of a file
    /// - Parameter url: URL to the file
    /// - Returns: The MIME type as a string
    private func determineMimeType(for url: URL) -> String? {
        if #available(iOS 14.0, *) {
            // Use UTType in iOS 14+
            if let utType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
               let mimeType = UTType(utType.identifier)?.preferredMIMEType {
                return mimeType
            }
        }
        
        // Fallback for iOS 13 and earlier
        let fileExtension = url.pathExtension.lowercased()
        
        let mimeTypes: [String: String] = [
            "pdf": "application/pdf",
            "txt": "text/plain",
            "html": "text/html",
            "htm": "text/html",
            "csv": "text/csv",
            "json": "application/json",
            "md": "text/markdown",
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "doc": "application/msword",
            "rtf": "application/rtf"
        ]
        
        return mimeTypes[fileExtension]
    }
    
    /// Extract text content from a file based on its MIME type
    /// - Parameters:
    ///   - url: URL to the file
    ///   - mimeType: The MIME type of the file
    /// - Returns: The extracted text content
    private func extractText(from url: URL, mimeType: String) async throws -> String? {
        switch mimeType {
        case "application/pdf":
            return try await extractTextFromPDF(at: url)
        case "text/plain", "text/markdown", "text/csv", "text/html", "application/json":
            return try await extractTextFromPlainText(at: url)
        case "image/png", "image/jpeg", "image/gif", "image/tiff", "image/bmp":
            return try await extractTextFromImage(at: url)
        default:
            if let alternativeText = try? await extractTextFromPlainText(at: url) {
                return alternativeText
            }
            
            logger.log(level: .warning, message: "No specific extraction method for MIME type: \(mimeType)")
            return nil
        }
    }
    
    /// Extract text from a PDF file
    /// - Parameter url: URL to the PDF file
    /// - Returns: The extracted text content with structure preserved
    private func extractTextFromPDF(at url: URL) async throws -> String? {
        return await withCheckedContinuation { continuation in
            guard let pdfDocument = PDFDocument(url: url) else {
                logger.log(level: .error, message: "Failed to load PDF document")
                continuation.resume(returning: nil)
                return
            }
            
            var structuredChunks: [(text: String, page: Int, isHeading: Bool, fontSize: CGFloat, rect: CGRect)] = []
            let pageCount = pdfDocument.pageCount
            
            // Process each page
            for pageIndex in 0..<pageCount {
                guard let page = pdfDocument.page(at: pageIndex) else { continue }
                
                // Method 1: Use built-in attributedString
                if let attributedString = page.attributedString {
                    let processedText = processAttributedStringWithFormat(attributedString, pageNumber: pageIndex + 1)
                    structuredChunks.append(contentsOf: processedText)
                } else {
                    // Method 2: Use PDFKit's built-in string representation
                    if let pageText = page.string {
                        structuredChunks.append((pageText, pageIndex + 1, false, 12.0, .zero))
                    }
                }
            }
            
            // Reconstruct the text from structured chunks
            let finalText = structuredChunks
                .map { "\(isHeadingPrefix($0.isHeading))\($0.text) [Page \($0.page)]" }
                .joined(separator: "\n\n")
            
            continuation.resume(returning: finalText)
        }
    }
    
    /// Helper to add heading prefix
    private func isHeadingPrefix(_ isHeading: Bool) -> String {
        return isHeading ? "## " : ""
    }
    
    /// Process attributed string to extract formatting information
    private func processAttributedStringWithFormat(_ attributedString: NSAttributedString, pageNumber: Int) -> [(text: String, page: Int, isHeading: Bool, fontSize: CGFloat, rect: CGRect)] {
        var structuredChunks: [(text: String, page: Int, isHeading: Bool, fontSize: CGFloat, rect: CGRect)] = []
        
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length)) { attributes, range, _ in
            guard let font = attributes[.font] as? UIFont else { return }
            
            let text = attributedString.attributedSubstring(from: range).string
            let isHeading = font.pointSize > 14 // Heuristic for heading detection
            
            structuredChunks.append((text, pageNumber, isHeading, font.pointSize, .zero))
        }
        
        return structuredChunks
    }
    
    /// Extract text from a plain text file
    /// - Parameter url: URL to the text file
    /// - Returns: The extracted text content
    private func extractTextFromPlainText(at url: URL) async throws -> String? {
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    /// Extract text from an image using OCR
    /// - Parameter url: URL to the image file
    /// - Returns: The extracted text content
    private func extractTextFromImage(at url: URL) async throws -> String? {
        return await withCheckedContinuation { continuation in
            guard let uiImage = UIImage(contentsOfFile: url.path) else {
                logger.log(level: .error, message: "Failed to load image")
                continuation.resume(returning: nil)
                return
            }
            
            // Use Vision framework for OCR
            guard let cgImage = uiImage.cgImage else {
                logger.log(level: .error, message: "Failed to get CGImage from UIImage")
                continuation.resume(returning: nil)
                return
            }
            
            // Create a new Vision request
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    self.logger.log(level: .error, message: "OCR error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                // Process the results
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            // Configure the request
            request.recognitionLevel = .accurate
            
            // Create a request handler
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // Perform the request
            do {
                try requestHandler.perform([request])
            } catch {
                logger.log(level: .error, message: "Failed to perform OCR: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
}
