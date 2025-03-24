// MARK: - SearchResultsView.swift
import SwiftUI

struct SearchResultsView: View {
    let results: SearchResults
    let onSourceSelected: (SourceResult) -> Void
    
    @State private var expandedAnswer = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Query
                HStack {
                    Text("Query:")
                        .font(.headline)
                    
                    Text(results.query)
                        .font(.body)
                }
                .padding(.horizontal)
                
                // Answer section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Answer")
                            .font(.headline)
                        
                        Spacer()
                        
                        if results.answer.count > 300 {
                            Button(action: {
                                expandedAnswer.toggle()
                            }) {
                                Text(expandedAnswer ? "Show Less" : "Show More")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Text(expandedAnswer ? results.answer : results.answer.prefix(300) + (results.answer.count > 300 ? "..." : ""))
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Sources section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sources")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if results.sources.isEmpty {
                        Text("No sources found")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(results.sources) { source in
                            SourceRow(source: source)
                                .onTapGesture {
                                    onSourceSelected(source)
                                }
                        }
                    }
                }
                
                // Search timestamp
                Text("Search performed: \(results.timestamp.formattedString())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            .padding(.vertical)
        }
    }
}
