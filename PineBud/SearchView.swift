// MARK: - SearchView.swift
import SwiftUI

struct SearchView: View {
    @EnvironmentObject var searchManager: SearchManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var apiManager: APIManager
    
    @State private var query = ""
    @State private var selectedSource: SourceResult?
    @State private var showSourceDetail = false
    @State private var showHistorySheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                TextField("Enter your query...", text: $query)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                
                Button(action: {
                    showHistorySheet = true
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .padding(10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                .disabled(searchManager.searchHistory.isEmpty)
                
                Button(action: performSearch) {
                    Image(systemName: "magnifyingglass")
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(query.isEmpty || searchManager.isSearching || settingsManager.activeIndex == nil)
            }
            .padding()
            
            // No index warning
            if settingsManager.activeIndex == nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                        .padding(.bottom, 4)
                    
                    Text("No active index selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Please select an index in the Indexes tab before searching")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    NavigationLink(destination: IndexesView()) {
                        Text("Go to Indexes")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .frame(maxHeight: .infinity)
            }
            // Search results
            else if let results = searchManager.searchResults {
                SearchResultsView(results: results) { source in
                    selectedSource = source
                    showSourceDetail = true
                }
            }
            // Loading state
            else if searchManager.isSearching {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    
                    Text("Searching...")
                        .font(.headline)
                    
                    Text("Retrieving relevant documents and generating response")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxHeight: .infinity)
            }
            // Error state
            else if let error = searchManager.searchError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Search Error")
                        .font(.headline)
                    
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Button("Try Again") {
                        performSearch()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(query.isEmpty)
                }
                .padding()
                .frame(maxHeight: .infinity)
            }
            // Empty state
            else {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Enter a query to search your documents")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Your search will retrieve relevant information from your indexed documents and generate an answer using AI.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if !searchManager.searchHistory.isEmpty {
                        Button("View Search History") {
                            showHistorySheet = true
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle("Search")
        .sheet(isPresented: $showSourceDetail) {
            if let source = selectedSource {
                NavigationView {
                    SourceDetailView(source: source)
                }
            }
        }
        .sheet(isPresented: $showHistorySheet) {
            SearchHistoryView { historyItem in
                query = historyItem
                showHistorySheet = false
                performSearch()
            }
        }
        .onAppear {
            // Configure search manager
            searchManager.configure(apiManager: apiManager, settingsManager: settingsManager)
        }
    }
    
    private func performSearch() {
        guard !query.isEmpty, settingsManager.activeIndex != nil else { return }
        
        searchManager.performSearch(query: query)
        
        // Dismiss keyboard
        hideKeyboard()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}



