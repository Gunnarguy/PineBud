// MARK: - DocumentsView.swift
import SwiftUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var showDocumentPicker = false
    @State private var isIndexing = false
    @State private var indexingProgress: Double = 0.0
    @State private var selectedDocument: DocumentItem?
    @State private var showDocumentDetails = false
    @State private var searchText = ""
    @State private var showActionSheet = false
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: DocumentItem?
    
    var filteredDocuments: [DocumentItem] {
        if searchText.isEmpty {
            return documentManager.documents
        } else {
            return documentManager.documents.filter {
                $0.metadata.fileName.localizedCaseInsensitiveContains(searchText) ||
                $0.metadata.textContent.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            // Search bar
            if !documentManager.documents.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search documents", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Document list
            if documentManager.documents.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Documents")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Add documents to get started")
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        Label("Add Documents", systemImage: "plus")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top)
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredDocuments) { document in
                        DocumentRow(document: document)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDocument = document
                                showDocumentDetails = true
                            }
                            .contextMenu {
                                Button(action: {
                                    selectedDocument = document
                                    showDocumentDetails = true
                                }) {
                                    Label("View Details", systemImage: "info.circle")
                                }
                                
                                Button(action: {
                                    indexSingleDocument(document)
                                }) {
                                    Label("Index Document", systemImage: "arrow.up.doc")
                                }
                                .disabled(document.metadata.isIndexed || isIndexing || settingsManager.activeIndex == nil)
                                
                                Button(action: {
                                    documentToDelete = document
                                    showDeleteConfirmation = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                    }
                    .onDelete { indexSet in
                        let documentsToDelete = indexSet.map { filteredDocuments[$0] }
                        
                        if let firstDoc = documentsToDelete.first {
                            documentToDelete = firstDoc
                            showDeleteConfirmation = true
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            
            if documentManager.isProcessing || isIndexing {
                // Processing indicator
                VStack {
                    ProgressView(value: documentManager.isProcessing ? documentManager.processingProgress : indexingProgress)
                        .padding(.horizontal)
                    
                    Text(documentManager.isProcessing ? "Processing documents..." : "Indexing documents...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Bottom buttons
            HStack {
                Button(action: {
                    showDocumentPicker = true
                }) {
                    Label("Add Documents", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(documentManager.isProcessing || isIndexing)
                
                Button(action: {
                    indexDocuments()
                }) {
                    Label("Index All", systemImage: "arrow.up.doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(documentManager.isProcessing || isIndexing || documentManager.documents.isEmpty || settingsManager.activeIndex == nil)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Documents")
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(types: documentManager.supportedContentTypes) { urls in
                processDocuments(urls)
            }
        }
        .sheet(isPresented: $showDocumentDetails, onDismiss: {
            selectedDocument = nil
        }) {
            if let document = selectedDocument {
                DocumentDetailView(document: document)
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Document"),
                message: Text("Are you sure you want to delete '\(documentToDelete?.metadata.fileName ?? "")'? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let document = documentToDelete {
                        do {
                            try documentManager.deleteDocument(document)
                        } catch {
                            apiManager.currentError = APIError(message: "Error deleting document: \(error.localizedDescription)")
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        Label("Add Documents", systemImage: "plus")
                    }
                    
                    Button(action: {
                        indexDocuments()
                    }) {
                        Label("Index All Documents", systemImage: "arrow.up.doc.on.clipboard")
                    }
                    .disabled(documentManager.documents.isEmpty || isIndexing || settingsManager.activeIndex == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func processDocuments(_ urls: [URL]) {
        Task {
            do {
                try await documentManager.processDocuments(urls: urls)
            } catch {
                print("Error processing documents: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    apiManager.currentError = APIError(message: "Error processing documents: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func indexSingleDocument(_ document: DocumentItem) {
        guard let indexName = settingsManager.activeIndex, !document.metadata.isIndexed else { return }
        
        isIndexing = true
        indexingProgress = 0.0
        
        Task {
            do {
                // Chunk document
                let chunks = documentManager.chunkDocument(
                    document,
                    chunkSize: settingsManager.chunkSize,
                    chunkOverlap: settingsManager.chunkOverlap
                )
                
                // Update document with chunks
                try documentManager.updateDocumentChunks(document, chunks: chunks)
                
                // Generate embeddings
                let chunkContents = chunks.map { $0.content }
                let embeddings = try await apiManager.generateEmbeddings(for: chunkContents)
                
                // Prepare vectors for Pinecone
                var vectors: [PineconeVector] = []
                
                for (i, (chunk, embedding)) in zip(chunks, embeddings).enumerated() {
                    let vector = PineconeVector(
                        id: "\(document.id)_\(i)",
                        values: embedding,
                        metadata: [
                            "text": AnyCodable(chunk.content),
                            "source": AnyCodable(document.metadata.fileName),
                            "document_id": AnyCodable(document.id),
                            "chunk_id": AnyCodable(String(i)),
                            "hash": AnyCodable(chunk.contentHash ?? "")
                        ]
                    )
                    vectors.append(vector)
                }
                
                // Upsert vectors to Pinecone
                _ = try await apiManager.upsertVectors(
                    indexName: indexName,
                    vectors: vectors,
                    namespace: settingsManager.activeNamespace
                )
                
                // Mark document as indexed
                try documentManager.markDocumentAsIndexed(document)
                
                DispatchQueue.main.async {
                    isIndexing = false
                    indexingProgress = 1.0
                }
            } catch {
                print("Error indexing document: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    apiManager.currentError = APIError(message: "Error indexing document: \(error.localizedDescription)")
                    isIndexing = false
                }
            }
        }
    }
    
    private func indexDocuments() {
        guard let indexName = settingsManager.activeIndex, !documentManager.documents.isEmpty else { return }
        
        let nonIndexedDocuments = documentManager.documents.filter { !$0.metadata.isIndexed }
        if nonIndexedDocuments.isEmpty {
            apiManager.currentError = APIError(message: "All documents are already indexed")
            return
        }
        
        isIndexing = true
        indexingProgress = 0.0
        
        Task {
            let totalCount = nonIndexedDocuments.count
            
            for (index, document) in nonIndexedDocuments.enumerated() {
                do {
                    // Chunk document
                    let chunks = documentManager.chunkDocument(
                        document,
                        chunkSize: settingsManager.chunkSize,
                        chunkOverlap: settingsManager.chunkOverlap
                    )
                    
                    // Update document with chunks
                    try documentManager.updateDocumentChunks(document, chunks: chunks)
                    
                    // Generate embeddings in batches to avoid timeout
                    let chunkContents = chunks.map { $0.content }
                    let batchSize = 8
                    var allEmbeddings: [[Double]] = []
                    
                    for i in stride(from: 0, to: chunkContents.count, by: batchSize) {
                        let end = min(i + batchSize, chunkContents.count)
                        let batchTexts = Array(chunkContents[i..<end])
                        let batchEmbeddings = try await apiManager.generateEmbeddings(for: batchTexts)
                        allEmbeddings.append(contentsOf: batchEmbeddings)
                    }
                    
                    // Prepare vectors for Pinecone
                    var vectors: [PineconeVector] = []
                    
                    for (i, (chunk, embedding)) in zip(chunks, allEmbeddings).enumerated() {
                        let vector = PineconeVector(
                            id: "\(document.id)_\(i)",
                            values: embedding,
                            metadata: [
                                "text": AnyCodable(chunk.content),
                                "source": AnyCodable(document.metadata.fileName),
                                "document_id": AnyCodable(document.id),
                                "chunk_id": AnyCodable(String(i)),
                                "hash": AnyCodable(chunk.contentHash ?? "")
                            ] as [String : AnyCodable]
                        )
                        vectors.append(vector)
                    }
                    
                    // Upsert vectors to Pinecone
                    _ = try await apiManager.upsertVectors(
                        indexName: indexName,
                        vectors: vectors,
                        namespace: settingsManager.activeNamespace
                    )
                    
                    // Mark document as indexed
                    try documentManager.markDocumentAsIndexed(document)
                    
                    // Update progress on the main thread
                    let currentProgress = Double(index + 1) / Double(totalCount)
                    await MainActor.run {
                        indexingProgress = currentProgress
                    }
                } catch {
                    print("Error indexing document \(document.metadata.fileName): \(error.localizedDescription)")
                }
            }
            
            // Update completion status on the main thread
            await MainActor.run {
                isIndexing = false
                indexingProgress = 1.0
            }
        }
    }
}

// MARK: - DocumentRow.swift
import SwiftUI

struct DocumentRow: View {
    let document: DocumentItem
    
    var body: some View {
        HStack {
            // Document icon
            documentIcon
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(iconBackground)
                .cornerRadius(8)
            
            // Document details
            VStack(alignment: .leading, spacing: 4) {
                Text(document.metadata.fileName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(document.metadata.fileSize.formattedFileSize())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(document.metadata.dateAdded.formattedString())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            if document.metadata.isIndexed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .imageScale(.large)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var documentIcon: some View {
        let fileName = document.metadata.fileName.lowercased()
        
        if fileName.hasSuffix(".pdf") {
            return Image(systemName: "doc.text.fill")
                .foregroundColor(.white)
        } else if fileName.hasSuffix(".txt") || fileName.hasSuffix(".md") {
            return Image(systemName: "doc.plaintext.fill")
                .foregroundColor(.white)
        } else if fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") ||
                  fileName.hasSuffix(".png") || fileName.hasSuffix(".gif") {
            return Image(systemName: "photo.fill")
                .foregroundColor(.white)
        } else if fileName.hasSuffix(".doc") || fileName.hasSuffix(".docx") {
            return Image(systemName: "doc.fill")
                .foregroundColor(.white)
        } else if fileName.hasSuffix(".html") || fileName.hasSuffix(".htm") {
            return Image(systemName: "doc.richtext.fill")
                .foregroundColor(.white)
        } else {
            return Image(systemName: "doc.fill")
                .foregroundColor(.white)
        }
    }
    
    private var iconBackground: Color {
        let fileName = document.metadata.fileName.lowercased()
        
        if fileName.hasSuffix(".pdf") {
            return .red
        } else if fileName.hasSuffix(".txt") || fileName.hasSuffix(".md") {
            return .blue
        } else if fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") ||
                  fileName.hasSuffix(".png") || fileName.hasSuffix(".gif") {
            return .purple
        } else if fileName.hasSuffix(".doc") || fileName.hasSuffix(".docx") {
            return .indigo
        } else if fileName.hasSuffix(".html") || fileName.hasSuffix(".htm") {
            return .orange
        } else {
            return .gray
        }
    }
}

// MARK: - DocumentDetailView.swift
import SwiftUI

struct DocumentDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    let document: DocumentItem
    
    @State private var isIndexing = false
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var previewText: String
    
    init(document: DocumentItem) {
        self.document = document
        // Initialize with preview text (first 1000 chars)
        self._previewText = State(initialValue: String(document.metadata.textContent.prefix(1000)))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Document header
                HStack {
                    Image(systemName: getDocumentIconName())
                        .font(.largeTitle)
                        .foregroundColor(getDocumentColor())
                    
                    VStack(alignment: .leading) {
                        Text(document.metadata.fileName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text(document.metadata.fileSize.formattedFileSize())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Added \(document.metadata.dateAdded.formattedString())")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Status and actions
                HStack(spacing: 12) {
                    VStack(alignment: .center) {
                        Image(systemName: document.metadata.isIndexed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(document.metadata.isIndexed ? .green : .secondary)
                            .imageScale(.large)
                        
                        Text(document.metadata.isIndexed ? "Indexed" : "Not Indexed")
                            .font(.caption)
                            .foregroundColor(document.metadata.isIndexed ? .green : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    VStack(alignment: .center) {
                        Text("\(document.metadata.chunks.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Chunks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    Button(action: {
                        showShareSheet = true
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .imageScale(.large)
                            
                            Text("Share")
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Content preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Content Preview")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            // Toggle between short and full preview
                            if previewText.count <= 1000 {
                                previewText = document.metadata.textContent
                            } else {
                                previewText = String(document.metadata.textContent.prefix(1000))
                            }
                        }) {
                            Text(previewText.count <= 1000 ? "Show More" : "Show Less")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text(previewText)
                        .font(.body)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    
                    if previewText.count <= 1000 && document.metadata.textContent.count > 1000 {
                        Text("(Content truncated, showing first 1000 characters)")
                            .font(.caption)
                            .italic()
                            .foregroundColor(.secondary)
                    }
                }
                
                // Chunks section
                if !document.metadata.chunks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chunks (\(document.metadata.chunks.count))")
                            .font(.headline)
                        
                        ForEach(document.metadata.chunks.prefix(3)) { chunk in
                            ChunkView(chunk: chunk)
                        }
                        
                        if document.metadata.chunks.count > 3 {
                            Text("(Showing 3 of \(document.metadata.chunks.count) chunks)")
                                .font(.caption)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Action buttons
                if !document.metadata.isIndexed {
                    Button(action: {
                        indexDocument()
                    }) {
                        if isIndexing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Label("Index Document", systemImage: "arrow.up.doc")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                    .disabled(isIndexing || settingsManager.activeIndex == nil)
                }
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Label("Delete Document", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle("Document Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Document"),
                message: Text("Are you sure you want to delete '\(document.metadata.fileName)'? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteDocument()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [document.metadata.url])
        }
    }
    
    private func getDocumentIconName() -> String {
        let fileName = document.metadata.fileName.lowercased()
        
        if fileName.hasSuffix(".pdf") {
            return "doc.text.fill"
        } else if fileName.hasSuffix(".txt") || fileName.hasSuffix(".md") {
            return "doc.plaintext.fill"
        } else if fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") ||
                  fileName.hasSuffix(".png") || fileName.hasSuffix(".gif") {
            return "photo.fill"
        } else if fileName.hasSuffix(".doc") || fileName.hasSuffix(".docx") {
            return "doc.fill"
        } else if fileName.hasSuffix(".html") || fileName.hasSuffix(".htm") {
            return "doc.richtext.fill"
        } else {
            return "doc.fill"
        }
    }
    
    private func getDocumentColor() -> Color {
        let fileName = document.metadata.fileName.lowercased()
        
        if fileName.hasSuffix(".pdf") {
            return .red
        } else if fileName.hasSuffix(".txt") || fileName.hasSuffix(".md") {
            return .blue
        } else if fileName.hasSuffix(".jpg") || fileName.hasSuffix(".jpeg") ||
                  fileName.hasSuffix(".png") || fileName.hasSuffix(".gif") {
            return .purple
        } else if fileName.hasSuffix(".doc") || fileName.hasSuffix(".docx") {
            return .indigo
        } else if fileName.hasSuffix(".html") || fileName.hasSuffix(".htm") {
            return .orange
        } else {
            return .gray
        }
    }
    
    private func indexDocument() {
        guard let indexName = settingsManager.activeIndex else { return }
        
        isIndexing = true
        
        Task {
            do {
                // Chunk document
                let chunks = documentManager.chunkDocument(
                    document,
                    chunkSize: settingsManager.chunkSize,
                    chunkOverlap: settingsManager.chunkOverlap
                )
                
                // Update document with chunks
                try documentManager.updateDocumentChunks(document, chunks: chunks)
                
                // Generate embeddings
                let chunkContents = chunks.map { $0.content }
                let embeddings = try await apiManager.generateEmbeddings(for: chunkContents)
                
                // Prepare vectors for Pinecone
                var vectors: [PineconeVector] = []
                
                for (i, (chunk, embedding)) in zip(chunks, embeddings).enumerated() {
                    let vector = PineconeVector(
                        id: "\(document.id)_\(i)",
                        values: embedding,
                            metadata: [
                                "text": AnyCodable(chunk.content),
                                "source": AnyCodable(document.metadata.fileName),
                                "document_id": AnyCodable(document.id),
                                "chunk_id": AnyCodable(String(i)),
                                "hash": AnyCodable(chunk.contentHash ?? "")
                            ] as [String : AnyCodable]
                    )
                    vectors.append(vector)
                }
                
                // Upsert vectors to Pinecone
                _ = try await apiManager.upsertVectors(
                    indexName: indexName,
                    vectors: vectors,
                    namespace: settingsManager.activeNamespace
                )
                
                // Mark document as indexed
                try documentManager.markDocumentAsIndexed(document)
                
                DispatchQueue.main.async {
                    isIndexing = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("Error indexing document: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    apiManager.currentError = APIError(message: "Error indexing document: \(error.localizedDescription)")
                    isIndexing = false
                }
            }
        }
    }
    
    private func deleteDocument() {
        do {
            try documentManager.deleteDocument(document)
            presentationMode.wrappedValue.dismiss()
        } catch {
            apiManager.currentError = APIError(message: "Error deleting document: \(error.localizedDescription)")
        }
    }
}

// MARK: - ChunkView.swift
import SwiftUI

struct ChunkView: View {
    let chunk: TextChunk
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                isExpanded.toggle()
            }) {
                HStack {
                    Text("Chunk #\(chunk.metadata["chunk_id"] ?? "unknown")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(chunk.content)
                    .font(.body)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
            } else {
                Text(chunk.content.prefix(150))
                    .font(.caption)
                    .lineLimit(3)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                
                if chunk.content.count > 150 {
                    Text("(Tap to expand)")
                        .font(.caption2)
                        .italic()
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - ActivityViewController.swift
import SwiftUI
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
