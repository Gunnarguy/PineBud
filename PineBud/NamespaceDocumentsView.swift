// MARK: - NamespaceDocumentsView.swift
import SwiftUI


struct NamespaceDocumentsView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var namespaceDocuments: [String: [String]] = [:]
    @State private var isLoading = false
    @State private var selectedNamespace: String?
    @State private var selectedDocument: DocumentItem?
    @State private var showDocumentDetails = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading documents by namespace...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if namespaceDocuments.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "folder")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Documents in Namespaces")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Index documents to see them organized by namespace")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(namespaceDocuments.keys.sorted()), id: \.self) { namespace in
                        Section(header: Text(namespace.isEmpty ? "Default Namespace" : namespace)) {
                            ForEach(namespaceDocuments[namespace] ?? [], id: \.self) { documentId in
                                if let document = documentManager.findDocument(with: documentId) {
                                    DocumentRow(document: document)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedDocument = document
                                            showDocumentDetails = true
                                        }
                                } else {
                                    Text("Unknown Document")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    await loadDocumentsByNamespace()
                }
            }
        }
        .navigationTitle("Documents by Namespace")
        .sheet(isPresented: $showDocumentDetails, onDismiss: {
            selectedDocument = nil
        }) {
            if let document = selectedDocument {
                DocumentDetailView(document: document)
            }
        }
        .onAppear {
            Task {
                await loadDocumentsByNamespace()
            }
        }
    }
    
    private func loadDocumentsByNamespace() async {
        guard let indexName = settingsManager.activeIndex, !indexName.isEmpty else {
            DispatchQueue.main.async {
                self.namespaceDocuments = [:]
            }
            return
        }
        
        print("Active Index Name: \(indexName)") // Added print statement

        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            // Get all available namespaces
            let namespaces = try await apiManager.getNamespaces(indexName: indexName)
            
            // Include default (empty) namespace
            var allNamespaces = namespaces
            allNamespaces.append("")
            
            var documentsByNamespace: [String: [String]] = [:]
            
            // For each namespace, fetch document ids
            for namespace in allNamespaces {
                do {
                    // Query to get document_ids with a simple * wildcard search
                    let queryRequest = PineconeQueryRequest(
                        topK: 100,
                        includeMetadata: true,
                        namespace: namespace,
                        filter: [:] as [String: String], // Explicit type annotation for filter
                        vector: nil as [Double]?,
                        sparseVector: nil as [String: Double]?,
                        includeValues: false,
                        id: nil as String?
                    )
                    
                    let queryResponse = try await _apiManager.wrappedValue.queryIndex(
                        indexName: indexName,
                        request: queryRequest
                    )
                    
                    // Extract unique document IDs from matches
                    var documentIds = Set<String>()
                    for match in queryResponse.matches {
                        if let documentId = match.metadata["document_id"] as? String {
                            documentIds.insert(documentId)
                        }
                    }
                    
                    // Only add namespaces that have documents
                    if !documentIds.isEmpty {
                        documentsByNamespace[namespace] = Array(documentIds)
                    }
                } catch {
                    print("Error fetching documents for namespace \(namespace): \(error.localizedDescription), error: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.namespaceDocuments = documentsByNamespace
                self.isLoading = false
            }
        } catch {
            print("Error loading namespaces: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                self.namespaceDocuments = [:]
                self.isLoading = false
                apiManager.currentError = APIError(message: "Error loading documents by namespace: \(error.localizedDescription)")
            }
        }
    }
}
